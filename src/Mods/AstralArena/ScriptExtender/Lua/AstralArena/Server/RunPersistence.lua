local Constants = Ext.Require("AstralArena/Shared/Constants.lua")
local RunRecord = Ext.Require("AstralArena/Core/RunRecord.lua")

-- Stores the gauntlet RunRecord in a persistent, server-only ModVar so an
-- elimination, the one-time armory, and the staging origin survive save/load.
local RunPersistence = {}

local function modVars()
    return Ext.Vars.GetModVariables(Constants.ModuleUUID)
end

function RunPersistence.load()
    local stored = modVars().ArenaRunState
    local record = RunRecord.normalize(stored)
    if record ~= stored then
        RunPersistence.save(record)
    end
    return record
end

function RunPersistence.save(record)
    local vars = modVars()
    -- Reassign the whole table so Script Extender marks the variable dirty.
    vars.ArenaRunState = record
    Ext.Vars.SyncModVariables(Constants.ModuleUUID)
end

return RunPersistence
