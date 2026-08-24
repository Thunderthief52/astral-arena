Mods = Mods or {}
Mods.AstralArena = Mods.AstralArena or {}

local Variables = Ext.Require("AstralArena/Shared/Variables.lua")
Variables.Register()

local Controller = Ext.Require("AstralArena/Server/Controller.lua")
Mods.AstralArena.Controller = Controller
Mods.AstralArena.API = Controller.API
Mods.AstralArena.Sparring = Controller.Sparring
Mods.AstralArena.SoloArena = Controller.SoloArena

Controller.Register()
