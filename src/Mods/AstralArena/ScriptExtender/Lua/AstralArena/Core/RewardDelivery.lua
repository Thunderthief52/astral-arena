-- A save-backed delivery plan. Persist intent before each engine call, then
-- reconcile inventory UUIDs and stack amounts before retrying after a reload.
local Delivery = {}

local function received(operation, inventory)
    if operation.kind == "item" then
        local function total(snapshot)
            local sum = 0
            for _, item in pairs(snapshot or {}) do
                if item.templateId == operation.templateId then sum = sum + item.amount end
            end
            return sum
        end
        return math.max(0, total(inventory) - total(operation.before))
    end
    local amount = 0
    for guid, item in pairs(inventory) do
        local before = operation.before and operation.before[guid]
        if operation.kind == "treasure" or item.templateId == operation.templateId then
            amount = amount + math.max(0, item.amount - (before and before.amount or 0))
        end
    end
    return amount
end

function Delivery.process(transaction, adapter, save)
    -- Reuse the last verified inventory within this synchronous pass. Reset
    -- the cache on every tick/reload and refresh it after each engine action.
    local observedGuid, observedInventory
    local function observe(guid, refresh)
        if refresh or observedGuid ~= guid then
            observedInventory = adapter.rewardInventorySnapshot(guid)
            observedGuid = guid
        end
        return observedInventory
    end
    transaction.cursor = transaction.cursor or 1
    transaction.delivered = transaction.delivered or { treasureRolls=0, armoryItems=0, revivifyScrolls=0, rareItems=0 }
    while transaction.cursor <= #transaction.operations do
        local operation = transaction.operations[transaction.cursor]
        local inventory = observe(operation.recipientGuid)
        if not operation.before then
            operation.before = inventory
            operation.attempts = 0
            save()
        end
        local added = received(operation, inventory)
        local complete = (operation.kind == "treasure" and added > 0)
            or (operation.kind == "item" and added >= operation.amount)
        if not complete and operation.waitTicks and operation.waitTicks > 0 then
            operation.waitTicks = operation.waitTicks - 1
            save()
            return false
        end
        -- Native treasure tables may legitimately return no loot. Only accept
        -- that result after the call returned normally and an observation delay.
        if not complete and operation.kind == "treasure" and operation.returned then complete = true end
        if complete then
            local bucket = operation.bucket
            transaction.delivered[bucket] = (transaction.delivered[bucket] or 0)
                + (operation.kind == "item" and operation.amount or 1)
            operation.state = "delivered"
            transaction.cursor = transaction.cursor + 1
            save()
        else
            if operation.attempts >= 3 then
                return false, "delivery needs attention after three unsuccessful attempts"
            end
            operation.attempts = operation.attempts + 1
            operation.state = "issuing"
            operation.returned = false
            operation.waitTicks = 3
            save()
            local remaining = operation.kind == "item" and math.max(0, operation.amount - added) or nil
            local ok, err = pcall(adapter.applyRewardOperation, operation, remaining)
            operation.returned = ok
            if ok then operation.lastError = nil else operation.lastError = tostring(err) end
            save()
            -- Observe once immediately; engine calls that settle later resume
            -- on the normal progression tick instead of issuing another bundle.
            inventory = observe(operation.recipientGuid, true)
            added = received(operation, inventory)
            if (operation.kind == "item" and added >= operation.amount)
                or (operation.kind == "treasure" and added > 0) then
                operation.waitTicks = 0
            else
                return false, operation.lastError
            end
        end
    end
    transaction.status = "delivered"
    return true
end

function Delivery.retry(transaction)
    local operation = transaction.operations[transaction.cursor or 1]
    -- Do not let repeated hotbar clicks reissue a successful asynchronous call
    -- or skip its settlement delay. Only reset a step that exhausted retries.
    if operation and (operation.attempts or 0) >= 3 then
        operation.attempts, operation.waitTicks = 0, 0
        return true
    end
    return false
end

return Delivery
