local H = require("tests.test_helper")
local LevelPoolRun = require("AstralArena.Core.LevelPoolRun")

local function newRun(options)
    options = options or {}
    options.id = options.id or "run-1"
    options.partyId = options.partyId or "party-1"
    return LevelPoolRun.new(options)
end

local function startBout(run, level, suffix)
    suffix = suffix or tostring(level)
    LevelPoolRun.submitBuild(run, "build-" .. suffix, level)
    LevelPoolRun.assignOpponent(run, {
        snapshotId = "opponent-" .. suffix,
        level = level,
    })
    LevelPoolRun.beginCombat(run)
end

H.test("a level-pool run begins by capturing the player's level-one build", function()
    local run = newRun()
    H.equal(run.level, 1)
    H.equal(run.lives, 3)
    H.equal(run.phase, "awaiting_build")

    LevelPoolRun.submitBuild(run, "build-1", 1)
    H.equal(run.phase, "seeking_opponent")
end)

H.test("a bout only accepts an opponent from the same level", function()
    local run = newRun()
    LevelPoolRun.submitBuild(run, "build-1", 1)
    H.raises(function()
        LevelPoolRun.assignOpponent(run, { snapshotId = "opponent-2", level = 2 })
    end, "opponent level")
end)

H.test("a win adds a trophy and advances to native level-up", function()
    local run = newRun()
    startBout(run, 1)
    LevelPoolRun.recordResult(run, "win")

    H.equal(run.trophies, 1)
    H.equal(run.lives, 3)
    H.equal(run.level, 2)
    H.equal(run.phase, "awaiting_level_up")
end)

H.test("a loss costs a life but still advances a level", function()
    local run = newRun()
    startBout(run, 1)
    LevelPoolRun.recordResult(run, "loss")

    H.equal(run.trophies, 0)
    H.equal(run.lives, 2)
    H.equal(run.level, 2)
    H.equal(run.phase, "awaiting_level_up")
end)

H.test("three losses eliminate a standard run", function()
    local run = newRun()
    for level = 1, 3 do
        startBout(run, level)
        LevelPoolRun.recordResult(run, "loss")
    end

    H.equal(run.level, 3)
    H.equal(run.lives, 0)
    H.equal(run.phase, "completed")
    H.equal(run.completion, "eliminated")
    H.equal(#run.bouts, 3)
end)

H.test("the level-twelve bout completes a surviving run", function()
    local run = newRun({ startingLevel = 12 })
    startBout(run, 12)
    LevelPoolRun.recordResult(run, "win")

    H.equal(run.trophies, 1)
    H.equal(run.phase, "completed")
    H.equal(run.completion, "level_cap")
end)
