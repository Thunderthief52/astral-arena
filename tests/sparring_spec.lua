local H = require("tests.test_helper")

local previousExt = _G.Ext
_G.Ext = {
    Require = function(path)
        return require((path:gsub("%.lua$", ""):gsub("/", ".")))
    end,
}
local Sparring = require("AstralArena.Server.Sparring")
_G.Ext = previousExt

local function fakeAdapter()
    local adapter = {
        alive = { left = true, right = true },
        scheduled = nil,
        prepared = {},
        restored = {},
        defeated = {},
        hostilePairs = 0,
        combatPairs = 0,
        notifications = {},
    }

    function adapter.partyMembers()
        return {
            { guid = "left", name = "Left", userId = 0, level = 5, faction = "faction-left" },
            { guid = "right", name = "Right", userId = 1, level = 5, faction = "faction-right" },
        }
    end

    function adapter.prepareCharacter(guid)
        if adapter.failPreparation then
            error("engine refused setup")
        end
        table.insert(adapter.prepared, guid)
    end

    function adapter.makeHostile()
        adapter.hostilePairs = adapter.hostilePairs + 1
    end

    function adapter.enterCombat()
        adapter.combatPairs = adapter.combatPairs + 1
    end

    function adapter.isAlive(guid)
        return adapter.alive[guid]
    end

    function adapter.markDefeated(guid)
        adapter.defeated[guid] = true
    end

    function adapter.restoreCharacter(member)
        table.insert(adapter.restored, member.guid)
    end

    function adapter.schedule(_, callback)
        adapter.scheduled = callback
    end

    function adapter.notify(_, message)
        table.insert(adapter.notifications, message)
    end

    return adapter
end

H.test("sparring prepares two user-owned teams and starts combat", function()
    local adapter = fakeAdapter()
    local messages = {}
    local sparring = Sparring.new(adapter, function(message)
        table.insert(messages, message)
    end)

    local match = sparring:startAuto()
    H.equal(match.phase, "combat")
    H.equal(#adapter.prepared, 2)
    H.equal(adapter.hostilePairs, 1)
    H.equal(adapter.combatPairs, 1)
    H.truthy(adapter.scheduled)
end)

H.test("sparring detects defeat, declares a winner, and restores both teams", function()
    local adapter = fakeAdapter()
    local sparring = Sparring.new(adapter, function() end)
    sparring:startAuto()

    adapter.alive.right = false
    adapter.scheduled()

    H.equal(sparring.active, nil)
    H.equal(sparring.lastResult.winnerUserId, 0)
    H.truthy(adapter.defeated.right)
    H.equal(#adapter.restored, 2)
end)

H.test("manual abort restores both teams without a winner", function()
    local adapter = fakeAdapter()
    local sparring = Sparring.new(adapter, function() end)
    sparring:startAuto()
    sparring:abort("test")

    H.equal(sparring.active, nil)
    H.equal(sparring.lastResult, nil)
    H.equal(#adapter.restored, 2)
end)

H.test("a partial engine setup failure rolls back both teams", function()
    local adapter = fakeAdapter()
    adapter.failPreparation = true
    local sparring = Sparring.new(adapter, function() end)

    H.raises(function()
        sparring:startAuto()
    end, "rolled back")
    H.equal(sparring.active, nil)
    H.equal(#adapter.restored, 2)
end)
