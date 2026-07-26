local H = require("tests.test_helper")

local previousExt = _G.Ext
_G.Ext = {
    Require = function(path)
        return require((path:gsub("%.lua$", ""):gsub("/", ".")))
    end,
}
local SoloArena = require("AstralArena.Server.SoloArena")
local Fixtures = require("AstralArena.Shared.AIFixtures")
local Catalog = require("AstralArena.Shared.RewardCatalog")
_G.Ext = previousExt

local function fakeAdapter()
    local adapter = {
        alive = {}, queue = {}, restored = {}, deleted = {}, delivered = {}, experienceTargets = {},
    }
    function adapter.partyMembers()
        return {
            { guid = "player-a", name = "Player A", userId = 0, level = adapter.partyLevel or 5, faction = "player" },
            { guid = "player-b", name = "Player B", userId = 1, level = adapter.partyLevel or 5, faction = "player" },
        }
    end
    function adapter.validateCharacterTemplate() return true end
    function adapter.validateItemTemplate() return true end
    function adapter.spawnFixtureTeam(fixture)
        local values = {}
        for index, member in ipairs(fixture.members) do
            local guid = "enemy-" .. index
            adapter.alive[guid] = true
            table.insert(values, { guid = guid, name = member.displayName, faction = "enemy", temporary = true })
        end
        adapter.alive["player-a"] = true
        adapter.alive["player-b"] = true
        return values
    end
    function adapter.prepareCharacter() end
    function adapter.makeHostile() end
    function adapter.enterCombat() end
    function adapter.isAlive(guid) return adapter.alive[guid] end
    function adapter.markDefeated() end
    function adapter.restoreCharacter(member) table.insert(adapter.restored, member.guid) end
    function adapter.deleteTemporary(member) table.insert(adapter.deleted, member.guid) end
    function adapter.schedule(_, callback) table.insert(adapter.queue, callback) end
    function adapter.notify() end
    function adapter.deliverAutomaticReward(_, recipient) table.insert(adapter.delivered, "auto:" .. recipient) end
    function adapter.deliverItem(_, recipient) table.insert(adapter.delivered, "item:" .. recipient) end
    function adapter.awardPartyToLevel(_, target) table.insert(adapter.experienceTargets, target) end
    return adapter
end

local function arena(adapter)
    return SoloArena.new(adapter, function() end, Fixtures, Catalog)
end

H.test("AI arena spawns a four-member level-five fixture", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    local match = subject:start({ countdownSeconds = 0 })
    H.equal(match.phase, "combat")
    H.equal(match.level, 5)
    H.equal(#subject.active.teams.right.members, 4)
end)

H.test("AI victory deletes enemies and opens the six-choice reward", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    for index = 1, 4 do adapter.alive["enemy-" .. index] = false end
    table.remove(adapter.queue, 1)()
    H.equal(subject.active, nil)
    H.equal(#adapter.deleted, 4)
    H.equal(subject.run.phase, "awaiting_reward")
    H.equal(#subject.run.pendingReward.offer.choices, 6)
end)

H.test("reward selection delivers automatic loot and one item then awards level-eight XP", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    for index = 1, 4 do adapter.alive["enemy-" .. index] = false end
    table.remove(adapter.queue, 1)()
    subject:pick(2, 2)
    H.equal(adapter.delivered[1], "auto:player-b")
    H.equal(adapter.delivered[2], "item:player-b")
    H.equal(adapter.experienceTargets[1], 8)
    H.equal(subject.run.phase, "awaiting_level_up")
end)

H.test("continue refuses until every party member reaches the expected level", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    for index = 1, 4 do adapter.alive["enemy-" .. index] = false end
    table.remove(adapter.queue, 1)()
    subject:pick(1, 1)
    H.raises(function() subject:continue() end, "level 8")
    adapter.partyLevel = 8
    local match = subject:continue()
    H.equal(match.level, 8)
end)

H.test("AI arena abort restores players and deletes temporary enemies", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    subject:abort("test")
    H.equal(subject.active, nil)
    H.equal(#adapter.restored, 2)
    H.equal(#adapter.deleted, 4)
    H.equal(subject.run.phase, "seeking_opponent")
end)
