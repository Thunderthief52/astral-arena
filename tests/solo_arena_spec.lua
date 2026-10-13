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
local RunRecord = require("AstralArena.Core.RunRecord")
_G.Ext = previousExt

local function fakeAdapter()
    local adapter = {
        alive = {}, dead = {}, queue = {}, promptQueue = {}, restored = {}, recovered = {}, deleted = {}, delivered = {}, experienceTargets = {}, layouts = {}, sites = {}, notifications = {}, defeatedMarks = {}, stagingReturns = 0, fullRests = 0, waveRests = 0, menus = {}, partySize = 2, spawnCalls = 0, interWaveRecoveries = 0, preparationCalls = 0,
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
    function adapter.restoreWaveResources(members)
        adapter.waveRests = adapter.waveRests + 1
        for _, member in ipairs(members) do
            if not adapter.dead[member.guid] then
                adapter.alive[member.guid] = true
            end
        end
    end
    function adapter.makeHostile() end
    function adapter.enterCombat() end
    function adapter.isAlive(guid) return adapter.alive[guid] end
    function adapter.isDead(guid) return adapter.dead[guid] == true end
    function adapter.markDefeated(guid) table.insert(adapter.defeatedMarks, guid) end
    function adapter.markRecovered(guid) table.insert(adapter.recovered, guid) end
    function adapter.restoreCharacter(member)
        adapter.alive[member.guid] = true
        adapter.dead[member.guid] = nil
        table.insert(adapter.restored, member.guid)
    end
    function adapter.recoverBetweenWaves(member)
        adapter.interWaveRecoveries = adapter.interWaveRecoveries + 1
        return { alive = adapter.alive[member.guid] == true, dead = adapter.dead[member.guid] == true }
    end
    function adapter.deleteTemporary(member) table.insert(adapter.deleted, member.guid) end
    function adapter.schedule(_, callback) table.insert(adapter.queue, callback) end
    function adapter.schedulePromptRetry(_, callback) table.insert(adapter.promptQueue, callback) end
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
    function adapter.deliverPreparationBundle(members, level, catalog)
        adapter.preparationCalls = adapter.preparationCalls + 1
        adapter.preparationLevel = level
        adapter.preparationCatalogSize = #catalog
        return { treasureRolls = #members * 6, armoryItems = 12, revivifyScrolls = #members * 2 }
    end
    function adapter.awardPartyToLevel(_, target)
        table.insert(adapter.experienceTargets, target)
        return 1
    end
    return adapter
end

local function sharedStore()
    -- Mimics the ModVar: every load returns a fresh copy, so a test fails if the
    -- runtime forgets to save a mutation.
    local saved = RunRecord.new()
    local function copy(value)
        if type(value) ~= "table" then
            return value
        end
        local result = {}
        for key, child in pairs(value) do
            result[key] = copy(child)
        end
        return result
    end
    return {
        load = function()
            return RunRecord.normalize(copy(saved))
        end,
        save = function(record)
            saved = copy(record)
        end,
        peek = function()
            return saved
        end,
    }
end

local function arena(adapter, campService, store)
    return SoloArena.new(adapter, function() end, Fixtures, Catalog, Layouts, Sites, campService, store)
end

local function defeatCurrentWave(subject, adapter)
    for _, member in ipairs(subject.active.teams.right.members) do
        adapter.alive[member.guid] = false
    end
    table.remove(adapter.queue, 1)()
end

local function acceptReadyWave(subject)
    H.equal(subject.menu.kind, "wave_start")
    subject:handleMenuResponse(subject.menu.ownerGuid, subject.menu.messageKey, true)
end

local function clearBout(subject, adapter)
    local waveCount = subject.active.waveCount
    for waveIndex = 1, waveCount do
        defeatCurrentWave(subject, adapter)
        if waveIndex < waveCount then
            H.truthy(subject.active.transitioning)
            H.equal(adapter.fullRests, 0)
            H.equal(subject.menu.kind, "wave_start")
            subject:handleMenuResponse("player-a", subject.menu.messageKey, true)
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
    H.equal(adapter.preparationCalls, 1)
    H.equal(adapter.preparationLevel, 5)
    H.equal(adapter.preparationCatalogSize, #Catalog)
end)

H.test("AI bootstrap starts after approved Withers followers expand a split-screen party", function()
    local adapter = fakeAdapter()
    adapter.partyLevel = 1
    adapter.partySize = 2
    local campService = {
        recruitedCharacters = function()
            return { ["player-c"] = true, ["player-d"] = true }
        end,
    }
    local subject = arena(adapter, campService)
    subject:bootstrapParty()
    adapter.partyLevel = 3
    adapter.partySize = 4
    local match = subject:start({ countdownSeconds = 0 })
    H.equal(subject.bootstrapState.phase, "completed")
    H.equal(match.phase, "combat")
    H.equal(#subject.active.teams.left.members, 4)
end)

H.test("arena preparation supplies are delivered once and retries cannot duplicate them", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    H.equal(adapter.preparationCalls, 1)
    adapter.alive["player-a"] = false
    adapter.alive["player-b"] = false
    table.remove(adapter.queue, 1)()
    table.remove(adapter.queue, 1)()
    H.equal(adapter.preparationCalls, 1)
end)

H.test("AI arena returns the party to staging when fixture setup fails", function()
    local adapter = fakeAdapter()
    adapter.spawnFixtureTeam = function() error("fixture failure") end
    local subject = arena(adapter)
    subject:start()
    acceptReadyWave(subject)
    H.equal(subject.active, nil)
    H.equal(adapter.stagingReturns, 1)
    H.equal(subject.run.phase, "seeking_opponent")
end)

H.test("AI victory restores the party, delivers loot, and advances without a reward prompt", function()
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
    H.equal(#adapter.menus, 1)
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
    H.equal(#Fixtures.forWave(3, 4, 1).members, 2)
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

H.test("higher-tier bouts fully refresh resources and wait for player confirmation between waves", function()
    local adapter = fakeAdapter()
    adapter.partyLevel = 8
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    H.equal(subject.active.waveCount, 3)
    defeatCurrentWave(subject, adapter)
    H.equal(adapter.fullRests, 0)
    H.equal(adapter.waveRests, 1)
    H.equal(subject.active.waveIndex, 1)
    H.truthy(subject.active.transitioning)
    H.equal(subject.menu.kind, "wave_start")
    subject:handleMenuResponse("player-a", subject.menu.messageKey, true)
    H.equal(subject.active.waveIndex, 2)
    H.equal(#subject.active.teams.right.members, 2)
end)

H.test("a downed teammate recovers during the between-wave resource refresh", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    adapter.alive["player-a"] = false
    defeatCurrentWave(subject, adapter)
    H.equal(adapter.fullRests, 0)
    H.equal(adapter.waveRests, 1)
    H.truthy(adapter.alive["player-a"])
    H.equal(#adapter.recovered, 0)
end)

H.test("a dead teammate stays dead during intermission but can be resurrected before the next wave", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    adapter.alive["player-a"] = false
    adapter.dead["player-a"] = true
    defeatCurrentWave(subject, adapter)
    H.equal(adapter.alive["player-a"], false)
    H.truthy(adapter.dead["player-a"])
    adapter.alive["player-a"] = true
    adapter.dead["player-a"] = nil
    subject:handleMenuResponse("player-a", subject.menu.messageKey, true)
    H.equal(subject.active.waveIndex, 2)
    H.truthy(adapter.alive["player-a"])
end)

H.test("declining a wave prompt never forces combat and offers it again after one minute", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start()
    H.equal(subject.active.match, nil)
    H.equal(adapter.spawnCalls, 0)
    H.equal(subject.menu.kind, "wave_start")
    subject:handleMenuResponse("player-a", subject.menu.messageKey, false)
    H.equal(subject.active.match, nil)
    H.equal(adapter.spawnCalls, 0)
    H.equal(#adapter.promptQueue, 1)
    table.remove(adapter.promptQueue, 1)()
    H.equal(#adapter.menus, 2)
    H.equal(subject.active.match, nil)
    H.equal(adapter.spawnCalls, 0)
end)

H.test("the first enemy is not created until the party confirms the ready prompt", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start()
    H.equal(adapter.spawnCalls, 0)
    H.equal(#subject.active.teams.right.members, 0)
    acceptReadyWave(subject)
    H.equal(adapter.spawnCalls, 1)
    H.equal(subject.active.match.phase, "combat")
    H.equal(subject.active.waveIndex, 1)
end)

H.test("AI arena retains the full fixture for a four-character party", function()
    local adapter = fakeAdapter()
    adapter.partySize = 4
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    H.equal(#subject.active.teams.right.members, 4)
end)

H.test("a single defeat restores the party and ends the run for good", function()
    local adapter = fakeAdapter()
    local store = sharedStore()
    local subject = arena(adapter, nil, store)
    subject:start({ countdownSeconds = 0 })
    adapter.alive["player-a"] = false
    adapter.alive["player-b"] = false
    table.remove(adapter.queue, 1)()
    H.equal(subject.active, nil)
    H.equal(subject.run.phase, "completed")
    H.equal(subject.run.completion, "defeated")
    H.equal(adapter.fullRests, 1)
    H.equal(adapter.stagingReturns, 1)
    H.equal(store.peek().outcome, "eliminated")
    H.equal(store.peek().ending.level, 5)
    H.equal(store.peek().ending.wave, 1)
    -- Only the three staged announcements remain; no rematch is scheduled.
    H.equal(#adapter.queue, 3)
    while #adapter.queue > 0 do
        table.remove(adapter.queue, 1)()
    end
    H.equal(subject.active, nil)
    H.equal(subject:autoAdvance(), "completed")
    H.equal(subject.active, nil)
    H.raises(function() subject:start() end, "ELIMINATED")
end)

H.test("battle defeat automatically resurrects dead players at the mission boundary", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    adapter.alive["player-a"] = false
    adapter.alive["player-b"] = false
    adapter.dead["player-a"] = true
    adapter.dead["player-b"] = true
    table.remove(adapter.queue, 1)()
    H.truthy(adapter.alive["player-a"])
    H.truthy(adapter.alive["player-b"])
    H.equal(adapter.dead["player-a"], nil)
    H.equal(adapter.dead["player-b"], nil)
    H.equal(adapter.fullRests, 1)
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

H.test("the native downed event records death-save state without target protection", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    adapter.alive["player-a"] = false
    H.truthy(subject:onStatusApplied("player-a", "DOWNED"))
    H.truthy(subject.active.defeated["player-a"])
    H.equal(adapter.defeatedMarks[1], "player-a")
    H.equal(subject:onStatusApplied("outside-combatant", "DOWNED"), false)
end)

H.test("continue refuses until every party member reaches the expected level", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    clearBout(subject, adapter)
    H.raises(function() subject:continue() end, "level 8")
    adapter.partyLevel = 8
    subject:continue()
    H.equal(subject.active.match, nil)
    acceptReadyWave(subject)
    H.equal(subject.active.match.level, 8)
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
    H.equal(subject.active.match, nil)
    acceptReadyWave(subject)
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
    acceptReadyWave(subject)
    H.equal(subject.active.match.level, 3)
end)

H.test("automatic progression starts the next bout after reward level-up", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    clearBout(subject, adapter)
    adapter.partyLevel = 8
    H.equal(subject:autoAdvance(), "started")
    acceptReadyWave(subject)
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
    acceptReadyWave(subject)
    H.equal(subject.active.match.level, 5)
end)

H.test("automatic recovery resumes an existing level-eight arena save", function()
    local adapter = fakeAdapter()
    adapter.partyLevel = 8
    local subject = arena(adapter)
    H.equal(subject:autoAdvance(), "started")
    acceptReadyWave(subject)
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

H.test("a mutual knockout is a draw that also eliminates the party", function()
    local adapter = fakeAdapter()
    local store = sharedStore()
    local subject = arena(adapter, nil, store)
    subject:start({ countdownSeconds = 0 })
    for guid in pairs(adapter.alive) do
        adapter.alive[guid] = false
    end
    table.remove(adapter.queue, 1)()
    H.equal(store.peek().outcome, "eliminated")
    H.equal(store.peek().ending.resolution, "draw")
    H.truthy(RunRecord.summary(store.peek()):find("fell together", 1, true) ~= nil)
end)

H.test("an elimination survives a reload and blocks every automatic restart", function()
    local adapter = fakeAdapter()
    local store = sharedStore()
    local first = arena(adapter, nil, store)
    first:start({ countdownSeconds = 0 })
    adapter.alive["player-a"] = false
    adapter.alive["player-b"] = false
    table.remove(adapter.queue, 1)()

    local reloadedAdapter = fakeAdapter()
    reloadedAdapter.partyLevel = 5
    local reloaded = arena(reloadedAdapter, nil, store)
    H.equal(reloaded:autoAdvance(), "completed")
    H.equal(reloaded:autoAdvance(), "completed")
    H.equal(reloaded.active, nil)
    H.equal(reloadedAdapter.preparationCalls, 0)
    H.equal(reloadedAdapter.spawnCalls, 0)
    H.truthy(reloadedAdapter.notifications[1].message:find("ELIMINATED", 1, true) ~= nil)
    -- The reminder is shown once per session rather than every watcher tick.
    H.equal(#reloadedAdapter.notifications, 2)
    H.raises(function() reloaded:bootstrapParty() end, "New Game")
end)

H.test("the defeat notice fires before BG3 can react when the final player goes down", function()
    local adapter = fakeAdapter()
    local store = sharedStore()
    local subject = arena(adapter, nil, store)
    subject:start({ countdownSeconds = 0 })
    adapter.alive["player-a"] = false
    subject:onStatusApplied("player-a", "DOWNED")
    H.truthy(subject.active ~= nil)
    adapter.alive["player-b"] = false
    subject:onStatusApplied("player-b", "DOWNED")
    H.equal(subject.active, nil)
    H.equal(store.peek().outcome, "eliminated")
    H.equal(adapter.fullRests, 1)
end)

H.test("a death event resolves a cleared wave immediately", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    local enemies = subject.active.teams.right.members
    for _, member in ipairs(enemies) do
        adapter.alive[member.guid] = false
    end
    H.truthy(subject:onDied(enemies[1].guid))
    H.truthy(subject.active.transitioning)
    H.equal(subject.menu.kind, "wave_start")
    -- The already-scheduled poll must not reopen or re-resolve the wave.
    table.remove(adapter.queue, 1)()
    H.equal(#adapter.queue, 0)
    H.equal(adapter.waveRests, 1)
    H.equal(subject:onDied("unrelated-npc"), false)
end)

H.test("accepting the next wave quickly never leaves two polling chains", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start({ countdownSeconds = 0 })
    local enemies = subject.active.teams.right.members
    for _, member in ipairs(enemies) do
        adapter.alive[member.guid] = false
    end
    subject:onDied(enemies[1].guid)
    acceptReadyWave(subject)
    H.equal(subject.active.waveIndex, 2)
    H.equal(#adapter.queue, 2)
    table.remove(adapter.queue, 1)()
    H.equal(#adapter.queue, 1)
    table.remove(adapter.queue, 1)()
    H.equal(#adapter.queue, 1)
end)

H.test("the one-time armory is never delivered again after a reload", function()
    local adapter = fakeAdapter()
    local store = sharedStore()
    local subject = arena(adapter, nil, store)
    subject:start({ countdownSeconds = 0 })
    clearBout(subject, adapter)
    H.equal(adapter.preparationCalls, 1)
    H.equal(#store.peek().victories, 1)

    local reloadedAdapter = fakeAdapter()
    reloadedAdapter.partyLevel = 8
    local reloaded = arena(reloadedAdapter, nil, store)
    H.equal(reloaded:autoAdvance(), "started")
    H.equal(reloadedAdapter.preparationCalls, 0)
    acceptReadyWave(reloaded)
    H.equal(reloaded.active.match.level, 8)
end)

H.test("the staging origin is persisted and reused after a reload", function()
    local adapter = fakeAdapter()
    local origin = nil
    function adapter.stagingOrigin() return { 1, 2, 3 } end
    function adapter.setStagingOrigin(value) origin = value end
    local store = sharedStore()
    arena(adapter, nil, store):start()
    H.equal(store.peek().stagingOrigin[3], 3)

    local reloadedAdapter = fakeAdapter()
    function reloadedAdapter.setStagingOrigin(value) origin = value end
    function reloadedAdapter.stagingOrigin() return { 9, 9, 9 } end
    arena(reloadedAdapter, nil, store):start()
    H.equal(origin[1], 1)
    H.equal(store.peek().stagingOrigin[1], 1)
end)

H.test("loading a save made mid-wave deletes stale enemies and restarts the battle", function()
    local adapter = fakeAdapter()
    local store = sharedStore()
    local subject = arena(adapter, nil, store)
    subject:start({ countdownSeconds = 0 })
    local enemyGuid = subject.active.teams.right.members[1].guid
    H.equal(store.peek().combat.wave, 1)
    H.equal(store.peek().combat.enemyGuids[1], enemyGuid)

    -- Simulate loading that save: a fresh session with a dead, in-combat player.
    local reloadedAdapter = fakeAdapter()
    reloadedAdapter.dead["player-b"] = true
    local reloaded = arena(reloadedAdapter, nil, store)
    H.equal(reloaded:autoAdvance(), "recovered")
    H.equal(reloadedAdapter.deleted[1], enemyGuid)
    H.equal(#reloadedAdapter.restored, 2)
    H.equal(reloadedAdapter.dead["player-b"], nil)
    H.equal(reloadedAdapter.stagingReturns, 1)
    H.equal(store.peek().combat, nil)
    H.equal(store.peek().outcome, nil)
    H.equal(reloaded:autoAdvance(), "started")
    H.equal(reloadedAdapter.preparationCalls, 0)
    H.equal(reloaded.menu.kind, "wave_start")
end)

H.test("a save made during an intermission still restores a dead ally on reload", function()
    local adapter = fakeAdapter()
    local store = sharedStore()
    local subject = arena(adapter, nil, store)
    subject:start({ countdownSeconds = 0 })
    adapter.dead["player-a"] = true
    adapter.alive["player-a"] = false
    defeatCurrentWave(subject, adapter)
    H.truthy(subject.active.transitioning)
    H.truthy(store.peek().combat ~= nil)
    H.equal(#store.peek().combat.enemyGuids, 0)
    local reloadedAdapter = fakeAdapter()
    reloadedAdapter.dead["player-a"] = true
    H.equal(arena(reloadedAdapter, nil, store):autoAdvance(), "recovered")
    H.equal(reloadedAdapter.dead["player-a"], nil)
end)

H.test("an abort is not a defeat and the ready prompt returns automatically", function()
    local adapter = fakeAdapter()
    local store = sharedStore()
    local subject = arena(adapter, nil, store)
    subject:start({ countdownSeconds = 0 })
    subject:abort("manual-abort")
    H.equal(store.peek().outcome, nil)
    H.equal(store.peek().combat, nil)
    H.equal(subject.menu, nil)
    local action
    for _ = 1, 9 do
        action = subject:autoAdvance()
        H.equal(action, "waiting")
    end
    H.equal(subject:autoAdvance(), "started")
    H.equal(subject.menu.kind, "wave_start")
    H.equal(adapter.spawnCalls, 1)
    H.equal(adapter.preparationCalls, 1)
end)

H.test("winning the level-twelve championship is recorded and survives a reload", function()
    local adapter = fakeAdapter()
    adapter.partyLevel = 12
    local store = sharedStore()
    local subject = arena(adapter, nil, store)
    subject:start({ countdownSeconds = 0 })
    clearBout(subject, adapter)
    H.equal(store.peek().outcome, "champion")
    local reloaded = arena(fakeAdapter(), nil, store)
    H.equal(reloaded:autoAdvance(), "completed")
    H.truthy(reloaded:status():find("CHAMPIONS", 1, true) ~= nil)
end)

H.test("a full 3 -> 5 -> 8 -> 10 -> 12 gauntlet crowns a surviving party", function()
    local adapter = fakeAdapter()
    adapter.partyLevel = 1
    local store = sharedStore()
    local subject = arena(adapter, nil, store)
    H.equal(subject:autoAdvance(), "bootstrapped")
    local expected = { 3, 5, 8, 10, 12 }
    for index, level in ipairs(expected) do
        adapter.partyLevel = level
        H.equal(subject:autoAdvance(), "started")
        acceptReadyWave(subject)
        H.equal(subject.active.match.level, level)
        adapter.fullRests = 0
        clearBout(subject, adapter)
        H.equal(#store.peek().victories, index)
        while #adapter.queue > 0 do
            table.remove(adapter.queue, 1)()
        end
    end
    H.equal(store.peek().outcome, "champion")
    H.equal(adapter.preparationCalls, 1)
    H.equal(subject:autoAdvance(), "completed")
    local targets = table.concat(adapter.experienceTargets, ",")
    H.equal(targets, "3,5,8,10,12")
end)

H.test("the developer override reopens a false elimination", function()
    local adapter = fakeAdapter()
    local store = sharedStore()
    local subject = arena(adapter, nil, store)
    subject:start({ countdownSeconds = 0 })
    adapter.alive["player-a"] = false
    adapter.alive["player-b"] = false
    table.remove(adapter.queue, 1)()
    H.equal(store.peek().outcome, "eliminated")
    subject:overrideElimination()
    H.equal(store.peek().outcome, nil)
    H.equal(store.peek().overrides, 1)
    H.equal(subject:autoAdvance(), "started")
    H.equal(subject.menu.kind, "wave_start")
end)

H.test("any party member may answer the ready prompt, as BG3 reports the selected character", function()
    local adapter = fakeAdapter()
    adapter.partySize = 2
    local subject = arena(adapter)
    subject:start()
    H.equal(subject.menu.ownerGuid, "player-a")
    -- A stranger cannot answer.
    H.equal(subject:handleMenuResponse("someone-else", subject.menu.messageKey, true), false)
    H.equal(adapter.spawnCalls, 0)
    -- The second split-screen player (or a selected hireling) can.
    H.truthy(subject:handleMenuResponse("player-b", subject.menu.messageKey, true))
    H.equal(adapter.spawnCalls, 1)
    H.equal(subject.active.match.phase, "combat")
end)

H.test("the console ready command answers an open wave prompt", function()
    local adapter = fakeAdapter()
    local subject = arena(adapter)
    subject:start()
    subject:confirmReadyPrompt()
    H.equal(adapter.spawnCalls, 1)
    H.raises(function() subject:confirmReadyPrompt() end, "no wave ready prompt")
end)
