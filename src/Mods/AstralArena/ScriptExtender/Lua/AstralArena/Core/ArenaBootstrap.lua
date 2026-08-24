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
        schemaVersion = 2,
        id = options.id,
        targetLevel = targetLevel,
        partySize = nil,
        memberGuids = nil,
        phase = "awaiting_level_one",
    }
end

local function rosterSnapshot(party)
    if type(party) == "number" then
        if party < 1 or party > 4 or party % 1 ~= 0 then
            error("arena bootstrap requires one to four active party members", 3)
        end
        return party, nil
    end
    if type(party) ~= "table" or not party[1] or #party > 4 then
        error("arena bootstrap requires one to four active party members", 3)
    end
    local guids = {}
    for _, member in ipairs(party) do
        if type(member) ~= "table" or type(member.guid) ~= "string" or member.guid == "" then
            error("arena bootstrap party members require GUIDs", 3)
        end
        if guids[member.guid] then
            error("arena bootstrap party contains a duplicate member", 3)
        end
        guids[member.guid] = true
    end
    return #party, guids
end

function ArenaBootstrap.begin(state, partyLevel, party)
    if state.phase ~= "awaiting_level_one" then
        error("arena bootstrap has already started", 2)
    end
    if partyLevel ~= 1 then
        error("arena bootstrap requires every active party member to be level 1", 2)
    end
    local partySize, memberGuids = rosterSnapshot(party)
    state.partySize = partySize
    state.memberGuids = memberGuids
    state.phase = "awaiting_experience"
    return state.targetLevel
end

function ArenaBootstrap.markExperienceAwarded(state)
    if state.phase ~= "awaiting_experience" then
        error("arena bootstrap is not waiting to award experience", 2)
    end
    state.phase = "awaiting_level_up"
end

function ArenaBootstrap.confirmPartyLevel(state, partyLevel, party, approvedAdditions)
    if state.phase ~= "awaiting_level_up" then
        error("arena bootstrap is not waiting for level-up completion", 2)
    end
    if partyLevel ~= state.targetLevel then
        error(string.format("every active party member must finish leveling to %d", state.targetLevel), 2)
    end
    local partySize, memberGuids = rosterSnapshot(party)
    if state.memberGuids and memberGuids then
        for guid in pairs(state.memberGuids) do
            if not memberGuids[guid] then
                error("active party membership changed during arena bootstrap", 2)
            end
        end
        for guid in pairs(memberGuids) do
            if not state.memberGuids[guid] and not (approvedAdditions and approvedAdditions[guid]) then
                error("active party membership changed during arena bootstrap", 2)
            end
        end
        state.memberGuids = memberGuids
        state.partySize = partySize
    elseif partySize ~= state.partySize then
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
