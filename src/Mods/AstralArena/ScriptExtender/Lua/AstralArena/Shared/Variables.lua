local Constants = Ext.Require("AstralArena/Shared/Constants.lua")

local Variables = {}

function Variables.Register()
    Ext.Vars.RegisterModVariable(Constants.ModuleUUID, "TournamentState", {
        Server = true,
        Client = true,
        WriteableOnServer = true,
        WriteableOnClient = false,
        Persistent = true,
        SyncToClient = true,
        SyncToServer = false,
        SyncOnTick = true,
        SyncOnWrite = true,
    })
    Ext.Vars.RegisterModVariable(Constants.ModuleUUID, "ArenaCampState", {
        Server = true,
        Client = false,
        WriteableOnServer = true,
        WriteableOnClient = false,
        Persistent = true,
        SyncToClient = false,
        SyncToServer = false,
        SyncOnTick = true,
        SyncOnWrite = true,
    })
    Ext.Vars.RegisterModVariable(Constants.ModuleUUID, "ArenaRunState", {
        Server = true,
        Client = false,
        WriteableOnServer = true,
        WriteableOnClient = false,
        Persistent = true,
        SyncToClient = false,
        SyncToServer = false,
        SyncOnTick = true,
        SyncOnWrite = true,
    })
end

return Variables

