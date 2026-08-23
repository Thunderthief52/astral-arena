local H = require("tests.test_helper")
local Bootstrap = require("AstralArena.Core.ArenaBootstrap")

H.test("arena bootstrap preserves native level one through five choices", function()
    local state = Bootstrap.new({ id = "bootstrap-1", targetLevel = 5 })
    H.equal(Bootstrap.begin(state, 1, 2), 5)
    Bootstrap.markExperienceAwarded(state)
    H.equal(state.phase, "awaiting_level_up")
    Bootstrap.confirmPartyLevel(state, 5, 2)
    Bootstrap.activate(state)
    H.equal(state.phase, "completed")
end)

H.test("arena bootstrap rejects an existing higher-level party", function()
    local state = Bootstrap.new({ id = "bootstrap-2" })
    H.raises(function() Bootstrap.begin(state, 2, 1) end, "level 1")
end)

H.test("arena bootstrap rejects party membership changes", function()
    local state = Bootstrap.new({ id = "bootstrap-3" })
    Bootstrap.begin(state, 1, 2)
    Bootstrap.markExperienceAwarded(state)
    H.raises(function() Bootstrap.confirmPartyLevel(state, 5, 1) end, "membership changed")
end)

H.test("arena bootstrap accepts only followers recruited during onboarding", function()
    local state = Bootstrap.new({ id = "bootstrap-4", targetLevel = 3 })
    Bootstrap.begin(state, 1, {
        { guid = "avatar-a" },
        { guid = "avatar-b" },
    })
    Bootstrap.markExperienceAwarded(state)
    Bootstrap.confirmPartyLevel(state, 3, {
        { guid = "avatar-a" },
        { guid = "avatar-b" },
        { guid = "hireling-fighter" },
        { guid = "hireling-cleric" },
    }, {
        ["hireling-fighter"] = true,
        ["hireling-cleric"] = true,
    })
    H.equal(state.partySize, 4)
    H.equal(state.phase, "ready")
end)

H.test("arena bootstrap still rejects an unapproved replacement", function()
    local state = Bootstrap.new({ id = "bootstrap-5", targetLevel = 3 })
    Bootstrap.begin(state, 1, { { guid = "avatar-a" }, { guid = "avatar-b" } })
    Bootstrap.markExperienceAwarded(state)
    H.raises(function()
        Bootstrap.confirmPartyLevel(state, 3, {
            { guid = "avatar-a" },
            { guid = "unexpected" },
        }, { ["hireling-fighter"] = true })
    end, "membership changed")
end)
