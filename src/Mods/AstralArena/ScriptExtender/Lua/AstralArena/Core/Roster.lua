local Util
if Ext and Ext.Require then
    Util = Ext.Require("AstralArena/Core/Util.lua")
else
    Util = require("AstralArena.Core.Util")
end

local Roster = {}

local function isReservedUserId(userId)
    return type(userId) == "number" and userId >= 0 and userId < 65535
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
        if isReservedUserId(member.userId) then
            byUser[member.userId] = byUser[member.userId] or {}
            table.insert(byUser[member.userId], Util.copy(member))
        end
    end

    local groups = {}
    for userId, userMembers in pairs(byUser) do
        table.sort(userMembers, function(a, b)
            return a.guid < b.guid
        end)
        table.insert(groups, { userId = userId, members = userMembers })
    end
    table.sort(groups, function(a, b)
        return a.userId < b.userId
    end)
    return groups
end

function Roster.autoTeams(members, maximumPartySize)
    maximumPartySize = maximumPartySize or 4
    local groups = Roster.groupByUser(members)
    if #groups ~= 2 then
        error(string.format("automatic sparring requires exactly two assigned users; found %d", #groups), 2)
    end

    for _, group in ipairs(groups) do
        if #group.members < 1 or #group.members > maximumPartySize then
            error(string.format(
                "user %d must control between 1 and %d party members; found %d",
                group.userId,
                maximumPartySize,
                #group.members
            ), 2)
        end
    end

    local expectedLevel = groups[1].members[1].level
    if type(expectedLevel) ~= "number" then
        error("party member level is missing", 2)
    end
    for _, group in ipairs(groups) do
        for _, member in ipairs(group.members) do
            if member.isDead then
                error((member.name or member.guid) .. " is dead and cannot enter sparring", 2)
            end
            if member.inCombat then
                error((member.name or member.guid) .. " is already in combat", 2)
            end
            if member.level ~= expectedLevel then
                error(string.format(
                    "all sparring characters must have the same level; %s is level %s instead of %s",
                    member.name or member.guid,
                    tostring(member.level),
                    tostring(expectedLevel)
                ), 2)
            end
        end
    end

    return {
        level = expectedLevel,
        left = groups[1],
        right = groups[2],
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
