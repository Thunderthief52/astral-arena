local Util
if Ext and Ext.Require then
    Util = Ext.Require("AstralArena/Core/Util.lua")
else
    Util = require("AstralArena.Core.Util")
end

local ArenaBootstrap = {}

function ArenaBootstrap.new(options)
    options = options or {}
    Util.assertNonEmptyString(options.id, "arena bootstrap id")
    local targetLevel = options.targetLevel or 5
    if type(targetLevel) ~= "number" or targetLevel < 2 or targetLevel > 12 or targetLevel % 1 ~= 0 then
        error("arena bootstrap target level must be an integer from 2 through 12", 2)
    end
    return {
        schemaVersion = 1,
        id = options.id,
        targetLevel = targetLevel,
        partySize = nil,
        phase = "awaiting_level_one",
    }
end

function ArenaBootstrap.begin(state, partyLevel, partySize)
    if state.phase ~= "awaiting_level_one" then
        error("arena bootstrap has already started", 2)
    end
    if partyLevel ~= 1 then
        error("arena bootstrap requires every active party member to be level 1", 2)
    end
    if type(partySize) ~= "number" or partySize < 1 or partySize > 4 or partySize % 1 ~= 0 then
        error("arena bootstrap requires one to four active party members", 2)
    end
    state.partySize = partySize
    state.phase = "awaiting_experience"
    return state.targetLevel
end

function ArenaBootstrap.markExperienceAwarded(state)
    if state.phase ~= "awaiting_experience" then
        error("arena bootstrap is not waiting to award experience", 2)
    end
    state.phase = "awaiting_level_up"
end

function ArenaBootstrap.confirmPartyLevel(state, partyLevel, partySize)
    if state.phase ~= "awaiting_level_up" then
        error("arena bootstrap is not waiting for level-up completion", 2)
    end
    if partyLevel ~= state.targetLevel then
        error(string.format("every active party member must finish leveling to %d", state.targetLevel), 2)
    end
    if partySize ~= state.partySize then
        error("active party membership changed during arena bootstrap", 2)
    end
    state.phase = "ready"
end

function ArenaBootstrap.activate(state)
    if state.phase ~= "ready" then
        error("arena bootstrap is not ready to enter the tournament", 2)
    end
    state.phase = "completed"
end

function ArenaBootstrap.status(state)
    return string.format(
        "Arena bootstrap %s: target L%d, %s",
        state.id,
        state.targetLevel,
        state.phase
    )
end

return ArenaBootstrap
