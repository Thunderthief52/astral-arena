local Adapter = {}
local PreparationLoadout
if Ext and Ext.Require then
    PreparationLoadout = Ext.Require("AstralArena/Shared/PreparationLoadout.lua")
else
    PreparationLoadout = require("AstralArena.Shared.PreparationLoadout")
end

local REVIVIFY_SCROLL_TEMPLATE = "c1c3e4fb-d68c-4e10-afdc-d4550238d50e"

local ENEMY_FACTION = "64321d50-d516-b1b2-cfac-2eb773de1ff6"
local TOTAL_EXPERIENCE = {
    [3] = 900,
    [5] = 6500,
    [8] = 34000,
    [10] = 64000,
    [12] = 100000,
}

local function translatedName(guid)
    local handle = Osi.GetDisplayName(guid)
    if handle and handle ~= "" then
        local translated = Ext.Loca.GetTranslatedString(handle)
        if translated and translated ~= "" then
            return translated
        end
        return handle
    end
    return guid
end

local function safely(action)
    local ok, result = pcall(action)
    if ok then
        return result
    end
    Ext.Utils.PrintWarning("[Astral Arena] Engine cleanup warning: " .. tostring(result))
    return nil
end

local function ensureDeathSavingThrows(guid)
    local hasPassive = safely(function()
        return Osi.HasPassive(guid, "DeathSavingThrows") == 1
    end)
    if not hasPassive then
        safely(function()
            Osi.AddPassive(guid, "DeathSavingThrows")
        end)
    end
end

function Adapter.partyMembers()
    local members = {}
    for _, row in pairs(Osi.DB_PartyMembers:Get(nil)) do
        local guid = row[1]
        if guid and guid ~= "" then
            local entity = Ext.Entity.Get(guid)
            local avatar = entity and entity.UserAvatar or nil
            table.insert(members, {
                guid = guid,
                name = translatedName(guid),
                userId = Osi.GetReservedUserID(guid),
                level = Osi.GetLevel(guid),
                faction = Osi.GetFaction(guid),
                isDead = Osi.IsDead(guid) == 1,
                inCombat = Osi.IsInCombat(guid) == 1,
                isAvatar = avatar ~= nil,
                avatarUserId = avatar and avatar.UserID or nil,
            })
        end
    end
    return members
end

function Adapter.isPartyInArena(members, arenaLevel)
    arenaLevel = arenaLevel or "AA_Arena_Main"
    if type(members) ~= "table" or not members[1] then
        return false
    end
    for _, member in ipairs(members) do
        if Osi.GetRegion(member.guid) ~= arenaLevel then
            return false
        end
    end
    return true
end

local stagingOrigin = nil

local function requirePosition(guid)
    local x, y, z = Osi.GetPosition(guid)
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        error("could not read arena position for " .. tostring(guid), 3)
    end
    return { x, y, z }
end

local function teleportParty(members, origin, site)
    local siteOffset = site.offset or { 0, 0, 0 }
    local partyOffsets = site.partyOffsets or {}
    for index, member in ipairs(members) do
        local offset = partyOffsets[index] or { 0, 0 }
        local targetX = origin[1] + (siteOffset[1] or 0) + (offset[1] or 0)
        local targetY = origin[2] + (siteOffset[2] or 0)
        local targetZ = origin[3] + (siteOffset[3] or 0) + (offset[2] or 0)
        Osi.TeleportToPosition(member.guid, targetX, targetY, targetZ, "", 0, 0, 0, 0, 1)
    end
end

-- AA_Arena_Main's staging court is authored around world origin and every
-- combat site offset in ArenaSites.lua is validated from that exact point (see
-- tools/scenery/validate_scenery.py). Only the ground height is read at runtime,
-- so spawn geometry never depends on where a player happened to be standing.
local STAGING_CENTER = { 0, 0 }

local function resolveStagingOrigin(members)
    if stagingOrigin then
        return stagingOrigin
    end
    local position = requirePosition(members[1].guid)
    stagingOrigin = { STAGING_CENTER[1], position[2], STAGING_CENTER[2] }
    return stagingOrigin
end

function Adapter.setStagingOrigin(origin)
    -- Saves record the origin; only its height is honoured because the
    -- horizontal centre is fixed by the authored level.
    if type(origin) == "table" and type(origin[2]) == "number" then
        stagingOrigin = { STAGING_CENTER[1], origin[2], STAGING_CENTER[2] }
    end
end

function Adapter.stagingOrigin()
    if not stagingOrigin then
        return nil
    end
    return { stagingOrigin[1], stagingOrigin[2], stagingOrigin[3] }
end

function Adapter.prepareArenaSite(members, site)
    if type(members) ~= "table" or not members[1] then
        error("arena site preparation requires a player party", 2)
    end
    if type(site) ~= "table" or type(site.offset) ~= "table" then
        error("arena site definition is invalid", 2)
    end
    teleportParty(members, resolveStagingOrigin(members), site)
end

function Adapter.returnPartyToStaging(members)
    if type(members) ~= "table" or not members[1] then
        return
    end
    local ok = pcall(resolveStagingOrigin, members)
    if not ok or not stagingOrigin then
        return
    end
    teleportParty(members, stagingOrigin, {
        offset = { 0, 0, 0 },
        partyOffsets = {
            { 0, 0 },
            { -2, -2 },
            { -2, 2 },
            { -4, 0 },
        },
    })
end

function Adapter.prepareCharacter(guid)
    safely(function()
        Osi.RemoveStatusesWithType(guid, "DOWNED", guid)
    end)
    safely(function()
        Osi.RemoveStatus(guid, "KNOCKED_OUT", guid)
    end)
    safely(function()
        Osi.RemoveStatus(guid, "INVULNERABLE_NOT_SHOWN", guid)
    end)
    safely(function()
        Osi.RemoveStatus(guid, "SANCTUARY", guid)
    end)
    safely(function()
        Osi.RemoveStatus(guid, "SANCTUARY_BLOCK", guid)
    end)
    Osi.SetCanFight(guid, 1)
    Osi.SetCanJoinCombat(guid, 1)
    Osi.SetImmortal(guid, 0)
    if Osi.IsDead(guid) == 1 then
        safely(function()
            Osi.Resurrect(guid)
        end)
    end
    ensureDeathSavingThrows(guid)
    safely(function()
        Osi.PROC_CharacterFullRestore(guid)
    end)
end

function Adapter.makeHostile(leftGuid, rightGuid)
    Osi.SetRelationTemporaryHostile(leftGuid, rightGuid)
    Osi.SetRelationTemporaryHostile(rightGuid, leftGuid)
end

function Adapter.enterCombat(leftGuid, rightGuid)
    -- A player may still be dead when a later wave arrives. Establishing the
    -- relationship is safe, but EnterCombat itself may reject a corpse; a
    -- successful resurrection is connected again by the arena poll.
    safely(function()
        Osi.EnterCombat(leftGuid, rightGuid)
    end)
    safely(function()
        Osi.EnterCombat(rightGuid, leftGuid)
    end)
end

function Adapter.isDead(guid)
    return Osi.IsDead(guid) == 1
end

function Adapter.isAlive(guid)
    if Adapter.isDead(guid) then
        return false
    end
    local hitpoints = Osi.GetHitpoints(guid)
    return type(hitpoints) == "number" and hitpoints > 0
end

function Adapter.markDefeated(guid)
    -- Native zero-hit-point handling supplies the downed pose, initiative turn,
    -- death-saving throws, attack-driven failures, and eventual death. Arena
    -- rules deliberately add no invulnerability or target exclusion here.
    ensureDeathSavingThrows(guid)
end

function Adapter.markRecovered(guid)
    ensureDeathSavingThrows(guid)
end

function Adapter.restoreCharacter(member, opposingFactions)
    safely(function()
        Osi.LeaveCombat(member.guid)
    end)
    for faction in pairs(opposingFactions or {}) do
        safely(function()
            Osi.ClearIndividualRelation(member.guid, faction)
        end)
    end
    safely(function()
        Osi.RemoveStatus(member.guid, "KNOCKED_OUT", member.guid)
    end)
    safely(function()
        Osi.RemoveStatus(member.guid, "FORCE_KNOCKED_OUT_TEMPORARILY", member.guid)
    end)
    safely(function()
        Osi.RemoveStatusesWithType(member.guid, "DOWNED", member.guid)
    end)
    safely(function()
        Osi.RemoveStatus(member.guid, "INVULNERABLE_NOT_SHOWN", member.guid)
    end)
    safely(function()
        Osi.RemoveStatus(member.guid, "SANCTUARY", member.guid)
    end)
    safely(function()
        Osi.RemoveStatus(member.guid, "SANCTUARY_BLOCK", member.guid)
    end)
    safely(function()
        Osi.SetCanFight(member.guid, 1)
    end)
    safely(function()
        Osi.SetCanJoinCombat(member.guid, 1)
    end)
    safely(function()
        Osi.SetImmortal(member.guid, 0)
    end)
    if Osi.IsDead(member.guid) == 1 then
        safely(function()
            Osi.Resurrect(member.guid)
        end)
    end
    safely(function()
        Osi.SetHitpointsPercentage(member.guid, 100)
    end)
    safely(function()
        Osi.ResetCooldowns(member.guid)
    end)
    safely(function()
        Osi.PROC_CharacterFullRestore(member.guid)
    end)
end

function Adapter.recoverBetweenWaves(member, opposingFactions)
    safely(function()
        Osi.LeaveCombat(member.guid)
    end)
    for faction in pairs(opposingFactions or {}) do
        safely(function()
            Osi.ClearIndividualRelation(member.guid, faction)
        end)
    end
    -- Preserve native DOWNED/KNOCKED_OUT, hit points, death state, buffs,
    -- spell slots, and class resources. Teammates must use Help, healing,
    -- Revivify, or a scroll during intermission.
    if Adapter.isAlive(member.guid) then
        safely(function()
            Osi.SetCanFight(member.guid, 1)
        end)
        safely(function()
            Osi.SetCanJoinCombat(member.guid, 1)
        end)
        safely(function()
            Osi.SetImmortal(member.guid, 0)
        end)
    end
    ensureDeathSavingThrows(member.guid)
    return {
        alive = Adapter.isAlive(member.guid),
        dead = Adapter.isDead(member.guid),
    }
end

function Adapter.fullRestParty(members)
    if type(members) ~= "table" or not members[1] then
        return
    end
    -- RestoreParty refreshes long-rest resources that ResetCooldowns and a
    -- simple heal do not cover (spell slots, class resources, and similar).
    safely(function()
        Osi.RestoreParty(members[1].guid)
    end)
    for _, member in ipairs(members) do
        safely(function()
            Osi.PROC_CharacterFullRestore(member.guid)
        end)
        safely(function()
            Osi.ResetCooldowns(member.guid)
        end)
    end
end

function Adapter.restoreWaveResources(members)
    if type(members) ~= "table" or not members[1] then
        return
    end
    -- RestoreParty replenishes spell slots and class resources. It does not
    -- replace the explicit resurrection step used at the battle boundary, so
    -- a character who actually died still needs Revivify between waves.
    safely(function()
        Osi.RestoreParty(members[1].guid)
    end)
    for _, member in ipairs(members) do
        if not Adapter.isDead(member.guid) then
            safely(function()
                Osi.SetHitpointsPercentage(member.guid, 100)
            end)
            safely(function()
                Osi.PROC_CharacterFullRestore(member.guid)
            end)
            safely(function()
                Osi.ResetCooldowns(member.guid)
            end)
        end
    end
end

function Adapter.schedule(delayMilliseconds, callback)
    Ext.Timer.WaitFor(delayMilliseconds, callback)
end

function Adapter.schedulePromptRetry(delayMilliseconds, callback)
    Ext.Timer.WaitFor(delayMilliseconds, callback)
end

function Adapter.notify(guid, message)
    safely(function()
        Osi.ShowNotification(guid, message)
    end)
end

function Adapter.menuOwner(members)
    local host = safely(function()
        return Osi.GetHostCharacter()
    end)
    if host and host ~= "" then
        for _, member in ipairs(members or {}) do
            if member.guid == host then
                return host
            end
        end
    end
    return members and members[1] and members[1].guid or nil
end

function Adapter.openYesNo(guid, messageKey, message)
    if not guid or guid == "" then
        error("arena menu requires a player character", 2)
    end
    if Ext.Loca and Ext.Loca.UpdateTranslatedString then
        safely(function()
            Ext.Loca.UpdateTranslatedString(messageKey, message)
        end)
    end
    Osi.OpenMessageBoxYesNo(guid, messageKey)
end

function Adapter.openMessage(guid, messageKey, message)
    if not guid or guid == "" then
        error("arena message requires a player character", 2)
    end
    if Ext.Loca and Ext.Loca.UpdateTranslatedString then
        safely(function()
            Ext.Loca.UpdateTranslatedString(messageKey, message)
        end)
    end
    Osi.OpenMessageBox(guid, messageKey)
end

function Adapter.getGold(guid)
    return math.max(0, tonumber(Osi.GetGold(guid)) or 0)
end

function Adapter.addGold(guid, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount ~= 0 then
        Osi.AddGold(guid, amount)
    end
end

function Adapter.hireFollower(candidate, buyerGuid, targetLevel, callback)
    local hirelingGuid = candidate and candidate.characterGuid
    local ok, err = pcall(function()
        if not hirelingGuid or hirelingGuid == "" then
            error("hireling character GUID is missing")
        end
        Osi.TeleportTo(hirelingGuid, buyerGuid, "AA_Hireling_Arrived", 0, 0, 0, 1, 1)
        safely(function() Osi.SetOnStage(hirelingGuid, 1) end)
        safely(function() Osi.SetLevel(hirelingGuid, targetLevel) end)
        Osi.PROC_Hirelings_Hire(hirelingGuid, buyerGuid)
    end)
    if not ok then
        callback(false, err)
        return
    end
    Adapter.schedule(1200, function()
        safely(function() Osi.SetLevel(hirelingGuid, targetLevel) end)
        for _, templateId in ipairs(candidate.equipment or {}) do
            if Adapter.validateItemTemplate(templateId) then
                safely(function()
                    Osi.TemplateAddTo(templateId, hirelingGuid, 1, 0)
                    local itemGuid = Osi.GetItemByTemplateInInventory(templateId, hirelingGuid)
                    if itemGuid and itemGuid ~= "" then
                        Osi.Equip(hirelingGuid, itemGuid, 1, 0, 1)
                    end
                end)
            end
        end
        safely(function() Adapter.prepareCharacter(hirelingGuid) end)
        local found = false
        for _, member in ipairs(Adapter.partyMembers()) do
            if member.guid == hirelingGuid then
                found = true
                break
            end
        end
        callback(found, found and nil or "BG3 did not add the summoned hireling to the active party")
    end)
end

function Adapter.validateCharacterTemplate(templateId)
    local template = Ext.Template.GetRootTemplate(templateId)
    if not template then
        return false, "template was not found"
    end
    if tostring(template.TemplateType):lower() ~= "character" then
        return false, "template is not a character"
    end
    if not template.Stats or tostring(template.Stats) == "" then
        return false, "template has no character stats"
    end
    return true
end

function Adapter.validateItemTemplate(templateId)
    local template = Ext.Template.GetRootTemplate(templateId)
    if not template then
        return false, "template was not found"
    end
    if tostring(template.TemplateType):lower() ~= "item" then
        return false, "template is not an item"
    end
    return true
end

function Adapter.spawnFixtureTeam(fixture, anchorGuid, layout)
    local anchorX, anchorY, anchorZ = Osi.GetPosition(anchorGuid)
    if type(anchorX) ~= "number" then
        error("could not read the player party position", 2)
    end
    local offsets = layout and layout.enemyOffsets or {
        { 45, -6 },
        { 47, -2 },
        { 47, 2 },
        { 45, 6 },
    }
    local spawned = {}
    local ok, err = pcall(function()
        for index, definition in ipairs(fixture.members) do
            local valid, reason = Adapter.validateCharacterTemplate(definition.templateId)
            if not valid then
                error(string.format("%s: %s", definition.id, reason))
            end
            local offset = offsets[index]
            if type(offset) ~= "table" or type(offset[1]) ~= "number" or type(offset[2]) ~= "number" then
                error("arena layout is missing enemy offset " .. tostring(index))
            end
            local guid = Osi.CreateAt(
                definition.templateId,
                anchorX + offset[1],
                anchorY,
                anchorZ + offset[2],
                1,
                0,
                ""
            )
            if not guid or guid == "" then
                error("engine failed to create " .. definition.id)
            end
            table.insert(spawned, {
                guid = guid,
                name = definition.displayName,
                fixtureMemberId = definition.id,
                level = fixture.level,
                faction = ENEMY_FACTION,
                temporary = true,
            })
            Osi.MakeNPC(guid)
            Osi.SetFaction(guid, ENEMY_FACTION)
            Osi.SetLevel(guid, fixture.level)
            Osi.SetCharacterLootable(guid, 0)
            Osi.SetCanFight(guid, 1)
            Osi.SetCanJoinCombat(guid, 1)
            Osi.SetImmortal(guid, 0)
            ensureDeathSavingThrows(guid)
            safely(function()
                Osi.PROC_CharacterFullRestore(guid)
            end)
        end
    end)
    if not ok then
        for _, member in ipairs(spawned) do
            safely(function()
                Osi.RequestDeleteTemporary(member.guid)
            end)
        end
        error("AI fixture spawn rolled back: " .. tostring(err), 2)
    end
    return spawned
end

function Adapter.deleteTemporary(member)
    safely(function()
        Osi.LeaveCombat(member.guid)
    end)
    safely(function()
        Osi.SetImmortal(member.guid, 0)
    end)
    safely(function()
        Osi.RequestDeleteTemporary(member.guid)
    end)
end

function Adapter.deliverAutomaticReward(offer, recipientGuid)
    local automatic = offer.automatic
    if not automatic.treasureTableId or automatic.treasureTableId == "" then
        error("automatic reward treasure table is not configured", 2)
    end
    for _ = 1, automatic.rolls do
        Osi.GenerateTreasure(recipientGuid, automatic.treasureTableId, offer.level, recipientGuid)
    end
end

function Adapter.randomIndex(maximum)
    maximum = math.max(1, math.floor(tonumber(maximum) or 1))
    return math.random(maximum)
end

local function shuffledCopy(values)
    local shuffled = {}
    for index, value in ipairs(values) do
        shuffled[index] = value
    end
    for index = #shuffled, 2, -1 do
        local swapIndex = Adapter.randomIndex(index)
        shuffled[index], shuffled[swapIndex] = shuffled[swapIndex], shuffled[index]
    end
    return shuffled
end

function Adapter.deliverPreparationBundle(members, level, catalog)
    if type(members) ~= "table" or not members[1] then
        error("arena preparation supplies require a player party", 2)
    end
    level = math.floor(tonumber(level) or 0)
    if not TOTAL_EXPERIENCE[level] then
        error("unsupported preparation level: " .. tostring(level), 2)
    end

    local delivered = { treasureRolls = 0, armoryItems = 0, revivifyScrolls = 0 }
    for _, member in ipairs(members) do
        -- Six level-scaled rolls give a fresh or reconstructed party weapons,
        -- armor, consumables, scrolls, and utility options before its first bout.
        for _ = 1, 6 do
            Osi.GenerateTreasure(member.guid, "RewardMedium", level, member.guid)
            delivered.treasureRolls = delivered.treasureRolls + 1
        end
        if Adapter.validateItemTemplate(REVIVIFY_SCROLL_TEMPLATE) then
            local ok = pcall(function()
                Osi.TemplateAddTo(REVIVIFY_SCROLL_TEMPLATE, member.guid, 2, 1)
            end)
            if ok then
                delivered.revivifyScrolls = delivered.revivifyScrolls + 2
            end
        end
    end

    -- Roll one item per equipment slot for every avatar. Each slot uses its own
    -- shuffled bag, which keeps the result random while preventing the whole
    -- split-screen party from receiving cloned kits.
    local slotOrder = {}
    local pools = {}
    for _, item in ipairs(PreparationLoadout) do
        if not pools[item.slot] then
            pools[item.slot] = {}
            table.insert(slotOrder, item.slot)
        end
        table.insert(pools[item.slot], item)
    end
    for _, slot in ipairs(slotOrder) do
        local bag = shuffledCopy(pools[slot])
        local bagIndex = 1
        for _, member in ipairs(members) do
            if bagIndex > #bag then
                bag = shuffledCopy(pools[slot])
                bagIndex = 1
            end
            local item = bag[bagIndex]
            bagIndex = bagIndex + 1
            if Adapter.validateItemTemplate(item.templateId) then
                local ok = pcall(function()
                    Osi.TemplateAddTo(item.templateId, member.guid, 1, 1)
                end)
                if ok then
                    delivered.armoryItems = delivered.armoryItems + 1
                end
            end
        end
    end
    return delivered
end

function Adapter.deliverVictoryBundle(offer, members)
    if type(members) ~= "table" or not members[1] then
        error("victory loot requires a player party", 2)
    end

    local delivered = { treasureRolls = 0, rareItems = 0 }
    local automatic = offer.automatic or {}
    local treasureTableId = automatic.treasureTableId
    if treasureTableId and treasureTableId ~= "" then
        -- Four rolls per avatar makes the between-round resupply substantial,
        -- and delivering per avatar avoids split-screen inventory ownership bugs.
        for _, member in ipairs(members) do
            for _ = 1, math.max(4, tonumber(automatic.rolls) or 0) do
                local ok = pcall(function()
                    Osi.GenerateTreasure(member.guid, treasureTableId, offer.level, member.guid)
                end)
                if ok then
                    delivered.treasureRolls = delivered.treasureRolls + 1
                end
            end
        end
    end

    -- The native prompt proved unreliable in controller/split-screen play. For
    -- this playable alpha, distribute the complete six-item shortlist round-robin
    -- so players can compare and trade the candidates without blocking the run.
    for index, choice in ipairs(offer.choices or {}) do
        local recipient = members[((index - 1) % #members) + 1]
        local valid = Adapter.validateItemTemplate(choice.templateId)
        if valid then
            local ok = pcall(function()
                Osi.TemplateAddTo(choice.templateId, recipient.guid, 1, 1)
            end)
            if ok then
                delivered.rareItems = delivered.rareItems + 1
            end
        end
    end
    return delivered
end

function Adapter.deliverItem(templateId, recipientGuid)
    local valid, reason = Adapter.validateItemTemplate(templateId)
    if not valid then
        error("reward item is invalid: " .. reason, 2)
    end
    Osi.TemplateAddTo(templateId, recipientGuid, 1, 1)
end

function Adapter.awardPartyToLevel(members, targetLevel)
    local targetExperience = TOTAL_EXPERIENCE[targetLevel]
    if not targetExperience then
        error("unsupported arena target level: " .. tostring(targetLevel), 2)
    end
    -- In ordinary parties AddExplorationExperience may propagate to everyone,
    -- while local split-screen avatars can have distinct progression ownership.
    -- Re-read before each award: a party-wide first call makes later calls no-ops,
    -- but an independently owned avatar still receives exactly its missing XP.
    local awardedCount = 0
    for _, member in ipairs(members) do
        if member.isAvatar == false then
            local currentLevel = tonumber(member.level) or tonumber(Osi.GetLevel(member.guid)) or 1
            if currentLevel < targetLevel then
                Osi.SetLevel(member.guid, targetLevel)
                awardedCount = awardedCount + 1
            end
        else
            local entity = Ext.Entity.Get(member.guid)
            if not entity or not entity.Experience then
                error("experience data is unavailable for " .. (member.name or member.guid), 2)
            end
            local current = tonumber(entity.Experience.TotalExperience) or 0
            local gain = targetExperience - current
            if gain > 0 then
                Osi.AddExplorationExperience(member.guid, gain)
                awardedCount = awardedCount + 1
            end
        end
    end
    return awardedCount
end

-- AutoKit engine access ------------------------------------------------------

local EQUIP_SLOTS = {
    "Helmet", "Breast", "Cloak", "MeleeMainHand", "MeleeOffHand", "RangedMainHand",
    "Ring", "Ring2", "Boots", "Gloves", "Amulet",
}
local STAT_FIELDS = {
    "Slot", "ArmorClass", "ArmorType", "Rarity", "Boosts", "DefaultBoosts", "PassivesOnEquip",
    "Proficiency Group", "Weapon Properties", "Damage",
}

local function bareUuid(guid)
    local uuid = tostring(guid or ""):match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)$")
    return uuid or guid
end

local function flatten(value)
    if type(value) == "table" then
        local parts = {}
        for _, part in pairs(value) do
            table.insert(parts, tostring(part))
        end
        return table.concat(parts, ";")
    end
    return value
end

function Adapter.statExists(name)
    local ok, stat = pcall(function()
        return Ext.Stats.Get(name)
    end)
    return ok and stat ~= nil
end

function Adapter.itemStatFields(itemGuid)
    local statsId = safely(function()
        return Osi.GetStatString(itemGuid)
    end)
    if not statsId or statsId == "" then
        statsId = safely(function()
            local entity = Ext.Entity.Get(itemGuid)
            return entity and entity.Data and entity.Data.StatsId
        end)
    end
    if not statsId or statsId == "" then
        return nil
    end
    local stat = safely(function()
        return Ext.Stats.Get(statsId)
    end)
    if not stat then
        return nil
    end
    local display = safely(function()
        return translatedName(itemGuid)
    end)
    local fields = { id = bareUuid(itemGuid), Name = (display and display ~= itemGuid) and display or statsId }
    for _, key in ipairs(STAT_FIELDS) do
        local ok, value = pcall(function()
            return stat[key]
        end)
        if ok and value ~= nil then
            fields[key] = flatten(value)
        end
    end
    return fields
end

function Adapter.equippedItems(guid)
    local result = {}
    for _, slot in ipairs(EQUIP_SLOTS) do
        local itemGuid = safely(function()
            return Osi.GetEquippedItem(guid, slot)
        end)
        if itemGuid and itemGuid ~= "" then
            local fields = Adapter.itemStatFields(itemGuid)
            if fields then
                result[slot] = fields
            end
        end
    end
    return result
end

function Adapter.characterItems(guid)
    local items = {}
    local seen = {}
    local function add(itemGuid)
        if type(itemGuid) ~= "string" or itemGuid == "" or seen[bareUuid(itemGuid)] then
            return
        end
        seen[bareUuid(itemGuid)] = true
        local fields = Adapter.itemStatFields(itemGuid)
        if fields then
            table.insert(items, fields)
        end
    end
    safely(function()
        local entity = Ext.Entity.Get(guid)
        local owner = entity and entity.InventoryOwner
        for _, inventory in pairs(owner and owner.Inventories or {}) do
            local container = inventory.InventoryContainer
            for _, entry in pairs(container and container.Items or {}) do
                local item = entry.Item
                add(item and item.Uuid and item.Uuid.EntityUuid)
            end
        end
    end)
    for _, fields in pairs(Adapter.equippedItems(guid)) do
        add(fields.id)
    end
    return items
end

function Adapter.equipItem(guid, itemGuid)
    Osi.Equip(guid, itemGuid, 1, 0, 1)
end

function Adapter.addSpell(guid, spell)
    Osi.AddSpell(guid, spell, 0, 1)
end

function Adapter.addPassive(guid, passive)
    if Osi.HasPassive(guid, passive) ~= 1 then
        Osi.AddPassive(guid, passive)
    end
end

function Adapter.addBoosts(guid, boost)
    Osi.AddBoosts(guid, boost, "AstralArena_AutoKit", "")
end

return Adapter
