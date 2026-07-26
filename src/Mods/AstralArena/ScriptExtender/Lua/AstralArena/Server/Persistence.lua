local Constants = Ext.Require("AstralArena/Shared/Constants.lua")
local Bracket = Ext.Require("AstralArena/Core/Bracket.lua")

local Persistence = {}

local function modVars()
    return Ext.Vars.GetModVariables(Constants.ModuleUUID)
end

function Persistence.Load()
    return modVars().TournamentState
end

function Persistence.LoadOrCreate()
    local state = Persistence.Load()
    if type(state) ~= "table" or state.schemaVersion ~= Constants.SchemaVersion then
        state = Bracket.new({
            schemaVersion = Constants.SchemaVersion,
            levels = Constants.Levels,
        })
        Persistence.Save(state)
    end
    return state
end

function Persistence.Save(state)
    local vars = modVars()
    vars.TournamentState = state
    Ext.Vars.SyncModVariables(Constants.ModuleUUID)
end

function Persistence.Reset()
    local state = Bracket.new({
        schemaVersion = Constants.SchemaVersion,
        levels = Constants.Levels,
    })
    Persistence.Save(state)
    return state
end

return Persistence

