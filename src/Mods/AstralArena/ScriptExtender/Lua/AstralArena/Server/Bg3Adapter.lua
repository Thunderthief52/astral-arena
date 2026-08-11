local Adapter = {}

local ENEMY_FACTION = "64321d50-d516-b1b2-cfac-2eb773de1ff6"
local TOTAL_EXPERIENCE = {
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
    Osi.SetCanFight(guid, 1)
    Osi.SetCanJoinCombat(guid, 1)
    Osi.SetImmortal(guid, 1)
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
    return type(hitpoints) == "number" and hitpoints > 1
end

function Adapter.markDefeated(guid)
    safely(function()
        Osi.SetCanFight(guid, 0)
    end)
    safely(function()
        Osi.LeaveCombat(guid)
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

function Adapter.schedule(delayMilliseconds, callback)
    Ext.Timer.WaitFor(delayMilliseconds, callback)
end

function Adapter.notify(guid, message)
    safely(function()
        Osi.ShowNotification(guid, message)
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
            Osi.SetImmortal(guid, 1)
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
    local lowestExperience = nil
    for _, member in ipairs(members) do
        local entity = Ext.Entity.Get(member.guid)
        if not entity or not entity.Experience then
            error("experience data is unavailable for " .. (member.name or member.guid), 2)
        end
        local current = tonumber(entity.Experience.TotalExperience) or 0
        if current >= targetExperience and Osi.GetLevel(member.guid) < targetLevel then
            error("experience curve mismatch; vanilla XP thresholds are required", 2)
        end
        lowestExperience = math.min(lowestExperience or current, current)
    end

    local gain = targetExperience - (lowestExperience or 0)
    if gain > 0 then
        -- AddExplorationExperience is party-wide; one call avoids multiplying XP in co-op.
        Osi.AddExplorationExperience(members[1].guid, gain)
    end
end

return Adapter
