local Util
if Ext and Ext.Require then
    Util = Ext.Require("AstralArena/Core/Util.lua")
else
    Util = require("AstralArena.Core.Util")
end

local Match = {}

local VALID_SIDES = { left = true, right = true }

local function assertSide(side)
    if not VALID_SIDES[side] then
        error("side must be 'left' or 'right'", 3)
    end
end

local function otherSide(side)
    return side == "left" and "right" or "left"
end

local function ensureUniqueCharacters(session, side, characters)
    local seen = {}
    for _, guid in ipairs(characters) do
        Util.assertNonEmptyString(guid, "character GUID")
        if seen[guid] then
            error("duplicate character in roster: " .. guid, 3)
        end
        seen[guid] = true
    end

    local opponent = session.teams[otherSide(side)]
    for _, guid in ipairs(opponent.characters) do
        if seen[guid] then
            error("character appears on both teams: " .. guid, 3)
        end
    end
end

function Match.new(options)
    options = options or {}
    Util.assertNonEmptyString(options.id, "match.id")
    Util.assertNonEmptyString(options.leftEntrantId, "match.leftEntrantId")
    Util.assertNonEmptyString(options.rightEntrantId, "match.rightEntrantId")

    return {
        schemaVersion = 1,
        id = options.id,
        level = options.level or 5,
        maxPartySize = options.maxPartySize or 4,
        phase = "assembling",
        teams = {
            left = { entrantId = options.leftEntrantId, characters = {}, ready = false },
            right = { entrantId = options.rightEntrantId, characters = {}, ready = false },
        },
        defeatedCharacters = {},
        winnerEntrantId = nil,
        loserEntrantId = nil,
        resolution = nil,
    }
end

function Match.setRoster(session, side, characterGuids)
    assertSide(side)
    if session.phase ~= "assembling" then
        error("rosters can only change while assembling", 2)
    end
    if type(characterGuids) ~= "table" then
        error("characterGuids must be a table", 2)
    end
    if #characterGuids < 1 or #characterGuids > session.maxPartySize then
        error(string.format("roster size must be between 1 and %d", session.maxPartySize), 2)
    end

    ensureUniqueCharacters(session, side, characterGuids)
    session.teams[side].characters = Util.copy(characterGuids)
    session.teams[side].ready = false
end

function Match.setReady(session, side, ready)
    assertSide(side)
    if session.phase ~= "assembling" then
        error("readiness can only change while assembling", 2)
    end
    if #session.teams[side].characters == 0 then
        error("cannot ready an empty roster", 2)
    end
    session.teams[side].ready = ready ~= false
    return session.teams.left.ready and session.teams.right.ready
end

function Match.beginPreparation(session)
    if session.phase ~= "assembling" then
        error("match is not assembling", 2)
    end
    if not session.teams.left.ready or not session.teams.right.ready then
        error("both teams must be ready", 2)
    end
    session.phase = "preparation"
end

function Match.beginCombat(session)
    if session.phase ~= "preparation" then
        error("match is not in preparation", 2)
    end
    session.phase = "combat"
end

local function complete(session, winnerSide, resolution)
    local loserSide = otherSide(winnerSide)
    session.phase = "completed"
    session.winnerEntrantId = session.teams[winnerSide].entrantId
    session.loserEntrantId = session.teams[loserSide].entrantId
    session.resolution = resolution
    return session.winnerEntrantId
end

function Match.evaluateAlive(session, aliveByGuid)
    if session.phase ~= "combat" then
        error("match is not in combat", 2)
    end

    local aliveCount = { left = 0, right = 0 }
    for side, team in pairs(session.teams) do
        for _, guid in ipairs(team.characters) do
            if aliveByGuid[guid] then
                aliveCount[side] = aliveCount[side] + 1
            else
                session.defeatedCharacters[guid] = true
            end
        end
    end

    if aliveCount.left == 0 and aliveCount.right == 0 then
        session.phase = "completed"
        session.resolution = "draw"
        return nil, "draw"
    elseif aliveCount.left == 0 then
        return complete(session, "right", "defeat"), "right"
    elseif aliveCount.right == 0 then
        return complete(session, "left", "defeat"), "left"
    end
    return nil, nil
end

function Match.forfeit(session, side)
    assertSide(side)
    if session.phase == "completed" or session.phase == "aborted" then
        error("match has already ended", 2)
    end
    return complete(session, otherSide(side), "forfeit")
end

function Match.abort(session, reason)
    if session.phase == "completed" then
        error("completed match cannot be aborted", 2)
    end
    session.phase = "aborted"
    session.resolution = reason or "aborted"
end

return Match
