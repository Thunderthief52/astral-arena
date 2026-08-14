local Bracket = Ext.Require("AstralArena/Core/Bracket.lua")
local Constants = Ext.Require("AstralArena/Shared/Constants.lua")
local Persistence = Ext.Require("AstralArena/Server/Persistence.lua")
local Bg3Adapter = Ext.Require("AstralArena/Server/Bg3Adapter.lua")
local Sparring = Ext.Require("AstralArena/Server/Sparring.lua")
local SoloArena = Ext.Require("AstralArena/Server/SoloArena.lua")
local AIFixtures = Ext.Require("AstralArena/Shared/AIFixtures.lua")
local RewardCatalog = Ext.Require("AstralArena/Shared/RewardCatalog.lua")
local ArenaLayouts = Ext.Require("AstralArena/Shared/ArenaLayouts.lua")
local ArenaSites = Ext.Require("AstralArena/Shared/ArenaSites.lua")

local Controller = { API = {} }
local registered = false

local function printLine(message)
    Ext.Utils.Print("[Astral Arena] " .. tostring(message))
end

local function printState(state)
    printLine("\n" .. Bracket.summary(state))
end

local sparring = Sparring.new(Bg3Adapter, printLine)
local soloArena = SoloArena.new(Bg3Adapter, printLine, AIFixtures, RewardCatalog, ArenaLayouts, ArenaSites)
Controller.Sparring = sparring
Controller.SoloArena = soloArena

local autoGeneration = 0

local function isAstralAdventureActive()
    local ok, startupLevel = pcall(function()
        return Osi.GetActiveModStartupLevel()
    end)
    return ok and startupLevel == Constants.ArenaLevel
end

local function configureAdventureTransition()
    local ok, err = pcall(function()
        Osi.DB_CharacterCreationTransitionInfo(Constants.ArenaLevel, "")
    end)
    if not ok then
        printLine("ERROR: Could not configure the post-character-creation arena transition: " .. tostring(err))
        return false
    end
    return true
end

local function isSystemCharacterCreationLevel(levelName)
    return type(levelName) == "string" and levelName:match("^SYS_CC_") ~= nil
end

local function recoverCharacterCreationHandoff(levelName)
    if not isSystemCharacterCreationLevel(levelName) or not isAstralAdventureActive() then
        return false
    end

    local ok, err = pcall(function()
        Osi.TeleportPartiesToLevelWithMovie(Constants.ArenaLevel, "", "")
    end)
    if not ok then
        printLine("ERROR: Could not recover the character-creation handoff: " .. tostring(err))
        return false
    end

    printLine("Recovered a finished party stranded in " .. levelName .. "; transferring to " .. Constants.ArenaLevel .. ".")
    return true
end

local function scheduleAutomaticProgression(generation)
    Bg3Adapter.schedule(1000, function()
        if generation ~= autoGeneration then
            return
        end
        local ok, action = pcall(function()
            return soloArena:autoAdvance()
        end)
        if not ok then
            printLine("Automatic arena onboarding paused: " .. tostring(action))
            return
        end
        if action == "outside" then
            printLine("Automatic arena onboarding ignored outside " .. Constants.ArenaLevel .. ".")
            return
        elseif action == "completed" then
            return
        elseif action == "bootstrapped" then
            printLine("Automatic onboarding is waiting for every player to finish level-up choices through level 5.")
        elseif action == "started" then
            printLine("Automatic progression started the next Astral Arena bout.")
        end
        scheduleAutomaticProgression(generation)
    end)
end

local function armAutomaticProgression()
    autoGeneration = autoGeneration + 1
    local generation = autoGeneration
    Bg3Adapter.schedule(1500, function()
        if generation == autoGeneration then
            local ok, action = pcall(function()
                return soloArena:autoAdvance()
            end)
            if not ok then
                printLine("Automatic arena onboarding paused: " .. tostring(action))
                return
            end
            if action ~= "outside" and action ~= "completed" then
                scheduleAutomaticProgression(generation)
            end
        end
    end)
end

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
        armAutomaticProgression()
    end)

    -- SessionLoaded is a restricted Script Extender callback and cannot mutate
    -- Osiris databases. Register the transition immediately before Osiris
    -- processes CharacterCreationFinished instead.
    Ext.Osiris.RegisterListener("CharacterCreationFinished", 0, "before", function()
        if isAstralAdventureActive() then
            configureAdventureTransition()
        end
    end)

    Ext.Osiris.RegisterListener("CharacterCreationFinished", 0, "after", function()
        if isAstralAdventureActive() then
            armAutomaticProgression()
        end
    end)

    Ext.Osiris.RegisterListener("LevelGameplayReady", 2, "after", function(levelName)
        if levelName == Constants.ArenaLevel then
            armAutomaticProgression()
        else
            recoverCharacterCreationHandoff(levelName)
        end
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
        printLine("AI progression starts automatically after Adventure character creation.")
        printLine("AI diagnostics and recovery commands:")
        printLine("  !aa_ai_bootstrap            award L1 characters XP for native level-ups to L5")
        printLine("  !aa_ai_doctor               validate party, AI templates, and reward templates")
        printLine("  !aa_ai_start                start the L5 -> L8 -> L10 -> L12 AI run")
        printLine("  !aa_ai_pick <1-6> <member>  deliver two random rolls and one selected item")
        printLine("  !aa_ai_continue             continue after every character finishes level-up")
        printLine("  !aa_ai_status               show run, reward, or level-up state")
        printLine("  !aa_ai_abort                restore players and delete active AI enemies")
        printLine("  !aa_ai_reset                reset session state; does not undo XP or loot")
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
            if soloArena.active then
                error("an AI arena match is active; use !aa_ai_abort first")
            end
            sparring:startAuto()
        end)
    end)

    Ext.RegisterConsoleCommand("aa_rematch", function()
        safely(function()
            if soloArena.active then
                error("an AI arena match is active; use !aa_ai_abort first")
            end
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

    Ext.RegisterConsoleCommand("aa_ai_doctor", function()
        safely(function()
            soloArena:doctor()
            printLine("AI doctor complete. No game state was changed.")
        end)
    end)

    Ext.RegisterConsoleCommand("aa_ai_bootstrap", function()
        safely(function()
            if sparring.active then
                error("a PvP sparring match is active; use !aa_abort first")
            end
            soloArena:bootstrapParty()
        end)
    end)

    Ext.RegisterConsoleCommand("aa_ai_start", function()
        safely(function()
            if sparring.active then
                error("a PvP sparring match is active; use !aa_abort first")
            end
            soloArena:start()
        end)
    end)

    Ext.RegisterConsoleCommand("aa_ai_pick", function(_, choiceIndex, recipientIndex)
        safely(function()
            if not choiceIndex then
                error("usage: !aa_ai_pick <choice 1-6> <recipient number>")
            end
            soloArena:pick(choiceIndex, recipientIndex)
        end)
    end)

    Ext.RegisterConsoleCommand("aa_ai_continue", function()
        safely(function()
            if sparring.active then
                error("a PvP sparring match is active; use !aa_abort first")
            end
            soloArena:continue()
        end)
    end)

    Ext.RegisterConsoleCommand("aa_ai_status", function()
        safely(function()
            printLine(soloArena:status())
        end)
    end)

    Ext.RegisterConsoleCommand("aa_ai_abort", function()
        safely(function()
            soloArena:abort("manual-abort")
        end)
    end)

    Ext.RegisterConsoleCommand("aa_ai_reset", function()
        safely(function()
            soloArena:reset()
        end)
    end)

    printLine("Server controller registered. Use !aa_help for playtest commands.")
end

return Controller
