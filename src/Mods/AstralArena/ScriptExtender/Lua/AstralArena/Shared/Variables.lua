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
end

return Variables

