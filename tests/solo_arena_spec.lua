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
local Layouts = require("AstralArena.Shared.ArenaLayouts")
local Sites = require("AstralArena.Shared.ArenaSites")
_G.Ext = previousExt

local function fakeAdapter()
    local adapter = {
        alive = {}, queue = {}, restored = {}, recovered = {}, deleted = {}, delivered = {}, experienceTargets = {}, layouts = {}, sites = {}, notifications = {}, stagingReturns = 0, fullRests = 0, menus = {}, partySize = 2, spawnCalls = 0, interWaveRecoveries = 0,
    }
    function adapter.partyMembers()
        local ids = { "player-a", "player-b", "player-c", "player-d" }
        local members = {}
        for index = 1, adapter.partySize do
            table.insert(members, {
                guid = ids[index],
                name = "Player " .. tostring(index),
                userId = index - 1,
                level = adapter.partyLevels and adapter.partyLevels[index] or adapter.partyLevel or 5,
                faction = "player",
            })
        end
        return members
    end
    function adapter.validateCharacterTemplate() return true end
    function adapter.validateItemTemplate() return true end
    function adapter.isPartyInArena() return adapter.inArena ~= false end
    function adapter.spawnFixtureTeam(fixture, _, layout)
        adapter.spawnCalls = adapter.spawnCalls + 1
        table.insert(adapter.layouts, layout)
        local values = {}
        for index, member in ipairs(fixture.members) do
            local guid = string.format("enemy-%d-%d", adapter.spawnCalls, index)
            adapter.alive[guid] = true
            table.insert(values, { guid = guid, name = member.displayName, faction = "enemy", temporary = true })
        end
        for _, member in ipairs(adapter.partyMembers()) do
            adapter.alive[member.guid] = true
        end
        return values
    end
    function adapter.prepareCharacter() end
    function adapter.prepareArenaSite(_, site) table.insert(adapter.sites, site) end
    function adapter.returnPartyToStaging() adapter.stagingReturns = adapter.stagingReturns + 1 end
    function adapter.fullRestParty() adapter.fullRests = adapter.fullRests + 1 end
    function adapter.makeHostile() end
    function adapter.enterCombat() end
    function adapter.isAlive(guid) return adapter.alive[guid] end
    function adapter.markDefeated() end
    function adapter.markRecovered(guid) table.insert(adapter.recovered, guid) end
    function adapter.restoreCharacter(member) table.insert(adapter.restored, member.guid) end
    function adapter.recoverBetweenWaves(member)
        adapter.interWaveRecoveries = adapter.interWaveRecoveries + 1
        if not adapter.alive[member.guid] then
            adapter.alive[member.guid] = true
            table.insert(adapter.recovered, member.guid)
        end
    end
    function adapter.deleteTemporary(member) table.insert(adapter.deleted, member.guid) end
    function adapter.schedule(_, callback) table.insert(adapter.queue, callback) end
    function adapter.notify(guid, message)
        table.insert(adapter.notifications, { guid = guid, message = message })
    end
    function adapter.menuOwner() return "player-a" end
    function adapter.openYesNo(guid, key, message)
        table.insert(adapter.menus, { guid = guid, key = key, message = message })
    end
    function adapter.deliverAutomaticReward(_, recipient) table.insert(adapter.delivered, "auto:" .. recipient) end
    function adapter.deliverItem(_, recipient) table.insert(adapter.delivered, "item:" .. recipient) end
    function adapter.deliverVictoryBundle(_, members)
        table.insert(adapter.delivered, "bundle:" .. tostring(#members))
        return { treasureRolls = #members * 4, rareItems = 6 }
    end
    function adapter.awardPartyToLevel(_, target)
        table.insert(adapter.experienceTargets, target)
        return 1
    end
    return adapter
end

local function arena(adapter)
    return SoloArena.new(adapter, function() end, Fixtures, Catalog, Layouts, Sites)
end

local function defeatCurrentWave(subject, adapter)
    for _, member in ipairs(subject.active.teams.right.members) do
        adapter.alive[member.guid] = false
    end
    table.remove(adapter.queue, 1)()
end

local function clearBout(subject, adapter)
    local waveCount = subject.active.waveCount
    for waveIndex = 1, waveCount do
        defeatCurrentWave(subject, adapter)
        if waveIndex < waveCount then
            H.truthy(subject.active.transitioning)
            H.equal(adapter.fullRests, 0)
            table.remove(adapter.queue, 1)()
        end
    end
end

H.test("AI bootstrap awards level-three XP while preserving native choices", function()
    local adapter = fakeAdapter()
    adapter.partyLevel = 1
    local subject = arena(adapter)
    subject:bootstrapParty()
    H.equal(adapter.experienceTargets[1], 3)
    H.equal(subject.bootstrapState.phase, "awaiting_level_up")
    adapter.partyLevel = 3
    subject:start({ countdownSeconds = 0 })
    H.equal(subject.bootstrapState.phase, "completed")
end)

H.test("AI bootstrap refuses an already leveled party", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    H.raises(function() subject:bootstrapParty() end, "level 1")
end)

H.test("AI arena scales a level-five fixture to a two-character party", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    local match = subject:start({ countdownSeconds = 0 })
    H.equal(match.phase, "combat")
    H.equal(match.level, 5)
    H.equal(subject.active.waveCount, 2)
    H.equal(subject.active.waveIndex, 1)
    H.equal(#subject.active.teams.right.members, 2)
    H.equal(subject.active.teams.right.members[1].name, "Vanguard Warrior")
    H.equal(subject.active.teams.right.members[2].name, "Vanguard Raider")
    H.truthy(adapter.layouts[1] ~= nil)
    H.equal(adapter.sites[1].id, "astral-flats")
end)

H.test("AI arena returns the party to staging when fixture setup fails", function()
    local adapter = fakeAdapter()
    adapter.spawnFixtureTeam = function() error("fixture failure") end
    local subject = arena(adapter)
    H.raises(function() subject:start({ countdownSeconds = 0 }) end, "rolled back")
    H.equal(subject.active, nil)
    H.equal(adapter.stagingReturns, 1)
    H.equal(subject.run.phase, "seeking_opponent")
end)

H.test("AI victory restores the party, delivers loot, and advances without a prompt", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    clearBout(subject, adapter)
    H.equal(subject.active, nil)
    H.equal(adapter.spawnCalls, 2)
    H.equal(#adapter.deleted, 4)
    H.equal(adapter.interWaveRecoveries, 2)
    H.equal(adapter.stagingReturns, 1)
    H.equal(adapter.fullRests, 1)
    H.equal(adapter.delivered[1], "bundle:2")
    H.equal(adapter.experienceTargets[1], 8)
    H.equal(subject.run.phase, "awaiting_level_up")
    H.equal(subject.menu, nil)
    H.equal(#adapter.menus, 0)
end)

H.test("AI fixture waves rotate roles while preserving party-size scaling", function()
    H.equal(Fixtures.waveCount(3), 2)
    H.equal(Fixtures.waveCount(5), 2)
    H.equal(Fixtures.waveCount(8), 3)
    H.equal(Fixtures.waveCount(10), 3)
    H.equal(Fixtures.waveCount(12), 4)
    local secondWave = Fixtures.forWave(5, 2, 2)
    H.equal(#secondWave.members, 2)
    H.equal(secondWave.members[1].id, "gish")
    H.equal(secondWave.members[2].id, "devastator")
end)

H.test("level-twelve championship uses four waves and celebrates every player", function()
    local adapter = fakeAdapter()
    adapter.partyLevel = 12
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    H.equal(subject.active.waveCount, 4)
    H.equal(subject.active.site.id, "echelon-steps")
    clearBout(subject, adapter)
    H.equal(subject.run.phase, "completed")
    H.equal(subject.run.completion, "champion")
    H.equal(adapter.fullRests, 1)
    H.equal(#adapter.experienceTargets, 0)
    H.equal(#adapter.queue, 3)
    local beforeCelebration = #adapter.notifications
    while #adapter.queue > 0 do
        table.remove(adapter.queue, 1)()
    end
    H.equal(#adapter.notifications - beforeCelebration, 6)
    H.truthy(adapter.notifications[beforeCelebration + 3].message:find("CHAMPIONS", 1, true) ~= nil)
end)

H.test("higher-tier bouts use three waves without resting between them", function()
    local adapter = fakeAdapter()
    adapter.partyLevel = 8
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    H.equal(subject.active.waveCount, 3)
    defeatCurrentWave(subject, adapter)
    H.equal(adapter.fullRests, 0)
    H.equal(subject.active.waveIndex, 1)
    H.truthy(subject.active.transitioning)
    table.remove(adapter.queue, 1)()
    H.equal(subject.active.waveIndex, 2)
    H.equal(#subject.active.teams.right.members, 2)
end)

H.test("a downed teammate recovers for the next wave without a full rest", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    adapter.alive["player-a"] = false
    defeatCurrentWave(subject, adapter)
    H.equal(adapter.fullRests, 0)
    H.equal(adapter.alive["player-a"], true)
    H.equal(adapter.recovered[1], "player-a")
end)

H.test("AI arena retains the full fixture for a four-character party", function()
    local adapter = fakeAdapter()
    adapter.partySize = 4
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    H.equal(#subject.active.teams.right.members, 4)
end)

H.test("defeat fully restores and schedules the same bout automatically", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    adapter.alive["player-a"] = false
    adapter.alive["player-b"] = false
    table.remove(adapter.queue, 1)()
    H.equal(subject.run.phase, "seeking_opponent")
    H.equal(adapter.fullRests, 1)
    H.equal(#adapter.menus, 0)
    table.remove(adapter.queue, 1)()
    H.equal(subject.run.phase, "ready")
    H.equal(subject.run.level, 5)
    H.equal(subject.active.match.level, 5)
end)

H.test("healing a downed combatant removes arena protection", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    adapter.alive["player-a"] = false
    table.remove(adapter.queue, 1)()
    H.truthy(subject.active.defeated["player-a"])
    adapter.alive["player-a"] = true
    table.remove(adapter.queue, 1)()
    H.equal(subject.active.defeated["player-a"], nil)
    H.equal(adapter.recovered[1], "player-a")
end)

H.test("continue refuses until every party member reaches the expected level", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    clearBout(subject, adapter)
    H.raises(function() subject:continue() end, "level 8")
    adapter.partyLevel = 8
    local match = subject:continue()
    H.equal(match.level, 8)
    H.equal(adapter.sites[2].id, "crescent-ruin")
end)

H.test("AI arena abort restores players and deletes temporary enemies", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    subject:abort("test")
    H.equal(subject.active, nil)
    H.equal(#adapter.restored, 2)
    H.equal(#adapter.deleted, 2)
    H.equal(subject.run.phase, "seeking_opponent")
end)

H.test("automatic onboarding bootstraps a fresh party to level three without console commands", function()
    local adapter = fakeAdapter()
    adapter.partyLevel = 1
    local subject = arena(adapter)
    H.equal(subject:autoAdvance(), "bootstrapped")
    H.equal(adapter.experienceTargets[1], 3)
    H.equal(subject.bootstrapState.phase, "awaiting_level_up")
end)

H.test("automatic onboarding never mutates a party outside AA_Arena_Main", function()
    local adapter = fakeAdapter()
    adapter.partyLevel = 1
    adapter.inArena = false
    local subject = arena(adapter)
    H.equal(subject:autoAdvance(), "outside")
    H.equal(#adapter.experienceTargets, 0)
    H.equal(subject.bootstrapState, nil)
end)

H.test("automatic onboarding validates and starts when every player reaches level three", function()
    local adapter = fakeAdapter()
    adapter.partyLevel = 1
    local subject = arena(adapter)
    subject:autoAdvance()
    adapter.partyLevel = 3
    H.equal(subject:autoAdvance(), "started")
    H.equal(subject.bootstrapState.phase, "completed")
    H.equal(subject.active.match.level, 3)
    H.equal(#subject.active.teams.right.members, 2)
end)

H.test("automatic onboarding repairs a split-screen avatar missed by the XP award", function()
    local adapter = fakeAdapter()
    adapter.partyLevels = { 3, 1 }
    local subject = arena(adapter)
    H.equal(subject:autoAdvance(), "repairing")
    H.equal(adapter.experienceTargets[1], 3)
    adapter.partyLevels = { 3, 3 }
    H.equal(subject:autoAdvance(), "started")
    H.equal(subject.active.match.level, 3)
end)

H.test("automatic progression starts the next bout after reward level-up", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    clearBout(subject, adapter)
    adapter.partyLevel = 8
    H.equal(subject:autoAdvance(), "started")
    H.equal(subject.active.match.level, 8)
end)

H.test("save recovery infers the current tier for a mixed level-five party", function()
    local adapter = fakeAdapter()
    adapter.partyLevels = { 5, 1 }
    local subject = arena(adapter)
    H.equal(subject:autoAdvance(), "repairing")
    H.equal(adapter.experienceTargets[1], 5)
    adapter.partyLevels = { 5, 5 }
    H.equal(subject:autoAdvance(), "started")
    H.equal(subject.active.match.level, 5)
end)

H.test("automatic recovery resumes an existing level-eight arena save", function()
    local adapter = fakeAdapter()
    adapter.partyLevel = 8
    local subject = arena(adapter)
    H.equal(subject:autoAdvance(), "started")
    H.equal(subject.active.match.level, 8)
    H.equal(adapter.sites[1].id, "crescent-ruin")
end)

H.test("manual bootstrap also rejects a party outside AA_Arena_Main", function()
    local adapter = fakeAdapter()
    adapter.partyLevel = 1
    adapter.inArena = false
    local subject = arena(adapter)
    H.raises(function() subject:bootstrapParty() end, "AA_Arena_Main")
end)
