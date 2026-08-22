local Adapter = {}

local REVIVIFY_SCROLL_TEMPLATE = "c1c3e4fb-d68c-4e10-afdc-d4550238d50e"
local WITHERS_TEMPLATE = "edb2601b-7f01-44e5-84df-7513a695d4eb"
local WITHERS_LEDGER_TEMPLATE = "14d9b664-b4e4-4e22-a83f-7fafd09f61f5"

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

function Adapter.getGold(guid)
    return math.max(0, tonumber(Osi.GetGold(guid)) or 0)
end

function Adapter.addGold(guid, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount ~= 0 then
        Osi.AddGold(guid, amount)
    end
end

local function entityIsInArena(guid)
    if not guid or guid == "" then
        return false
    end
    return safely(function()
        return Ext.Entity.Get(guid) ~= nil and Osi.GetRegion(guid) == "AA_Arena_Main"
    end) == true
end

function Adapter.ensureCampService(_, state)
    state = state or {}
    local withersGuid = state.withersGuid
    if not entityIsInArena(withersGuid) then
        withersGuid = safely(function()
            return Osi.CreateAt(WITHERS_TEMPLATE, 10.5, 0.0, 10.5, 1, 0, "")
        end)
        if not withersGuid or withersGuid == "" then
            error("engine could not create the arena Withers", 2)
        end
        safely(function() Osi.MakeNPC(withersGuid) end)
        safely(function() Osi.SetOnStage(withersGuid, 1) end)
        safely(function() Osi.SetCanFight(withersGuid, 0) end)
        safely(function() Osi.SetCanJoinCombat(withersGuid, 0) end)
        safely(function() Osi.SetImmortal(withersGuid, 1) end)
        safely(function() Osi.SetCharacterLootable(withersGuid, 0) end)
        -- Withers supplies the recognizable camp presence; the nearby ledger
        -- owns the deterministic custom interaction and avoids campaign dialog.
        safely(function() Osi.SetCanInteract(withersGuid, 0) end)
    end

    local ledgerGuid = state.ledgerGuid
    if not entityIsInArena(ledgerGuid) then
        ledgerGuid = safely(function()
            return Osi.CreateAt(WITHERS_LEDGER_TEMPLATE, 8.0, 0.15, 9.5, 0, 0, "")
        end)
        if not ledgerGuid or ledgerGuid == "" then
            Ext.Utils.PrintWarning("[Astral Arena] Engine could not create Withers' arena ledger; automatic hireling onboarding remains available.")
            return { withersGuid = withersGuid }
        end
        safely(function() Osi.SetOnStage(ledgerGuid, 1) end)
        safely(function() Osi.SetCanPickUp(ledgerGuid, 0) end)
        safely(function() Osi.SetCanInteract(ledgerGuid, 1) end)
    end
    return { withersGuid = withersGuid, ledgerGuid = ledgerGuid }
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
        { 30, -6 },
        { 32, -2 },
        { 32, 2 },
        { 30, 6 },
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

    -- A random table alone cannot guarantee that every class sees a usable
    -- weapon or armour piece. Build a shared, tradeable armory from the audited
    -- reward catalog as well, preferring the newest tier when an advanced save
    -- starts directly at level 8 or later.
    local armory = {}
    for _, item in ipairs(catalog or {}) do
        local minimumLevel = tonumber(item.minimumLevel) or 1
        local maximumLevel = tonumber(item.maximumLevel) or 12
        if level >= minimumLevel and level <= maximumLevel then
            table.insert(armory, item)
        end
    end
    table.sort(armory, function(left, right)
        local leftLevel = tonumber(left.minimumLevel) or 1
        local rightLevel = tonumber(right.minimumLevel) or 1
        if leftLevel ~= rightLevel then
            return leftLevel > rightLevel
        end
        return tostring(left.id) < tostring(right.id)
    end)
    for index = 1, math.min(12, #armory) do
        local item = armory[index]
        local recipient = members[((index - 1) % #members) + 1]
        if Adapter.validateItemTemplate(item.templateId) then
            local ok = pcall(function()
                Osi.TemplateAddTo(item.templateId, recipient.guid, 1, 1)
            end)
            if ok then
                delivered.armoryItems = delivered.armoryItems + 1
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
