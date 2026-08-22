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

H.test("split-screen fallback separates two player avatars when ownership collapses", function()
    local left = member("left-avatar", 0, 5)
    left.isAvatar = true
    left.avatarUserId = 0
    local right = member("right-avatar", 0, 5)
    right.isAvatar = true
    right.avatarUserId = 1
    local companion = member("companion", 0, 5)

    local teams = Roster.resolveTeams({ left, right, companion }, 4)
    H.equal(teams.mode, "split-screen-avatars")
    H.equal(teams.left.members[1].guid, "left-avatar")
    H.equal(teams.right.members[1].guid, "right-avatar")
    H.equal(teams.ignoredPartyMembers, 1)
end)

H.test("split-screen fallback creates distinct virtual sides for duplicate avatar user IDs", function()
    local left = member("a", 0, 5)
    left.isAvatar = true
    left.avatarUserId = 0
    local right = member("b", 0, 5)
    right.isAvatar = true
    right.avatarUserId = 0

    local teams = Roster.resolveTeams({ left, right }, 4)
    H.equal(teams.left.userId, 0)
    H.equal(teams.right.userId, 1)
    H.equal(teams.left.entrantId, "couch-player-1")
    H.equal(teams.right.entrantId, "couch-player-2")
end)

H.test("split-screen fallback refuses to guess when avatar count is ambiguous", function()
    local onlyAvatar = member("a", 0, 5)
    onlyAvatar.isAvatar = true
    H.raises(function()
        Roster.resolveTeams({ onlyAvatar, member("companion", 0, 5) }, 4)
    end, "exactly two player avatars")
end)

H.test("split-screen fallback keeps same-level safety validation", function()
    local left = member("a", 0, 5)
    left.isAvatar = true
    local right = member("b", 0, 6)
    right.isAvatar = true
    H.raises(function()
        Roster.resolveTeams({ left, right }, 4)
    end, "same level")
end)

H.test("AI arena treats online or couch-controlled characters as one party", function()
    local left = member("left", 0, 5)
    left.isAvatar = true
    local right = member("right", 1, 5)
    right.isAvatar = true
    local party = Roster.playerParty({ left, right }, 4)
    H.equal(party.level, 5)
    H.equal(#party.members, 2)
    H.equal(party.entrantId, "player-party")
end)

H.test("AI arena rejects oversized and mixed-level parties", function()
    H.raises(function()
        Roster.playerParty({ member("a", 0, 5), member("b", 0, 6) }, 4)
    end, "same level")
    H.raises(function()
        Roster.playerParty({
            member("a", 0), member("b", 0), member("c", 0), member("d", 0), member("e", 0),
        }, 4)
    end, "between 1 and 4")
end)
