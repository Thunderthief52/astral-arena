local Util
if Ext and Ext.Require then
    Util = Ext.Require("AstralArena/Core/Util.lua")
else
    Util = require("AstralArena.Core.Util")
end

local LevelPoolRun = {}

local VALID_RESULTS = { win = true, loss = true, draw = true }

function LevelPoolRun.new(options)
    options = options or {}
    Util.assertNonEmptyString(options.id, "run.id")
    Util.assertNonEmptyString(options.partyId, "run.partyId")

    local startingLevel = options.startingLevel or 1
    local maximumLevel = options.maximumLevel or 12
    local maximumLives = options.maximumLives or 3
    if startingLevel < 1 or maximumLevel < startingLevel then
        error("run levels are invalid", 2)
    end
    if maximumLives < 1 then
        error("maximumLives must be positive", 2)
    end

    return {
        schemaVersion = 1,
        id = options.id,
        partyId = options.partyId,
        phase = "awaiting_build",
        level = startingLevel,
        maximumLevel = maximumLevel,
        lives = maximumLives,
        maximumLives = maximumLives,
        trophies = 0,
        buildSnapshots = {},
        opponent = nil,
        bouts = {},
        completion = nil,
    }
end

function LevelPoolRun.submitBuild(run, snapshotId, level)
    if run.phase ~= "awaiting_build" and run.phase ~= "awaiting_level_up" then
        error("run is not waiting for a build snapshot", 2)
    end
    Util.assertNonEmptyString(snapshotId, "snapshotId")
    if level ~= run.level then
        error(string.format("snapshot level must be %d", run.level), 2)
    end

    run.buildSnapshots[level] = snapshotId
    run.phase = "seeking_opponent"
end

function LevelPoolRun.assignOpponent(run, opponent)
    if run.phase ~= "seeking_opponent" then
        error("run is not seeking an opponent", 2)
    end
    if type(opponent) ~= "table" then
        error("opponent must be a table", 2)
    end
    Util.assertNonEmptyString(opponent.snapshotId, "opponent.snapshotId")
    if opponent.level ~= run.level then
        error(string.format("opponent level must be %d", run.level), 2)
    end
    if opponent.snapshotId == run.buildSnapshots[run.level] then
        error("a party cannot fight its own current snapshot", 2)
    end

    run.opponent = {
        snapshotId = opponent.snapshotId,
        level = opponent.level,
    }
    run.phase = "ready"
end

function LevelPoolRun.beginCombat(run)
    if run.phase ~= "ready" then
        error("run is not ready for combat", 2)
    end
    run.phase = "combat"
end

function LevelPoolRun.recordResult(run, result)
    if run.phase ~= "combat" then
        error("run is not in combat", 2)
    end
    if not VALID_RESULTS[result] then
        error("result must be 'win', 'loss', or 'draw'", 2)
    end

    if result == "win" then
        run.trophies = run.trophies + 1
    elseif result == "loss" then
        run.lives = run.lives - 1
    end

    table.insert(run.bouts, {
        level = run.level,
        result = result,
        buildSnapshotId = run.buildSnapshots[run.level],
        opponentSnapshotId = run.opponent.snapshotId,
    })
    run.opponent = nil

    if run.lives == 0 then
        run.phase = "completed"
        run.completion = "eliminated"
    elseif run.level == run.maximumLevel then
        run.phase = "completed"
        run.completion = "level_cap"
    else
        run.level = run.level + 1
        run.phase = "awaiting_level_up"
    end

    return run.phase, run.completion
end

return LevelPoolRun
