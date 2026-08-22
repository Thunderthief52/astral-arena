local Adapter = {}

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

function Adapter.prepareArenaSite(members, site)
    if type(members) ~= "table" or not members[1] then
        error("arena site preparation requires a player party", 2)
    end
    if type(site) ~= "table" or type(site.offset) ~= "table" then
        error("arena site definition is invalid", 2)
    end
    if not stagingOrigin then
        stagingOrigin = requirePosition(members[1].guid)
    end
    teleportParty(members, stagingOrigin, site)
end

function Adapter.returnPartyToStaging(members)
    if not stagingOrigin or type(members) ~= "table" then
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
    Osi.EnterCombat(leftGuid, rightGuid)
    Osi.EnterCombat(rightGuid, leftGuid)
end

function Adapter.isAlive(guid)
    if Osi.IsDead(guid) == 1 then
        return false
    end
    local hitpoints = Osi.GetHitpoints(guid)
    return type(hitpoints) == "number" and hitpoints > 0
end

function Adapter.markDefeated(guid)
    -- Native zero-hit-point handling supplies the downed pose, initiative turn,
    -- and DeathSavingThrows rolls. Hidden protection prevents the AI from farming
    -- automatic failures while allies still have a chance to help the actor up.
    safely(function()
        Osi.ApplyStatus(guid, "INVULNERABLE_NOT_SHOWN", -1.0, 1, guid)
    end)
end

function Adapter.markRecovered(guid)
    safely(function()
        Osi.RemoveStatus(guid, "INVULNERABLE_NOT_SHOWN", guid)
    end)
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
    local wasDown = not Adapter.isAlive(member.guid)
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
    if Osi.IsDead(member.guid) == 1 then
        safely(function()
            Osi.Resurrect(member.guid)
        end)
    end
    safely(function()
        Osi.SetCanFight(member.guid, 1)
    end)
    safely(function()
        Osi.SetCanJoinCombat(member.guid, 1)
    end)
    safely(function()
        Osi.SetImmortal(member.guid, 0)
    end)
    ensureDeathSavingThrows(member.guid)
    if wasDown then
        -- A wave transition cannot leave a player stranded at zero HP, but it
        -- is intentionally not a short or long rest. Surviving characters keep
        -- their current health, spell slots, class resources, and cooldowns.
        safely(function()
            Osi.SetHitpointsPercentage(member.guid, 50)
        end)
    end
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

function Adapter.schedule(delayMilliseconds, callback)
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
        { 8, -3 },
        { 10, -1 },
        { 10, 1 },
        { 8, 3 },
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
    for _, member in ipairs(members) do
        local entity = Ext.Entity.Get(member.guid)
        if not entity or not entity.Experience then
            error("experience data is unavailable for " .. (member.name or member.guid), 2)
        end
    end

    -- In ordinary parties AddExplorationExperience may propagate to everyone,
    -- while local split-screen avatars can have distinct progression ownership.
    -- Re-read before each award: a party-wide first call makes later calls no-ops,
    -- but an independently owned avatar still receives exactly its missing XP.
    local awardedCount = 0
    for _, member in ipairs(members) do
        local entity = Ext.Entity.Get(member.guid)
        local current = tonumber(entity.Experience.TotalExperience) or 0
        local gain = targetExperience - current
        if gain > 0 then
            Osi.AddExplorationExperience(member.guid, gain)
            awardedCount = awardedCount + 1
        end
    end
    return awardedCount
end

return Adapter
