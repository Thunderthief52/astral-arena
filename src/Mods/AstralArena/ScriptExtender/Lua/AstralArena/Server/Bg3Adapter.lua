local Adapter = {}

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

return Adapter
