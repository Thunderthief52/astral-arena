local H = require("tests.test_helper")
local Roster = require("AstralArena.Core.Roster")

local function member(guid, userId, level)
    return { guid = guid, name = guid, userId = userId, level = level or 5 }
end

H.test("party members are grouped by their assigned multiplayer user", function()
    local groups = Roster.groupByUser({
        member("b", 1),
        member("a", 0),
        member("c", 0),
        member("unassigned", 65535),
    })
    H.equal(#groups, 2)
    H.equal(groups[1].userId, 0)
    H.equal(groups[1].members[1].guid, "a")
    H.equal(groups[2].userId, 1)
end)

H.test("automatic teams require exactly two assigned users", function()
    H.raises(function()
        Roster.autoTeams({ member("a", 0) })
    end, "exactly two")
end)

H.test("automatic teams allow one to four characters per user", function()
    local teams = Roster.autoTeams({
        member("a", 0),
        member("b", 0),
        member("c", 1),
        member("d", 1),
    })
    H.equal(teams.level, 5)
    H.equal(#teams.left.members, 2)
    H.equal(#teams.right.members, 2)
end)

H.test("automatic teams reject mixed character levels", function()
    H.raises(function()
        Roster.autoTeams({ member("a", 0, 5), member("b", 1, 6) })
    end, "same level")
end)

H.test("automatic teams reject characters already in combat", function()
    local fighting = member("a", 0, 5)
    fighting.inCombat = true
    H.raises(function()
        Roster.autoTeams({ fighting, member("b", 1, 5) })
    end, "already in combat")
end)
