local Constants = Ext.Require("AstralArena/Shared/Constants.lua")

local CampPersistence = {}

local function modVars()
    return Ext.Vars.GetModVariables(Constants.ModuleUUID)
end

function CampPersistence.LoadOrCreate()
    local state = modVars().ArenaCampState
    if type(state) ~= "table" or state.schemaVersion ~= 1 then
        state = {
            schemaVersion = 1,
            fundedCharacters = {},
            hiredCharacters = {},
            onboardingComplete = false,
        }
        CampPersistence.Save(state)
    end
    state.fundedCharacters = state.fundedCharacters or {}
    state.hiredCharacters = state.hiredCharacters or {}
    return state
end

function CampPersistence.Save(state)
    local vars = modVars()
    vars.ArenaCampState = state
    Ext.Vars.SyncModVariables(Constants.ModuleUUID)
end

return CampPersistence
