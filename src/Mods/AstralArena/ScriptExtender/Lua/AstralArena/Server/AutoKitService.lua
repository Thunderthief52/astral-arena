local AutoKit = Ext.Require("AstralArena/Core/AutoKit.lua")

-- Applies AutoKit decisions to arena hirelings: the class build plan (once per
-- step, remembered in the save) and the best gear each hireling is carrying.
local AutoKitService = {}
AutoKitService.__index = AutoKitService

function AutoKitService.new(adapter, output, catalog, runStore)
    local byGuid = {}
    for _, candidate in ipairs(catalog or {}) do
        byGuid[candidate.characterGuid] = candidate
    end
    return setmetatable({
        adapter = adapter,
        output = output,
        byGuid = byGuid,
        runStore = runStore,
    }, AutoKitService)
end

local function shortGuid(guid)
    -- Osiris may report "Name_<uuid>"; catalogs store the bare uuid.
    local uuid = tostring(guid or ""):match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)$")
    return uuid or guid
end

function AutoKitService:hirelingFor(member)
    if member.isAvatar == true then
        return nil
    end
    return self.byGuid[shortGuid(member.guid)]
end

function AutoKitService:_firstExisting(names)
    for _, name in ipairs(names or {}) do
        if self.adapter.statExists(name) then
            return name
        end
    end
    return nil
end

function AutoKitService:_applyBuild(member, hireling, applied)
    local granted = {}
    for _, entry in ipairs(AutoKit.pendingSteps(hireling.className, member.level, applied)) do
        local given, missing = 0, {}
        local ok, err = pcall(function()
            for _, alternatives in ipairs(entry.spells or {}) do
                local name = self:_firstExisting(alternatives)
                if name then
                    self.adapter.addSpell(member.guid, name)
                    given = given + 1
                else
                    table.insert(missing, alternatives[1])
                end
            end
            for _, alternatives in ipairs(entry.passives or {}) do
                local name = self:_firstExisting(alternatives)
                if name then
                    self.adapter.addPassive(member.guid, name)
                    given = given + 1
                else
                    table.insert(missing, alternatives[1])
                end
            end
            for _, boost in ipairs(entry.boosts or {}) do
                self.adapter.addBoosts(member.guid, boost)
                given = given + 1
            end
        end)
        if ok then
            -- Mark the step done even when a name is missing from this game
            -- version, so it is not retried (and never double-applied) later.
            applied[entry.id] = true
            if given > 0 then
                table.insert(granted, entry.label or entry.id)
            end
            if #missing > 0 then
                self.output(string.format("Note: %s's plan step %s skipped names not in this game version: %s",
                    hireling.displayName, entry.id, table.concat(missing, ", ")))
            end
        else
            self.output("WARNING: auto-build step " .. entry.id .. " failed: " .. tostring(err))
        end
    end
    return granted
end

function AutoKitService:_applyGear(member, hireling)
    local profile = AutoKit.PROFILES[hireling.className]
    if not profile then
        return {}
    end
    local items = {}
    for _, fields in ipairs(self.adapter.characterItems(member.guid) or {}) do
        local item = AutoKit.describe(fields)
        if item then
            table.insert(items, item)
        end
    end
    local equipped = {}
    for slot, fields in pairs(self.adapter.equippedItems(member.guid) or {}) do
        local item = AutoKit.describe(fields)
        if item then
            equipped[slot] = item
        end
    end
    local changes = AutoKit.chooseLoadout(profile, items, equipped)
    local names = {}
    for _, change in ipairs(changes) do
        local ok, err = pcall(function()
            self.adapter.equipItem(member.guid, change.item.id)
        end)
        if ok then
            table.insert(names, change.item.name or change.item.id)
        else
            self.output("WARNING: could not equip " .. tostring(change.item.name) .. ": " .. tostring(err))
        end
    end
    return names
end

-- Called before every bout: hirelings catch up on their build plan for their
-- current level and put on the best gear they carry.
function AutoKitService:refresh(members)
    local record = self.runStore.load()
    record.autoKit = type(record.autoKit) == "table" and record.autoKit or {}
    local changed = false
    for _, member in ipairs(members or {}) do
        local hireling = self:hirelingFor(member)
        if hireling then
            local key = shortGuid(member.guid)
            record.autoKit[key] = type(record.autoKit[key]) == "table" and record.autoKit[key] or {}
            local granted = self:_applyBuild(member, hireling, record.autoKit[key])
            if #granted > 0 then
                changed = true
                self.output(string.format("%s (%s L%d) learned: %s.", hireling.displayName, hireling.className, member.level or 0, table.concat(granted, "; ")))
            end
            local ok, equipped = pcall(function()
                return self:_applyGear(member, hireling)
            end)
            if not ok then
                self.output("WARNING: auto-equip skipped for " .. hireling.displayName .. ": " .. tostring(equipped))
            elseif #equipped > 0 then
                self.output(string.format("%s equipped: %s.", hireling.displayName, table.concat(equipped, ", ")))
                self.adapter.notify(member.guid, hireling.displayName .. " geared up: " .. table.concat(equipped, ", "))
            end
        end
    end
    if changed then
        self.runStore.save(record)
    end
end

return AutoKitService
