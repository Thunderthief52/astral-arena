local Util
if Ext and Ext.Require then
    Util = Ext.Require("AstralArena/Core/Util.lua")
else
    Util = require("AstralArena.Core.Util")
end

local Roster = {}

local function isUserId(userId)
    return type(userId) == "number" and userId >= 0 and userId < 65535
end

local function copyAndSort(members)
    local values = Util.copy(members)
    table.sort(values, function(a, b)
        local aUser = isUserId(a.avatarUserId) and a.avatarUserId or 65535
        local bUser = isUserId(b.avatarUserId) and b.avatarUserId or 65535
        if aUser ~= bUser then
            return aUser < bUser
        end
        return a.guid < b.guid
    end)
    return values
end

local function validateMember(member, expectedLevel)
    if member.isDead then
        error((member.name or member.guid) .. " is dead and cannot enter sparring", 3)
    end
    if member.inCombat then
        error((member.name or member.guid) .. " is already in combat", 3)
    end
    if member.level ~= expectedLevel then
        error(string.format(
            "all sparring characters must have the same level; %s is level %s instead of %s",
            member.name or member.guid,
            tostring(member.level),
            tostring(expectedLevel)
        ), 3)
    end
end

local function validateGroups(groups, maximumPartySize)
    for _, group in ipairs(groups) do
        if #group.members < 1 or #group.members > maximumPartySize then
            error(string.format(
                "%s must control between 1 and %d party members; found %d",
                group.label,
                maximumPartySize,
                #group.members
            ), 3)
        end
    end

    local expectedLevel = groups[1].members[1].level
    if type(expectedLevel) ~= "number" then
        error("party member level is missing", 3)
    end
    for _, group in ipairs(groups) do
        for _, member in ipairs(group.members) do
            validateMember(member, expectedLevel)
        end
    end
    return expectedLevel
end

function Roster.groupByUser(members)
    if type(members) ~= "table" then
        error("members must be a table", 2)
    end

    local byUser = {}
    for _, member in ipairs(members) do
        if type(member) ~= "table" then
            error("each party member must be a table", 2)
        end
        Util.assertNonEmptyString(member.guid, "party member GUID")
        if isUserId(member.userId) then
            byUser[member.userId] = byUser[member.userId] or {}
            table.insert(byUser[member.userId], Util.copy(member))
        end
    end

    local groups = {}
    for userId, userMembers in pairs(byUser) do
        table.sort(userMembers, function(a, b)
            return a.guid < b.guid
        end)
        table.insert(groups, {
            userId = userId,
            entrantId = "user-" .. tostring(userId),
            label = "User " .. tostring(userId),
            members = userMembers,
        })
    end
    table.sort(groups, function(a, b)
        return a.userId < b.userId
    end)
    return groups
end

function Roster.avatarMembers(members)
    local avatars = {}
    for _, member in ipairs(members) do
        if member.isAvatar then
            table.insert(avatars, member)
        end
    end
    return copyAndSort(avatars)
end

function Roster.autoTeams(members, maximumPartySize)
    maximumPartySize = maximumPartySize or 4
    local groups = Roster.groupByUser(members)
    if #groups ~= 2 then
        error(string.format("automatic sparring requires exactly two assigned users; found %d", #groups), 2)
    end

    local level = validateGroups(groups, maximumPartySize)
    return {
        level = level,
        mode = "assigned-users",
        left = groups[1],
        right = groups[2],
    }
end

function Roster.splitScreenTeams(members)
    local avatars = Roster.avatarMembers(members)
    if #avatars ~= 2 then
        error(string.format(
            "split-screen fallback requires exactly two player avatars; found %d",
            #avatars
        ), 2)
    end

    local leftUserId = isUserId(avatars[1].avatarUserId) and avatars[1].avatarUserId or 0
    local rightUserId = isUserId(avatars[2].avatarUserId) and avatars[2].avatarUserId or 1
    if rightUserId == leftUserId then
        leftUserId = 0
        rightUserId = 1
    end

    local groups = {
        {
            userId = leftUserId,
            entrantId = "couch-player-1",
            label = "Couch Player 1",
            members = { avatars[1] },
        },
        {
            userId = rightUserId,
            entrantId = "couch-player-2",
            label = "Couch Player 2",
            members = { avatars[2] },
        },
    }
    local level = validateGroups(groups, 1)
    return {
        level = level,
        mode = "split-screen-avatars",
        ignoredPartyMembers = #members - 2,
        left = groups[1],
        right = groups[2],
    }
end

function Roster.resolveTeams(members, maximumPartySize)
    local groups = Roster.groupByUser(members)
    if #groups == 2 then
        return Roster.autoTeams(members, maximumPartySize)
    end
    if #groups < 2 then
        return Roster.splitScreenTeams(members)
    end
    error(string.format(
        "automatic sparring found %d assigned users; reduce the session to two users",
        #groups
    ), 2)
end

function Roster.playerParty(members, maximumPartySize)
    maximumPartySize = maximumPartySize or 4
    if type(members) ~= "table" or #members < 1 or #members > maximumPartySize then
        error(string.format(
            "AI arena requires between 1 and %d active party members; found %d",
            maximumPartySize,
            type(members) == "table" and #members or 0
        ), 2)
    end

    local values = copyAndSort(members)
    local expectedLevel = values[1].level
    if type(expectedLevel) ~= "number" then
        error("party member level is missing", 2)
    end
    for _, member in ipairs(values) do
        Util.assertNonEmptyString(member.guid, "party member GUID")
        validateMember(member, expectedLevel)
    end

    return {
        userId = values[1].userId,
        entrantId = "player-party",
        label = "Player Party",
        members = values,
        level = expectedLevel,
    }
end

function Roster.guids(group)
    local values = {}
    for _, member in ipairs(group.members) do
        table.insert(values, member.guid)
    end
    return values
end

return Roster
