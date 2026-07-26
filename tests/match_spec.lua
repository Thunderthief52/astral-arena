local H = require("tests.test_helper")
local Match = require("AstralArena.Core.Match")

local function readyMatch()
    local session = Match.new({
        id = "QF1",
        leftEntrantId = "p1",
        rightEntrantId = "p8",
        level = 5,
        maxPartySize = 4,
    })
    Match.setRoster(session, "left", { "l1", "l2", "l3", "l4" })
    Match.setRoster(session, "right", { "r1", "r2", "r3", "r4" })
    Match.setReady(session, "left")
    Match.setReady(session, "right")
    Match.beginPreparation(session)
    Match.beginCombat(session)
    return session
end

H.test("a match follows the assembly preparation combat lifecycle", function()
    local session = readyMatch()
    H.equal(session.phase, "combat")
    H.equal(session.level, 5)
end)

H.test("eliminating one roster resolves the opposing winner", function()
    local session = readyMatch()
    local winner, side = Match.evaluateAlive(session, {
        l1 = true,
        l2 = true,
        l3 = true,
        l4 = true,
    })
    H.equal(winner, "p1")
    H.equal(side, "left")
    H.equal(session.phase, "completed")
    H.equal(session.loserEntrantId, "p8")
end)

H.test("simultaneous elimination records a draw", function()
    local session = readyMatch()
    local winner, result = Match.evaluateAlive(session, {})
    H.equal(winner, nil)
    H.equal(result, "draw")
    H.equal(session.resolution, "draw")
end)

H.test("forfeit resolves before combat begins", function()
    local session = Match.new({ id = "QF1", leftEntrantId = "p1", rightEntrantId = "p8" })
    local winner = Match.forfeit(session, "left")
    H.equal(winner, "p8")
    H.equal(session.resolution, "forfeit")
end)

H.test("the same character cannot appear on both teams", function()
    local session = Match.new({ id = "QF1", leftEntrantId = "p1", rightEntrantId = "p8" })
    Match.setRoster(session, "left", { "shared" })
    H.raises(function()
        Match.setRoster(session, "right", { "shared" })
    end, "both teams")
end)
