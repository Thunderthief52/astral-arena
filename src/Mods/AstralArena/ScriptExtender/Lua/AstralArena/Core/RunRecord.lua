local Util
if Ext and Ext.Require then
    Util = Ext.Require("AstralArena/Core/Util.lua")
else
    Util = require("AstralArena.Core.Util")
end

-- Save-persistent record of one Adventure's gauntlet run.
--
-- The live SoloRun/SoloArena objects are session-only. This record is the part
-- that must survive a save and reload: whether the run has already ended
-- (one loss eliminates the party), whether the one-time armory was handed out,
-- where staging is, and which temporary enemies exist if the game was saved in
-- the middle of a fight. It holds only plain values so Script Extender can
-- serialize it into the savegame.
local RunRecord = {}

RunRecord.SCHEMA_VERSION = 1
RunRecord.RULESET = "one-loss-elimination"

function RunRecord.new()
    return {
        schemaVersion = RunRecord.SCHEMA_VERSION,
        ruleset = RunRecord.RULESET,
        outcome = nil,
        ending = nil,
        victories = {},
        preparationDelivered = false,
        stagingOrigin = nil,
        combat = nil,
        endingAnnounced = false,
    }
end

function RunRecord.normalize(record)
    if type(record) ~= "table" or record.schemaVersion ~= RunRecord.SCHEMA_VERSION then
        return RunRecord.new()
    end
    record.victories = type(record.victories) == "table" and record.victories or {}
    record.preparationDelivered = record.preparationDelivered == true
    return record
end

function RunRecord.isOver(record)
    return record.outcome == "eliminated" or record.outcome == "champion"
end

local function requireOpen(record)
    if RunRecord.isOver(record) then
        error("the Astral Arena run has already ended (" .. tostring(record.outcome) .. ")", 3)
    end
end

function RunRecord.markPreparationDelivered(record)
    record.preparationDelivered = true
end

function RunRecord.setStagingOrigin(record, origin)
    if type(origin) ~= "table" then
        return
    end
    for index = 1, 3 do
        if type(origin[index]) ~= "number" then
            error("staging origin needs three numeric coordinates", 2)
        end
    end
    record.stagingOrigin = { origin[1], origin[2], origin[3] }
end

function RunRecord.beginCombat(record, details)
    requireOpen(record)
    details = details or {}
    local enemies = {}
    for _, guid in ipairs(details.enemyGuids or {}) do
        Util.assertNonEmptyString(guid, "enemy guid")
        table.insert(enemies, guid)
    end
    local factions = {}
    for _, faction in ipairs(details.enemyFactions or {}) do
        table.insert(factions, faction)
    end
    record.combat = {
        level = details.level,
        battleIndex = details.battleIndex,
        wave = details.wave,
        enemyGuids = enemies,
        enemyFactions = factions,
    }
end

function RunRecord.clearCombat(record)
    record.combat = nil
end

function RunRecord.recordVictory(record, details)
    requireOpen(record)
    details = details or {}
    table.insert(record.victories, {
        level = details.level,
        battleIndex = details.battleIndex,
        opponent = details.opponent,
        waves = details.waves,
    })
    record.combat = nil
end

function RunRecord.eliminate(record, details)
    requireOpen(record)
    details = details or {}
    record.outcome = "eliminated"
    record.ending = {
        level = details.level,
        battleIndex = details.battleIndex,
        battleCount = details.battleCount,
        wave = details.wave,
        waveCount = details.waveCount,
        opponent = details.opponent,
        resolution = details.resolution or "defeat",
    }
    record.combat = nil
    record.endingAnnounced = false
end

function RunRecord.crown(record, details)
    requireOpen(record)
    details = details or {}
    record.outcome = "champion"
    record.ending = {
        level = details.level,
        battleIndex = details.battleIndex,
        battleCount = details.battleCount,
        opponent = details.opponent,
        resolution = "champion",
    }
    record.combat = nil
    record.endingAnnounced = false
end

-- Only a developer override may reopen an ended run. It keeps the history so a
-- report still shows that the run was eliminated once.
function RunRecord.reopen(record)
    if record.outcome ~= "eliminated" then
        error("only an eliminated run can be reopened", 2)
    end
    record.overrides = (record.overrides or 0) + 1
    record.outcome = nil
    record.ending = nil
    record.endingAnnounced = false
end

function RunRecord.summary(record)
    local wins = #record.victories
    if record.outcome == "champion" then
        return string.format("CHAMPIONS: the party won all %d battles and conquered the level-12 championship.", wins)
    end
    if record.outcome == "eliminated" then
        local ending = record.ending or {}
        local how = ending.resolution == "draw" and "fell together with" or "was defeated by"
        return string.format(
            "ELIMINATED: the party %s %s in the level-%s battle (%s/%s, wave %s/%s) after %d victor%s.",
            how,
            tostring(ending.opponent or "the arena"),
            tostring(ending.level or "?"),
            tostring(ending.battleIndex or "?"),
            tostring(ending.battleCount or "?"),
            tostring(ending.wave or "?"),
            tostring(ending.waveCount or "?"),
            wins,
            wins == 1 and "y" or "ies"
        )
    end
    return string.format("Run in progress: %d victor%s so far.", wins, wins == 1 and "y" or "ies")
end

return RunRecord
