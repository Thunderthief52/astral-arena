local Bracket = Ext.Require("AstralArena/Core/Bracket.lua")
local Constants = Ext.Require("AstralArena/Shared/Constants.lua")
local Persistence = Ext.Require("AstralArena/Server/Persistence.lua")
local Bg3Adapter = Ext.Require("AstralArena/Server/Bg3Adapter.lua")
local Sparring = Ext.Require("AstralArena/Server/Sparring.lua")

local Controller = { API = {} }
local registered = false

local function printLine(message)
    Ext.Utils.Print("[Astral Arena] " .. tostring(message))
end

local function printState(state)
    printLine("\n" .. Bracket.summary(state))
end

local sparring = Sparring.new(Bg3Adapter, printLine)
Controller.Sparring = sparring

function Controller.API.GetState()
    return Persistence.LoadOrCreate()
end

function Controller.API.Reset()
    local state = Persistence.Reset()
    printLine("Tournament reset.")
    return state
end

function Controller.API.CreateDemo()
    local state = Persistence.Reset()
    for seed = 1, 8 do
        Bracket.register(state, {
            id = "seed-" .. seed,
            displayName = "Entrant " .. seed,
            roster = {},
        })
    end
    Bracket.seed(state)
    Persistence.Save(state)
    printState(state)
    return state
end

function Controller.API.RecordWinner(matchId, entrantId, resolution)
    local state = Persistence.LoadOrCreate()
    Bracket.recordWinner(state, matchId, entrantId, resolution)
    Persistence.Save(state)
    printState(state)
    return state
end

local function safely(action)
    local ok, result = pcall(action)
    if not ok then
        printLine("ERROR: " .. tostring(result))
        return nil
    end
    return result
end

function Controller.Register()
    if registered then
        return
    end
    registered = true

    Ext.Events.SessionLoaded:Subscribe(function()
        local state = Persistence.LoadOrCreate()
        printLine("Loaded tournament state: " .. state.status)
    end)

    Ext.RegisterConsoleCommand("aa_demo", function()
        safely(Controller.API.CreateDemo)
    end)

    Ext.RegisterConsoleCommand("aa_state", function()
        safely(function()
            printState(Persistence.LoadOrCreate())
        end)
    end)

    Ext.RegisterConsoleCommand("aa_reset", function()
        safely(Controller.API.Reset)
    end)

    Ext.RegisterConsoleCommand("aa_win", function(_, matchId, entrantId)
        safely(function()
            if not matchId or not entrantId then
                error("usage: !aa_win <match-id> <entrant-id>")
            end
            Controller.API.RecordWinner(tostring(matchId), tostring(entrantId), "console")
        end)
    end)

    Ext.RegisterConsoleCommand("aa_help", function()
        printLine("Astral Arena " .. Constants.DisplayVersion)
        printLine("Playable sparring commands:")
        printLine("  !aa_doctor                  validate online or split-screen team discovery")
        printLine("  !aa_scan                    list assignments and player-avatar components")
        printLine("  !aa_spar                    begin a same-level match after a 3-second countdown")
        printLine("  !aa_rematch                 rescan teams and replay after a completed match")
        printLine("  !aa_spar_status             show the current or previous sparring result")
        printLine("  !aa_forfeit left|right      concede for the selected side")
        printLine("  !aa_abort                   stop the match and restore both teams")
        printLine("Tournament simulation: !aa_demo, !aa_state, !aa_win <match> <entrant>, !aa_reset")
    end)

    Ext.RegisterConsoleCommand("aa_version", function()
        printLine(string.format(
            "Astral Arena %s; Script Extender API v%s",
            Constants.DisplayVersion,
            tostring(Ext.Utils.Version())
        ))
    end)

    Ext.RegisterConsoleCommand("aa_doctor", function()
        safely(function()
            printLine(string.format(
                "Astral Arena %s; Script Extender API v%s; connected users reported by game: %s",
                Constants.DisplayVersion,
                tostring(Ext.Utils.Version()),
                tostring(Osi.GetUserCount())
            ))
            sparring:doctor()
            printLine("Doctor complete. Team discovery and safety checks passed.")
        end)
    end)

    Ext.RegisterConsoleCommand("aa_scan", function()
        safely(function()
            sparring:scan()
        end)
    end)

    Ext.RegisterConsoleCommand("aa_spar", function()
        safely(function()
            sparring:startAuto()
        end)
    end)

    Ext.RegisterConsoleCommand("aa_rematch", function()
        safely(function()
            sparring:rematch()
        end)
    end)

    Ext.RegisterConsoleCommand("aa_spar_status", function()
        safely(function()
            printLine(sparring:status())
        end)
    end)

    Ext.RegisterConsoleCommand("aa_forfeit", function(_, side)
        safely(function()
            if side ~= "left" and side ~= "right" then
                error("usage: !aa_forfeit left|right")
            end
            sparring:forfeit(side)
        end)
    end)

    Ext.RegisterConsoleCommand("aa_abort", function()
        safely(function()
            sparring:abort("manual-abort")
        end)
    end)

    printLine("Server controller registered. Use !aa_help for playtest commands.")
end

return Controller
