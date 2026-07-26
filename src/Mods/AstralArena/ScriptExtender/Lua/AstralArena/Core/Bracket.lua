local Util
if Ext and Ext.Require then
    Util = Ext.Require("AstralArena/Core/Util.lua")
else
    Util = require("AstralArena.Core.Util")
end

local Bracket = {}

local DEFAULT_LEVELS = {
    quarterfinal = 5,
    semifinal = 8,
    final = 10,
    champion = 12,
}

local MATCH_DEFINITIONS = {
    { id = "QF1", round = "quarterfinal", roundIndex = 1, nextMatchId = "SF1", nextSlot = "left" },
    { id = "QF2", round = "quarterfinal", roundIndex = 1, nextMatchId = "SF1", nextSlot = "right" },
    { id = "QF3", round = "quarterfinal", roundIndex = 1, nextMatchId = "SF2", nextSlot = "left" },
    { id = "QF4", round = "quarterfinal", roundIndex = 1, nextMatchId = "SF2", nextSlot = "right" },
    { id = "SF1", round = "semifinal", roundIndex = 2, nextMatchId = "F1", nextSlot = "left" },
    { id = "SF2", round = "semifinal", roundIndex = 2, nextMatchId = "F1", nextSlot = "right" },
    { id = "F1", round = "final", roundIndex = 3 },
}

local SEED_PAIRINGS = {
    QF1 = { 1, 8 },
    QF2 = { 4, 5 },
    QF3 = { 2, 7 },
    QF4 = { 3, 6 },
}

local function buildMatches(levels)
    local matches = {}
    for _, definition in ipairs(MATCH_DEFINITIONS) do
        matches[definition.id] = {
            id = definition.id,
            round = definition.round,
            roundIndex = definition.roundIndex,
            level = levels[definition.round],
            rewardLevel = definition.round == "final" and levels.champion
                or levels[definition.round == "quarterfinal" and "semifinal" or "final"],
            leftEntrantId = nil,
            rightEntrantId = nil,
            nextMatchId = definition.nextMatchId,
            nextSlot = definition.nextSlot,
            status = "locked",
            winnerEntrantId = nil,
            loserEntrantId = nil,
            resolution = nil,
        }
    end
    return matches
end

local function refreshMatchStatus(match)
    if match.status == "completed" then
        return
    end
    if match.leftEntrantId and match.rightEntrantId then
        match.status = "ready"
    elseif match.leftEntrantId or match.rightEntrantId then
        match.status = "waiting"
    else
        match.status = "locked"
    end
end

local function assertMutable(state)
    if state.status == "completed" then
        error("tournament is already completed", 3)
    end
end

function Bracket.new(options)
    options = options or {}
    local levels = Util.copy(options.levels or DEFAULT_LEVELS)
    return {
        schemaVersion = options.schemaVersion or 1,
        id = options.id or "astral-arena-tournament",
        status = "registration",
        entrantLimit = 8,
        entrants = {},
        entrantOrder = {},
        matches = buildMatches(levels),
        levels = levels,
        championEntrantId = nil,
        history = {},
    }
end

function Bracket.register(state, entrant)
    assertMutable(state)
    if state.status ~= "registration" then
        error("registration is closed", 2)
    end
    if type(entrant) ~= "table" then
        error("entrant must be a table", 2)
    end

    Util.assertNonEmptyString(entrant.id, "entrant.id")
    Util.assertNonEmptyString(entrant.displayName, "entrant.displayName")

    if state.entrants[entrant.id] then
        error("entrant already registered: " .. entrant.id, 2)
    end
    if #state.entrantOrder >= state.entrantLimit then
        error("tournament is full", 2)
    end

    local stored = Util.copy(entrant)
    stored.seed = nil
    stored.currentLevel = state.levels.quarterfinal
    stored.eliminated = false
    state.entrants[stored.id] = stored
    table.insert(state.entrantOrder, stored.id)
    return stored
end

function Bracket.seed(state, orderedEntrantIds)
    assertMutable(state)
    if state.status ~= "registration" then
        error("bracket has already been seeded", 2)
    end
    if #state.entrantOrder ~= state.entrantLimit then
        error("exactly eight entrants are required before seeding", 2)
    end

    local order = orderedEntrantIds and Util.copy(orderedEntrantIds) or Util.copy(state.entrantOrder)
    if #order ~= state.entrantLimit then
        error("seed order must contain exactly eight entrants", 2)
    end

    local seen = {}
    for seed, entrantId in ipairs(order) do
        if not state.entrants[entrantId] then
            error("unknown entrant in seed order: " .. tostring(entrantId), 2)
        end
        if seen[entrantId] then
            error("duplicate entrant in seed order: " .. entrantId, 2)
        end
        seen[entrantId] = true
        state.entrants[entrantId].seed = seed
    end

    for matchId, pairing in pairs(SEED_PAIRINGS) do
        local match = state.matches[matchId]
        match.leftEntrantId = order[pairing[1]]
        match.rightEntrantId = order[pairing[2]]
        refreshMatchStatus(match)
    end

    state.status = "in_progress"
    table.insert(state.history, { type = "bracket_seeded", entrantIds = Util.copy(order) })
    return state
end

function Bracket.getMatch(state, matchId)
    local match = state.matches[matchId]
    if not match then
        error("unknown match: " .. tostring(matchId), 2)
    end
    return match
end

function Bracket.readyMatches(state)
    local result = {}
    for _, definition in ipairs(MATCH_DEFINITIONS) do
        local match = state.matches[definition.id]
        if match.status == "ready" then
            table.insert(result, match)
        end
    end
    return result
end

function Bracket.recordWinner(state, matchId, winnerEntrantId, resolution)
    assertMutable(state)
    local match = Bracket.getMatch(state, matchId)
    if match.status ~= "ready" and match.status ~= "active" then
        error("match is not resolvable: " .. matchId .. " (" .. match.status .. ")", 2)
    end
    if winnerEntrantId ~= match.leftEntrantId and winnerEntrantId ~= match.rightEntrantId then
        error("winner is not assigned to match " .. matchId, 2)
    end

    local loserEntrantId = winnerEntrantId == match.leftEntrantId
        and match.rightEntrantId or match.leftEntrantId

    match.status = "completed"
    match.winnerEntrantId = winnerEntrantId
    match.loserEntrantId = loserEntrantId
    match.resolution = resolution or "defeat"
    state.entrants[winnerEntrantId].currentLevel = match.rewardLevel
    state.entrants[loserEntrantId].eliminated = true

    table.insert(state.history, {
        type = "match_completed",
        matchId = matchId,
        winnerEntrantId = winnerEntrantId,
        loserEntrantId = loserEntrantId,
        resolution = match.resolution,
    })

    if match.nextMatchId then
        local nextMatch = state.matches[match.nextMatchId]
        if match.nextSlot == "left" then
            nextMatch.leftEntrantId = winnerEntrantId
        else
            nextMatch.rightEntrantId = winnerEntrantId
        end
        refreshMatchStatus(nextMatch)
    else
        state.championEntrantId = winnerEntrantId
        state.status = "completed"
    end

    return match
end

function Bracket.summary(state)
    local lines = {
        string.format("Astral Arena: %s (%s)", state.id, state.status),
        string.format("Entrants: %d/%d", #state.entrantOrder, state.entrantLimit),
    }

    for _, definition in ipairs(MATCH_DEFINITIONS) do
        local match = state.matches[definition.id]
        table.insert(lines, string.format(
            "%s L%d [%s] %s vs %s%s",
            match.id,
            match.level,
            match.status,
            match.leftEntrantId or "TBD",
            match.rightEntrantId or "TBD",
            match.winnerEntrantId and (" -> " .. match.winnerEntrantId) or ""
        ))
    end

    if state.championEntrantId then
        table.insert(lines, "Champion: " .. state.championEntrantId)
    end
    return table.concat(lines, "\n")
end

return Bracket
