Mods = Mods or {}
Mods.AstralArena = Mods.AstralArena or {}

local Constants = Ext.Require("AstralArena/Shared/Constants.lua")
local Variables = Ext.Require("AstralArena/Shared/Variables.lua")
Variables.Register()

function Mods.AstralArena.GetTournamentState()
    local vars = Ext.Vars.GetModVariables(Constants.ModuleUUID)
    return vars.TournamentState
end

