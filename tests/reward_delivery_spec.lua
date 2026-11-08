local H = require("tests.test_helper")
local Delivery = require("AstralArena.Core.RewardDelivery")
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end
local function fixture()
    local world = { player={old={templateId="scroll",amount=5}} }
    local calls, serial = 0, 0
    local adapter = {}
    function adapter.rewardInventorySnapshot(guid) return copy(assert(world[guid])) end
    function adapter.applyRewardOperation(op, amount)
        calls = calls + 1
        if op.templateId == "scroll" then
            world.player.old.amount = world.player.old.amount + amount
        else
            serial = serial + 1
            world.player["new-" .. serial] = {templateId=op.templateId or "loot",amount=amount or 1}
        end
    end
    local tx = { operations={
        {kind="treasure",recipientGuid="player",bucket="treasureRolls"},
        {kind="item",recipientGuid="player",templateId="rare",amount=1,bucket="rareItems"},
        {kind="item",recipientGuid="player",templateId="scroll",amount=2,bucket="revivifyScrolls"},
    }}
    return tx, adapter, world, function() return calls end
end
local function finish(tx, adapter, save)
    for _ = 1, 40 do if Delivery.process(tx,adapter,save) then return end end
    error("delivery did not complete")
end

H.test("reward delivery resumes every saved interruption without duplicating loot", function()
    for crashAt = 1, 12 do
        local tx, adapter, world, calls = fixture()
        local stored, count = nil, 0
        local function save()
            count = count + 1
            stored = copy(tx)
            if count == crashAt then error("simulated interrupted Lua context") end
        end
        pcall(finish, tx, adapter, save)
        tx = stored or tx
        finish(tx, adapter, function() stored=copy(tx) end)
        H.equal(calls(),3,"only three engine deliveries are needed after reload")
        H.equal(world.player.old.amount,7)
        H.equal(tx.delivered.treasureRolls,1)
        H.equal(tx.delivered.rareItems,1)
        H.equal(tx.delivered.revivifyScrolls,2)
    end
end)

H.test("reward journal reconciles an engine effect whose acknowledgement was lost", function()
    local tx, adapter, world, calls = fixture()
    local beforeEffect
    local execute = adapter.applyRewardOperation
    local crashed = false
    function adapter.applyRewardOperation(op, amount)
        execute(op, amount)
        if not crashed then
            crashed=true
            beforeEffect=copy(tx)
            error("effect succeeded before acknowledgement")
        end
    end
    finish(tx,adapter,function() end)
    -- Recreate a save containing the issuing journal and just the first effect.
    world.player={old={templateId="scroll",amount=5},["new-1"]={templateId="loot",amount=1}}
    tx=beforeEffect
    finish(tx,adapter,function() end)
    H.equal(calls(),5,"the recovered treasure roll must not be generated again")
    H.equal(world.player.old.amount,7)
end)

H.test("a partial stack delivery retries only the missing quantity", function()
    local tx, adapter, world = fixture()
    tx.operations={tx.operations[3]}
    local requested={}
    function adapter.applyRewardOperation(_,amount)
        table.insert(requested,amount)
        if #requested==1 then
            world.player.old.amount=world.player.old.amount+1
            error("interrupted after one scroll")
        end
        world.player.old.amount=world.player.old.amount+amount
    end
    finish(tx,adapter,function() end)
    H.equal(requested[1],2)
    H.equal(requested[2],1)
    H.equal(world.player.old.amount,7)
end)

H.test("stack UUID replacement does not count pre-existing items as new rewards", function()
    local tx, adapter, world = fixture()
    tx.operations={tx.operations[3]}
    local calls=0
    function adapter.applyRewardOperation(_,amount)
        calls=calls+1
        if calls==1 then
            world.player.old=nil
            world.player.replacement={templateId="scroll",amount=6}
            error("only one scroll arrived")
        else world.player.replacement.amount=world.player.replacement.amount+amount end
    end
    finish(tx,adapter,function() end)
    H.equal(calls,2)
    H.equal(world.player.replacement.amount,7)
end)

H.test("delivery failures stop safely and an explicit retry retains completed work", function()
    local tx, adapter, _, calls = fixture()
    local execute=adapter.applyRewardOperation
    local fail=true
    function adapter.applyRewardOperation(op,amount)
        if fail and op.kind=="item" then error("inventory unavailable") end
        execute(op,amount)
    end
    for _=1,20 do Delivery.process(tx,adapter,function() end) end
    H.equal(tx.cursor,2)
    H.equal(calls(),1)
    fail=false
    Delivery.retry(tx)
    finish(tx,adapter,function() end)
    H.equal(calls(),3)
end)

H.test("unavailable inventory cannot issue loot without a recovery snapshot", function()
    local tx, adapter, _, calls = fixture()
    function adapter.rewardInventorySnapshot() error("not loaded") end
    H.equal(pcall(Delivery.process,tx,adapter,function() end),false)
    H.equal(calls(),0)
end)

H.test("repeated retry requests cannot duplicate a normally returned asynchronous delivery", function()
    local tx,adapter,world=fixture()
    tx.operations={tx.operations[3]}
    local issued=0
    function adapter.applyRewardOperation() issued=issued+1 end
    local complete,reason=Delivery.process(tx,adapter,function() end)
    H.equal(complete,false)
    H.equal(reason,nil)
    for _=1,10 do H.equal(Delivery.retry(tx),false) end
    H.equal(tx.operations[1].waitTicks,3)
    world.player.old.amount=7
    finish(tx,adapter,function() end)
    H.equal(issued,1)
    H.equal(tx.delivered.revivifyScrolls,2)
end)
