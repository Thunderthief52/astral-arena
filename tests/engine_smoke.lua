-- Loads the real BootstrapServer.lua against a scripted fake of Script
-- Extender and Osiris, then drives a whole gauntlet through the Controller's
-- automatic watcher: onboarding, Withers, armory, five battles, a save/load in
-- the middle of a wave, and an elimination that must survive a reload.
--
--   luajit tests/engine_smoke.lua [path/to/ScriptExtender/Lua]
local luaRoot = arg and arg[1] or "./src/Mods/AstralArena/ScriptExtender/Lua"

local log = {}
local function logLine(text)
    table.insert(log, text)
end

local timers = {}
local now = 0
local listeners = {}
local sessionLoaded = {}
local commands = {}
local modVars = {}
local translated = {}
local messageBoxes = {}
local world = {
    party = {},
    characters = {},
    nextId = 0,
    region = "AA_Arena_Main",
    host = nil,
}

local function newCharacter(guid, level, isAvatar)
    world.characters[guid] = {
        guid = guid,
        level = level,
        hp = 10,
        dead = false,
        inCombat = false,
        avatar = isAvatar,
        xp = 0,
        position = { 0, 0, 0 },
        passives = {},
        temporary = false,
    }
    return world.characters[guid]
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, child in pairs(value) do
        result[key] = deepCopy(child)
    end
    return result
end

local XP = { [3] = 900, [5] = 6500, [8] = 34000, [10] = 64000, [12] = 100000 }

Ext = {
    Require = function(path)
        local file = luaRoot .. "/" .. path
        local chunk = assert(loadfile(file))
        return chunk()
    end,
    Utils = {
        Print = logLine,
        PrintWarning = function(text) logLine("WARN " .. text) end,
        Version = function() return 30 end,
    },
    Loca = {
        GetTranslatedString = function(handle) return handle end,
        UpdateTranslatedString = function(handle, text) translated[handle] = text end,
    },
    Vars = {
        RegisterModVariable = function() end,
        GetModVariables = function()
            -- Script Extender hands out copies; writes must reassign the field.
            return setmetatable({}, {
                __index = function(_, key) return deepCopy(modVars[key]) end,
                __newindex = function(_, key, value) modVars[key] = deepCopy(value) end,
            })
        end,
        SyncModVariables = function() end,
    },
    Events = {
        SessionLoaded = {
            Subscribe = function(_, fn) table.insert(sessionLoaded, fn) end,
        },
    },
    Osiris = {
        RegisterListener = function(name, arity, when, fn)
            listeners[name] = listeners[name] or {}
            table.insert(listeners[name], fn)
        end,
    },
    RegisterConsoleCommand = function(name, fn) commands[name] = fn end,
    Timer = {
        WaitFor = function(delay, fn)
            table.insert(timers, { at = now + delay, fn = fn })
        end,
    },
    Entity = {
        Get = function(guid)
            local c = world.characters[guid]
            if not c then return nil end
            return {
                UserAvatar = c.avatar and { UserID = 1 } or nil,
                Experience = { TotalExperience = c.xp },
            }
        end,
    },
    Template = {
        GetRootTemplate = function(id)
            return { TemplateType = world.characterTemplates[id] and "character" or "item", Stats = "Stats" }
        end,
    },
}

-- Fixture templates are characters; every other template is treated as an item.
world.characterTemplates = {}
do
    local fixtures = Ext.Require("AstralArena/Shared/AIFixtures.lua")
    for _, level in ipairs(fixtures.levels()) do
        for _, member in ipairs(fixtures.get(level).members) do
            world.characterTemplates[member.templateId] = true
        end
    end
end

local function fire(name, ...)
    for _, fn in ipairs(listeners[name] or {}) do
        fn(...)
    end
end

local function members()
    local rows = {}
    for _, guid in ipairs(world.party) do
        table.insert(rows, { guid })
    end
    return rows
end

local function applyLevelUps()
    for _, guid in ipairs(world.party) do
        local c = world.characters[guid]
        for _, level in ipairs({ 3, 5, 8, 10, 12 }) do
            if c.xp >= XP[level] and c.level < level then
                c.level = level
            end
        end
    end
end

Osi = setmetatable({
    DB_PartyMembers = { Get = function() return members() end },
    GetActiveModStartupLevel = function() return "AA_Arena_Main" end,
    GetRegion = function() return world.region end,
    GetReservedUserID = function(guid) return world.characters[guid].avatar and 65537 or 65535 end,
    GetLevel = function(guid) return world.characters[guid].level end,
    GetFaction = function(guid) return world.characters[guid].faction or "player" end,
    IsDead = function(guid) local c = world.characters[guid]; return c and c.dead and 1 or 0 end,
    IsInCombat = function(guid) return world.characters[guid].inCombat and 1 or 0 end,
    GetDisplayName = function(guid) return guid end,
    GetHitpoints = function(guid) local c = world.characters[guid]; return c and c.hp or 0 end,
    GetPosition = function(guid) local p = world.characters[guid].position; return p[1], p[2], p[3] end,
    TeleportToPosition = function(guid, x, y, z) world.characters[guid].position = { x, y, z } end,
    GetHostCharacter = function() return world.host end,
    OpenMessageBoxYesNo = function(guid, key) table.insert(messageBoxes, { kind = "yesno", guid = guid, key = key }) end,
    OpenMessageBox = function(guid, key) table.insert(messageBoxes, { kind = "ok", guid = guid, key = key }) end,
    GetGold = function(guid) return world.characters[guid].gold or 0 end,
    AddGold = function(guid, amount) local c = world.characters[guid]; c.gold = (c.gold or 0) + amount end,
    AddExplorationExperience = function(guid, gain) local c = world.characters[guid]; c.xp = c.xp + gain end,
    SetLevel = function(guid, level) world.characters[guid].level = level end,
    HasPassive = function(guid, passive) return world.characters[guid] and world.characters[guid].passives[passive] and 1 or 0 end,
    AddPassive = function(guid, passive) world.characters[guid].passives[passive] = true end,
    Resurrect = function(guid) local c = world.characters[guid]; c.dead = false; c.hp = 10 end,
    SetHitpointsPercentage = function(guid) local c = world.characters[guid]; if c then c.hp = 10 end end,
    PROC_CharacterFullRestore = function(guid) local c = world.characters[guid]; if c and not c.dead then c.hp = 10 end end,
    CreateAt = function(template, x, y, z)
        world.nextId = world.nextId + 1
        local guid = "enemy_" .. world.nextId
        local c = newCharacter(guid, 1, false)
        c.temporary = true
        c.position = { x, y, z }
        return guid
    end,
    SetFaction = function(guid, faction) world.characters[guid].faction = faction end,
    RequestDeleteTemporary = function(guid) world.characters[guid] = nil end,
    LeaveCombat = function(guid) local c = world.characters[guid]; if c then c.inCombat = false end end,
    EnterCombat = function(a, b)
        if world.characters[a] then world.characters[a].inCombat = true end
        if world.characters[b] then world.characters[b].inCombat = true end
    end,
    PROC_Hirelings_Hire = function(guid) table.insert(world.party, guid) end,
    GetItemByTemplateInInventory = function() return "" end,
}, {
    __index = function(_, name)
        return function() return nil end
    end,
})

local function runTimers(limitMs)
    local target = now + limitMs
    while true do
        table.sort(timers, function(a, b) return a.at < b.at end)
        local nextTimer = timers[1]
        if not nextTimer or nextTimer.at > target then
            break
        end
        table.remove(timers, 1)
        now = nextTimer.at
        nextTimer.fn()
    end
    now = target
end

local function answerMenus(answer, onlyKey)
    local handled = 0
    local index = 1
    while index <= #messageBoxes do
        local box = messageBoxes[index]
        if box.kind == "yesno" and (not onlyKey or box.key == onlyKey) then
            table.remove(messageBoxes, index)
            -- BG3 reports the clicking player's selected character, which is often
            -- not the character the box was opened for.
            local responder = box.key == "h4b7ad31ee2074bfab4a21407db48a032" and world.party[#world.party] or box.guid
            fire("MessageBoxYesNoClosed", responder, box.key, answer)
            handled = handled + 1
        else
            index = index + 1
        end
    end
    return handled
end

local function enemies()
    local result = {}
    for guid, c in pairs(world.characters) do
        if c.temporary then
            table.insert(result, guid)
        end
    end
    table.sort(result)
    return result
end

local function knockOut(guid)
    local c = world.characters[guid]
    c.hp = 0
    fire("StatusApplied", guid, "DOWNED", "", 0)
end

local function expect(condition, message)
    if not condition then
        io.write(table.concat(log, "\n"), "\n")
        error(message, 2)
    end
end

local function logContains(text)
    for _, line in ipairs(log) do
        if line:find(text, 1, true) then
            return true
        end
    end
    return false
end

local function loadSession()
    listeners, sessionLoaded, commands, timers = {}, {}, {}, {}
    local bootstrap = assert(loadfile(luaRoot .. "/BootstrapServer.lua"))
    Mods = nil
    bootstrap()
    for _, fn in ipairs(sessionLoaded) do
        fn()
    end
end

-- New Adventure: two split-screen avatars at level 1.
newCharacter("avatar_a", 1, true)
newCharacter("avatar_b", 1, true)
world.party = { "avatar_a", "avatar_b" }
world.host = "avatar_a"
loadSession()
runTimers(3000)
expect(world.characters.avatar_a.xp == 900, "bootstrap should award level-3 XP")
applyLevelUps()
runTimers(2000)
-- Withers: decline every offer.
for _ = 1, 10 do
    runTimers(1000)
    if answerMenus(false, "h93ba8d19ef074e7eb7c59686bbc9fbb5") == 0 then break end
end
runTimers(3000)
expect(#enemies() == 0, "no enemy may exist before the ready prompt")
expect(logContains("Prepared AI bout 1/5 at L3"), "bout 1 should be prepared at level 3")

local function fightBattle(expectedLevel, loseOnWave)
    local waves = 0
    for _ = 1, 8 do
        runTimers(1000)
        answerMenus(true)
        runTimers(500)
        local foes = enemies()
        if #foes == 0 then
            break
        end
        waves = waves + 1
        if loseOnWave == waves then
            for _, guid in ipairs(world.party) do
                knockOut(guid)
            end
            return waves
        end
        for _, guid in ipairs(foes) do
            knockOut(guid)
        end
        runTimers(500)
    end
    return waves
end

local expectedWaves = { [3] = 2, [5] = 2, [8] = 3, [10] = 3 }
for _, level in ipairs({ 3, 5, 8, 10 }) do
    local waves = fightBattle(level)
    expect(waves == expectedWaves[level], "level " .. level .. " should have " .. expectedWaves[level] .. " waves, got " .. waves)
    applyLevelUps()
    runTimers(3000)
end
expect(world.characters.avatar_a.level == 12, "party should reach level 12")
local armoryLines = 0
for _, line in ipairs(log) do
    if line:find("Arena armory rolled", 1, true) then armoryLines = armoryLines + 1 end
end
expect(armoryLines == 1, "armory must be delivered exactly once")

-- Save in the middle of championship wave 1, then "load" it.
runTimers(1000)
answerMenus(true)
runTimers(500)
expect(#enemies() > 0, "championship wave 1 should spawn")
local savedVars = deepCopy(modVars)
local savedWorld = deepCopy(world)
world.characters.avatar_b.dead = true
world.characters.avatar_b.hp = 0

world = savedWorld
world.characters.avatar_b.dead = true
world.characters.avatar_b.inCombat = true
modVars = deepCopy(savedVars)
messageBoxes = {}
loadSession()
runTimers(3000)
expect(logContains("was loaded. The unfinished battle was reset"), "mid-wave save should be recovered")
expect(#enemies() == 0, "stale enemies should be deleted after loading a mid-wave save")
expect(not world.characters.avatar_b.dead, "dead ally should be restored after mid-wave recovery")
runTimers(3000)
armoryLines = 0
for _, line in ipairs(log) do
    if line:find("Arena armory rolled", 1, true) then armoryLines = armoryLines + 1 end
end
expect(armoryLines == 1, "reload must not deliver a second armory")

-- Lose championship wave 2: the run must end.
local waves = fightBattle(12, 2)
expect(waves == 2, "should lose on wave 2")
runTimers(6000)
expect(logContains("RUN OVER"), "elimination should be announced")
local runOverBox = false
for _, box in ipairs(messageBoxes) do
    if box.kind == "ok" then runOverBox = true end
end
expect(runOverBox, "host should get a run-over message box")
expect(#enemies() == 0, "enemies should be deleted after elimination")
expect(world.characters.avatar_a.hp > 0 and not world.characters.avatar_a.dead, "party should be restored after elimination")
local stored = modVars.ArenaRunState
expect(stored.outcome == "eliminated" and stored.ending.level == 12 and stored.ending.wave == 2, "elimination should be saved")
expect(#stored.victories == 4, "four victories should be recorded")

-- Reload after the loss: nothing may start again.
messageBoxes = {}
local before = #log
loadSession()
runTimers(120000)
answerMenus(true)
runTimers(5000)
expect(#enemies() == 0, "no battle may start after an elimination reload")
for index = before + 1, #log do
    expect(not log[index]:find("Prepared AI bout", 1, true), "no bout may be prepared after elimination")
end
commands.aa_ai_status()
expect(log[#log]:find("ELIMINATED", 1, true) ~= nil, "status should report the elimination")

local pauses = 0
for _, line in ipairs(log) do
    if line:find("onboarding paused", 1, true) then pauses = pauses + 1 end
end
io.write(string.format("engine smoke passed: %d log lines, %d pause lines\n", #log, pauses))
if os.getenv("SMOKE_FULL") then for _, line in ipairs(log) do io.write("  ", line, "\n") end end
io.write("last lines:\n")
for index = math.max(1, #log - 6), #log do
    io.write("  ", log[index], "\n")
end
