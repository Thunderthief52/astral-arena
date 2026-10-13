local Match = Ext.Require("AstralArena/Core/Match.lua")
local Roster = Ext.Require("AstralArena/Core/Roster.lua")
local SoloRun = Ext.Require("AstralArena/Core/SoloRun.lua")
local ArenaBootstrap = Ext.Require("AstralArena/Core/ArenaBootstrap.lua")
local Constants = Ext.Require("AstralArena/Shared/Constants.lua")
local PreparationLoadout = Ext.Require("AstralArena/Shared/PreparationLoadout.lua")
local RunRecord = Ext.Require("AstralArena/Core/RunRecord.lua")

local SoloArena = {}
SoloArena.__index = SoloArena

local function guids(group)
    return Roster.guids(group)
end

local function factionSet(group)
    local result = {}
    for _, member in ipairs(group.members) do
        if member.faction and member.faction ~= "" then
            result[member.faction] = true
        end
    end
    return result
end

local function countdown(value)
    value = tonumber(value) or 3
    return math.max(0, math.min(30, math.floor(value)))
end

-- Session-only fallback used by deterministic tests and by callers that do not
-- provide a save-backed store. The game passes RunPersistence instead.
local function memoryRunStore()
    local record = RunRecord.new()
    return {
        load = function()
            return record
        end,
        save = function(value)
            record = value
        end,
    }
end

function SoloArena.new(adapter, output, fixtures, rewardCatalog, arenaLayouts, arenaSites, campService, runStore)
    return setmetatable({
        adapter = adapter,
        output = output,
        fixtures = fixtures,
        rewardCatalog = rewardCatalog,
        arenaLayouts = arenaLayouts,
        arenaSites = arenaSites,
        run = nil,
        bootstrapState = nil,
        active = nil,
        generation = 0,
        recentOfferItemIds = {},
        rewardRecipients = nil,
        repairNoticeTarget = nil,
        menu = nil,
        preparationBundleDelivered = false,
        campService = campService,
        runStore = runStore or memoryRunStore(),
        endingNoticeShown = false,
        restartCooldown = 0,
    }, SoloArena)
end

local PROGRESSION_LEVELS = { 3, 5, 8, 10, 12 }

local function progressionFrom(startingLevel)
    local result = {}
    local found = false
    for _, level in ipairs(PROGRESSION_LEVELS) do
        if level == startingLevel then
            found = true
        end
        if found then
            table.insert(result, level)
        end
    end
    if #result < 1 then
        error("an AI arena run requires a party at level 3, 5, 8, 10, or 12", 3)
    end
    return result
end

function SoloArena:_record()
    return self.runStore.load()
end

function SoloArena:_saveRecord(record)
    self.runStore.save(record)
end

local function enemyFactionList(group)
    local values = {}
    local seen = {}
    for _, member in ipairs(group and group.members or {}) do
        if member.faction and member.faction ~= "" and not seen[member.faction] then
            seen[member.faction] = true
            table.insert(values, member.faction)
        end
    end
    return values
end

function SoloArena:_persistCombat(active)
    -- Persistence protects save/load recovery; it must never block a fight.
    local ok, err = pcall(function()
        local record = self:_record()
        if RunRecord.isOver(record) then
            return
        end
        RunRecord.beginCombat(record, {
            level = self.run and self.run.level,
            battleIndex = self.run and self.run.battleIndex,
            wave = active.waveIndex,
            enemyGuids = guids(active.teams.right),
            enemyFactions = enemyFactionList(active.teams.right),
        })
        self:_saveRecord(record)
    end)
    if not ok then
        self.output("WARNING: could not record the active wave for save recovery: " .. tostring(err))
    end
end

-- Position in the full 3 -> 12 gauntlet, even when a reload rebuilt the live
-- run from a later tier.
local function gauntletPosition(level)
    for index, value in ipairs(PROGRESSION_LEVELS) do
        if value == level then
            return index, #PROGRESSION_LEVELS
        end
    end
    return 1, #PROGRESSION_LEVELS
end

-- BG3 reports a message-box answer against whichever character the clicking
-- player currently has selected: a hireling, the other split-screen avatar, or
-- the host. Any active party member may therefore answer an arena prompt.
local function isPartyResponder(adapter, menu, characterGuid)
    if characterGuid == menu.ownerGuid then
        return true
    end
    local ok, members = pcall(adapter.partyMembers)
    if not ok or type(members) ~= "table" then
        return false
    end
    for _, member in ipairs(members) do
        if member.guid == characterGuid then
            return true
        end
    end
    return false
end

local function menuResultIsYes(result)
    return result == true or result == 1 or result == "1"
end

function SoloArena:_menuOwner(members)
    if self.adapter.menuOwner then
        return self.adapter.menuOwner(members)
    end
    return members and members[1] and members[1].guid or nil
end

function SoloArena:_showMenu()
    local menu = self.menu
    if not menu then
        return false
    end

    local key
    local message
    if menu.kind == "wave_start" then
        key = Constants.MenuMessages.waveStart
        if menu.isInitial then
            message = string.format(
                "ARENA READY — Begin wave 1/%d now? Choose Yes only when every player has finished equipping and positioning. Choose No for more preparation time; this prompt returns in one minute.",
                self.active and self.active.waveCount or 1
            )
        else
            message = string.format(
                "WAVE %d CLEARED — Begin wave %d/%d now? Living allies have full health, spell slots, and class resources. Dead allies still require Revivify. Choose No for more preparation time; this prompt returns in one minute.",
                menu.clearedWave or 1,
                menu.nextWave or 2,
                self.active and self.active.waveCount or 2
            )
        end
    elseif menu.kind == "reward" then
        key = Constants.MenuMessages.reward
        local choices = self.run.pendingReward.offer.choices
        local choice = choices[menu.choiceIndex]
        message = string.format(
            "Victory reward %d/%d: %s (%s). Take this item? Choose No to view the next reward.",
            menu.choiceIndex,
            #choices,
            choice.displayName,
            choice.rarity
        )
    elseif menu.kind == "recipient" then
        key = Constants.MenuMessages.recipient
        local members = self.rewardRecipients.members
        local recipient = members[menu.recipientIndex]
        message = string.format(
            "Give %s to %s? Choose No to view the next party member.",
            menu.selectedChoice.displayName,
            recipient.name or recipient.guid
        )
    else
        error("unknown arena menu state: " .. tostring(menu.kind), 2)
    end

    menu.messageKey = key
    self.adapter.openYesNo(menu.ownerGuid, key, message)
    return true
end

function SoloArena:_openMenu(kind, members)
    self.menu = {
        kind = kind,
        ownerGuid = self:_menuOwner(members),
        choiceIndex = 1,
        recipientIndex = 1,
    }
    self:_showMenu()
end

function SoloArena:reopenMenu()
    if not self.menu then
        error("there is no arena menu to reopen", 2)
    end
    return self:_showMenu()
end

function SoloArena:handleMenuResponse(characterGuid, messageKey, result)
    local menu = self.menu
    if not menu or messageKey ~= menu.messageKey or not isPartyResponder(self.adapter, menu, characterGuid) then
        return false
    end

    local accepted = menuResultIsYes(result)
    if menu.kind == "wave_start" then
        local active = self.active
        if not active then
            self.menu = nil
            return true
        end
        if accepted then
            local generation = active.generation
            local startsNextWave = active.transitioning
            self.menu = nil
            if startsNextWave then
                self:_spawnNextWave(generation)
            else
                self:_beginCombat(generation)
            end
        else
            menu.dismissed = true
            local message = "Arena paused safely. Prepare for as long as you need; the ready prompt will return in one minute."
            self.output(message)
            for _, member in ipairs(active.teams.left.members) do
                self.adapter.notify(member.guid, message)
            end
            -- The recurring prompt retry armed when this menu opened will
            -- redisplay it without spawning or forcing a wave.
        end
        return true
    end

    if menu.kind == "reward" then
        local choices = self.run.pendingReward.offer.choices
        if accepted then
            menu.selectedChoice = choices[menu.choiceIndex]
            menu.kind = "recipient"
            menu.recipientIndex = 1
        else
            menu.choiceIndex = (menu.choiceIndex % #choices) + 1
        end
        self:_showMenu()
        return true
    end

    if menu.kind == "recipient" then
        local members = self.rewardRecipients.members
        if accepted then
            local choiceIndex = menu.choiceIndex
            local recipientIndex = menu.recipientIndex
            self:pick(choiceIndex, recipientIndex)
        else
            menu.recipientIndex = (menu.recipientIndex % #members) + 1
            self:_showMenu()
        end
        return true
    end

    return false
end

function SoloArena:confirmReadyPrompt()
    local menu = self.menu
    if not menu or menu.kind ~= "wave_start" then
        error("no wave ready prompt is open", 2)
    end
    return self:handleMenuResponse(menu.ownerGuid, menu.messageKey, true)
end

function SoloArena:_openWaveStartMenu(members, options)
    options = options or {}
    self.menu = {
        kind = "wave_start",
        ownerGuid = self:_menuOwner(members),
        isInitial = options.isInitial == true,
        clearedWave = options.clearedWave,
        nextWave = options.nextWave,
    }
    local shown = self:_showMenu()
    local menu = self.menu
    local generation = self.active and self.active.generation
    local scheduleRetry = self.adapter.schedulePromptRetry or self.adapter.schedule
    local function armRetry()
        if not menu or menu.retryArmed then
            return
        end
        menu.retryArmed = true
        scheduleRetry(60000, function()
            menu.retryArmed = nil
            if self.active and self.active.generation == generation and self.menu == menu then
                menu.dismissed = nil
                self:_showMenu()
                armRetry()
            end
        end)
    end
    armRetry()
    return shown
end

function SoloArena:_requireOpenRun()
    local record = self:_record()
    if RunRecord.isOver(record) then
        error(RunRecord.summary(record) .. " Start a New Game with Astral Arena Adventure for a fresh run.", 3)
    end
    return record
end

function SoloArena:bootstrapParty()
    self:_requireOpenRun()
    if self.active or (self.run and self.run.phase ~= "completed") then
        error("an AI arena run is already in progress", 2)
    end
    if self.bootstrapState and self.bootstrapState.phase ~= "completed" then
        error("arena bootstrap has already started; finish leveling or use !aa_ai_reset", 2)
    end
    local party = self:_party()
    self:_requireArenaParty(party)
    self:_validateParty(party, false)
    self.generation = self.generation + 1
    local state = ArenaBootstrap.new({
        id = "arena-bootstrap-" .. tostring(self.generation),
        targetLevel = 3,
    })
    local targetLevel = ArenaBootstrap.begin(state, party.level, party.members)
    self.bootstrapState = state
    self.adapter.awardPartyToLevel(party.members, targetLevel)
    ArenaBootstrap.markExperienceAwarded(state)
    self.output(string.format(
        "Arena bootstrap awarded the level-3 XP threshold to %d character(s). Complete every native level-up; the initiation ready prompt will appear automatically.",
        #party.members
    ))
    for _, member in ipairs(party.members) do
        self.adapter.notify(member.guid, "Astral Arena: finish leveling to 3. The initiation ready prompt will appear automatically.")
    end
    return state
end

function SoloArena:_party()
    return Roster.playerParty(self.adapter.partyMembers(), 4)
end

function SoloArena:_repairMixedLevelParty()
    local members = self.adapter.partyMembers()
    if type(members) ~= "table" or #members < 1 or #members > 4 then
        return false
    end
    if self.adapter.isPartyInArena and not self.adapter.isPartyInArena(members) then
        return false
    end

    local targetLevel = 3
    if self.run and self.run.phase == "awaiting_level_up" then
        targetLevel = self.run.level
    elseif self.bootstrapState then
        targetLevel = self.bootstrapState.targetLevel
    else
        -- Session state is intentionally transient. If a co-op save is loaded
        -- while avatars are at different points in a native level-up, infer the
        -- next supported tier from the highest reported character level.
        local highestLevel = 1
        for _, member in ipairs(members) do
            highestLevel = math.max(highestLevel, tonumber(member.level) or 1)
        end
        for _, level in ipairs(PROGRESSION_LEVELS) do
            if level >= highestLevel then
                targetLevel = level
                break
            end
        end
    end

    local hasLowerLevel = false
    for _, member in ipairs(members) do
        if type(member.level) ~= "number" or member.level < 1 or member.level > targetLevel then
            return false
        end
        hasLowerLevel = hasLowerLevel or member.level < targetLevel
    end
    if not hasLowerLevel then
        return false
    end

    local awardedCount = self.adapter.awardPartyToLevel(members, targetLevel) or 0
    if awardedCount > 0 and self.repairNoticeTarget ~= targetLevel then
        self.repairNoticeTarget = targetLevel
        self.output(string.format(
            "Recovered split-screen progression: awarded missing XP to %d avatar(s) for level %d.",
            awardedCount,
            targetLevel
        ))
        for _, member in ipairs(members) do
            if member.level < targetLevel then
                self.adapter.notify(member.guid, "Astral Arena: missing XP restored. Finish leveling to " .. tostring(targetLevel) .. ".")
            end
        end
    end
    return true
end

function SoloArena:_requireArenaParty(party)
    if self.adapter.isPartyInArena and not self.adapter.isPartyInArena(party.members) then
        error("automatic arena progression is only available inside AA_Arena_Main", 2)
    end
end

function SoloArena:_validateParty(party, verbose)
    if verbose then
        self.output(string.format("AI arena party: %d character(s) at level %d.", #party.members, party.level))
        for index, member in ipairs(party.members) do
            self.output(string.format("  Recipient %d: %s [%s]", index, member.name or member.guid, member.guid))
        end
    end
    for _, level in ipairs(self.fixtures.levels()) do
        local fixture = self.fixtures.get(level)
        for _, member in ipairs(fixture.members) do
            local valid, reason = self.adapter.validateCharacterTemplate(member.templateId)
            if not valid then
                error(string.format("L%d fixture %s is invalid: %s", level, member.id, reason), 2)
            end
        end
        if verbose then
            self.output(string.format("  L%d fixture validated: %s", level, fixture.displayName))
        end
    end
    for _, item in ipairs(self.rewardCatalog) do
        local valid, reason = self.adapter.validateItemTemplate(item.templateId)
        if not valid then
            error(string.format("reward %s is invalid: %s", item.id, reason), 2)
        end
    end
    for _, item in ipairs(PreparationLoadout) do
        local valid, reason = self.adapter.validateItemTemplate(item.templateId)
        if not valid then
            error(string.format("preparation item %s is invalid: %s", item.displayName, reason), 2)
        end
    end
    if verbose then
        self.output(string.format("  Reward catalog validated: %d items.", #self.rewardCatalog))
        self.output(string.format("  Random preparation pools validated: %d audited candidates.", #PreparationLoadout))
    end
    return party
end

function SoloArena:doctor()
    return self:_validateParty(self:_party(), true)
end

local function preparePlayers(adapter, party)
    for _, member in ipairs(party.members) do
        adapter.prepareCharacter(member.guid)
    end
end

local function connectTeams(adapter, teams)
    for _, player in ipairs(teams.left.members) do
        for _, enemy in ipairs(teams.right.members) do
            adapter.makeHostile(player.guid, enemy.guid)
            adapter.enterCombat(player.guid, enemy.guid)
        end
    end
end

local function reconnectCombatant(adapter, member, opponents)
    for _, opponent in ipairs(opponents or {}) do
        adapter.makeHostile(member.guid, opponent.guid)
        adapter.enterCombat(member.guid, opponent.guid)
    end
end

local function createWaveMatch(run, teams, waveIndex)
    local match = Match.new({
        id = string.format("%s-bout-%d-wave-%d", run.id, run.battleIndex, waveIndex),
        leftEntrantId = teams.left.entrantId,
        rightEntrantId = teams.right.entrantId,
        level = run.level,
        maxPartySize = 4,
    })
    Match.setRoster(match, "left", guids(teams.left))
    Match.setRoster(match, "right", guids(teams.right))
    Match.setReady(match, "left", true)
    Match.setReady(match, "right", true)
    Match.beginPreparation(match)
    return match
end

function SoloArena:start(options)
    options = options or {}
    if self.active then
        error("an AI arena match is already active", 2)
    end
    if self.run and self.run.phase ~= "completed" then
        error("an AI arena run already exists; use status, continue, or reset", 2)
    end
    self:_requireOpenRun()
    local party = self:_party()
    local levels = progressionFrom(party.level)
    self:_requireArenaParty(party)
    if self.bootstrapState and self.bootstrapState.phase ~= "completed" then
        if self.bootstrapState.phase == "awaiting_level_up" then
            local recruited = self.campService and self.campService.recruitedCharacters
                and self.campService:recruitedCharacters()
                or nil
            ArenaBootstrap.confirmPartyLevel(self.bootstrapState, party.level, party.members, recruited)
        end
        if self.bootstrapState.phase ~= "ready" then
            error("arena bootstrap is incomplete; use !aa_ai_status or !aa_ai_reset", 2)
        end
        ArenaBootstrap.activate(self.bootstrapState)
    end
    self:_validateParty(party, false)
    self.generation = self.generation + 1
    self.run = SoloRun.new({
        id = "ai-run-" .. tostring(self.generation),
        partyId = "local-player-party",
        levels = levels,
    })
    self.recentOfferItemIds = {}
    self.preparationBundleDelivered = false
    SoloRun.confirmPartyLevel(self.run, party.level)
    return self:_startBout(party, options)
end

function SoloArena:_startBout(party, options)
    options = options or {}
    self.menu = nil
    local fixture = self.fixtures.forWave
        and self.fixtures.forWave(self.run.level, #party.members, 1)
        or self.fixtures.forPartySize
        and self.fixtures.forPartySize(self.run.level, #party.members)
        or self.fixtures.get(self.run.level)
    if not fixture then
        error("no AI fixture exists for level " .. tostring(self.run.level), 2)
    end
    SoloRun.assignOpponent(self.run, fixture)

    local record = self:_record()
    local preparation = { treasureRolls = 0, armoryItems = 0, revivifyScrolls = 0 }
    if not record.preparationDelivered and not self.preparationBundleDelivered
        and self.adapter.deliverPreparationBundle
    then
        -- Mark first: a crash halfway through delivery must never allow a
        -- reload to hand out a second full armory.
        self.preparationBundleDelivered = true
        RunRecord.markPreparationDelivered(record)
        self:_saveRecord(record)
        preparation = self.adapter.deliverPreparationBundle(
            party.members,
            self.run.level,
            self.rewardCatalog
        ) or preparation
        local supplyMessage = string.format(
            "Arena armory rolled: %d randomized personal gear pieces, %d level-%d supply rolls, and %d Scrolls of Revivify. Every character has weapon and armour choices plus a helmet, gloves, boots, amulet, and ring. Equip before confirming combat.",
            preparation.armoryItems or 0,
            preparation.treasureRolls or 0,
            self.run.level,
            preparation.revivifyScrolls or 0
        )
        self.output(supplyMessage)
        for _, member in ipairs(party.members) do
            self.adapter.notify(member.guid, supplyMessage)
        end
    end

    if self.autoKitService then
        -- Hirelings catch up on their class build and wear their best gear
        -- before every battle (after the armory and after each level-up).
        local kitOk, kitError = pcall(function()
            self.autoKitService:refresh(party.members)
        end)
        if not kitOk then
            self.output("WARNING: hireling auto-kit skipped: " .. tostring(kitError))
        end
    end

    local layout = self.arenaLayouts and self.arenaLayouts.select(
        self.run.id .. "-bout-" .. tostring(self.run.battleIndex) .. "-wave-1"
    ) or nil
    local site = self.arenaSites and (
        self.arenaSites.forLevel and self.arenaSites.forLevel(self.run.level)
        or self.arenaSites.forBout(self.run.battleIndex)
    ) or nil
    local setupOk, setupError = pcall(function()
        if site and self.adapter.prepareArenaSite then
            if record.stagingOrigin and self.adapter.setStagingOrigin then
                self.adapter.setStagingOrigin(record.stagingOrigin)
            end
            self.adapter.prepareArenaSite(party.members, site)
            if not record.stagingOrigin and self.adapter.stagingOrigin then
                local origin = self.adapter.stagingOrigin()
                if origin then
                    RunRecord.setStagingOrigin(record, origin)
                    self:_saveRecord(record)
                end
            end
        end
    end)
    if not setupOk then
        if self.adapter.returnPartyToStaging then
            self.adapter.returnPartyToStaging(party.members)
        end
        self.run.phase = "seeking_opponent"
        self.run.opponent = nil
        error("AI arena site setup failed and was rolled back: " .. tostring(setupError), 2)
    end
    local teams = {
        level = self.run.level,
        left = party,
        right = {
            entrantId = fixture.id,
            label = fixture.displayName,
            members = {},
        },
    }
    local waveCount = self.fixtures.waveCount and self.fixtures.waveCount(self.run.level) or 1

    self.active = {
        generation = self.generation,
        teams = teams,
        match = nil,
        fixture = fixture,
        defeated = {},
        dead = {},
        countdownRemaining = options.countdownSeconds ~= nil and countdown(options.countdownSeconds) or nil,
        layout = layout,
        site = site,
        waveIndex = 0,
        waveCount = math.max(1, waveCount),
        transitioning = false,
    }
    local ok, err = pcall(function()
        preparePlayers(self.adapter, party)
    end)
    if not ok then
        local active = self.active
        self.active = nil
        self:_cleanup(active)
        self.run.phase = "seeking_opponent"
        self.run.opponent = nil
        error("AI arena setup failed and was rolled back: " .. tostring(err), 2)
    end

    local boutIndex, boutCount = gauntletPosition(self.run.level)
    self.output(string.format(
        "Prepared AI bout %d/%d at L%d in %s: %d wave(s), with %d player(s) versus %d %s in wave 1%s.",
        boutIndex,
        boutCount,
        self.run.level,
        site and site.displayName or "the active arena",
        self.active.waveCount,
        #party.members,
        #fixture.members,
        fixture.displayName,
        layout and (" using " .. layout.displayName .. " formation") or ""
    ))
    if self.active.countdownRemaining == nil then
        self:_openWaveStartMenu(party.members, { isInitial = true, nextWave = 1 })
        local readyMessage = "Astral Arena is ready. Equip and position the whole party, then choose Yes on the ready prompt to begin wave 1."
        for _, member in ipairs(party.members) do
            self.adapter.notify(member.guid, readyMessage)
        end
    elseif self.active.countdownRemaining == 0 then
        self:_beginCombat(self.generation)
    else
        self:_countdown(self.generation, self.active.countdownRemaining)
    end
    return self.active and self.active.match or nil
end

function SoloArena:_countdown(generation, remaining)
    if not self.active or self.active.generation ~= generation then
        return
    end
    self.active.countdownRemaining = remaining
    local message = "AI arena begins in " .. tostring(remaining) .. "..."
    self.output(message)
    self.adapter.notify(self.active.teams.left.members[1].guid, message)
    self.adapter.schedule(1000, function()
        if not self.active or self.active.generation ~= generation then
            return
        end
        if remaining <= 1 then
            self:_beginCombat(generation)
        else
            self:_countdown(generation, remaining - 1)
        end
    end)
end

function SoloArena:_beginCombat(generation)
    if not self.active or self.active.generation ~= generation then
        return
    end
    local active = self.active
    local ok, err = pcall(function()
        local fixture = active.fixture
        local layout = active.layout
        local party = active.teams.left
        local spawned = self.adapter.spawnFixtureTeam(fixture, party.members[1].guid, layout)
        active.teams = {
            level = self.run.level,
            left = party,
            right = {
                entrantId = fixture.id,
                label = fixture.displayName,
                members = spawned,
            },
        }
        active.match = createWaveMatch(self.run, active.teams, 1)
        active.waveIndex = 1
        active.fixture = nil
        self:_persistCombat(active)
        connectTeams(self.adapter, active.teams)
        Match.beginCombat(active.match)
        SoloRun.beginCombat(self.run)
    end)
    if not ok then
        self.output("ERROR starting AI combat: " .. tostring(err))
        self:abort("combat-start-error")
        return
    end
    local message = string.format(
        "WAVE %d/%d — L%d Player Party versus %s",
        self.active.waveIndex,
        self.active.waveCount,
        self.run.level,
        self.active.teams.right.label
    )
    self.output(message)
    for _, member in ipairs(self.active.teams.left.members) do
        self.adapter.notify(member.guid, message)
    end
    self:_schedulePoll(generation)
end

local function isPollable(active)
    return active ~= nil
        and not active.transitioning
        and active.match ~= nil
        and active.match.phase == "combat"
end

function SoloArena:_schedulePoll(generation)
    local active = self.active
    if not active then
        return
    end
    -- One token per wave: a knockout resolved by an engine event, or a quick
    -- ready confirmation, can never leave two polling chains running.
    active.pollToken = (active.pollToken or 0) + 1
    local token = active.pollToken
    local function tick()
        self.adapter.schedule(250, function()
            local current = self.active
            if not current or current.generation ~= generation or current.pollToken ~= token then
                return
            end
            if not isPollable(current) then
                return
            end
            local ok, err = pcall(function()
                self:_poll()
            end)
            if not ok then
                self.output("ERROR while checking AI combat: " .. tostring(err))
                if self.active then
                    self:abort("poll-error")
                end
            elseif isPollable(self.active) and self.active.generation == generation and self.active.pollToken == token then
                tick()
            end
        end)
    end
    tick()
end

-- Resolve a wave the moment the engine reports a knockout instead of waiting
-- for the next poll. Ending a total party knockout inside the same engine
-- callback gives the arena cleanup a chance to run before BG3's own
-- party-wipe handling.
function SoloArena:_evaluateNow()
    if not isPollable(self.active) then
        return false
    end
    local ok, err = pcall(function()
        self:_poll()
    end)
    if not ok then
        self.output("ERROR while resolving an arena knockout: " .. tostring(err))
        if self.active then
            self:abort("poll-error")
        end
    end
    return true
end

function SoloArena:_poll()
    local alive = {}
    for _, side in ipairs({ "left", "right" }) do
        for _, member in ipairs(self.active.teams[side].members) do
            alive[member.guid] = self.adapter.isAlive(member.guid)
            local dead = self.adapter.isDead and self.adapter.isDead(member.guid) or false
            if dead and not self.active.dead[member.guid] then
                self.active.dead[member.guid] = true
                self.output((member.name or member.guid) .. " has died. Resurrection magic is required until the battle ends.")
            elseif not dead and self.active.dead[member.guid] then
                self.active.dead[member.guid] = nil
                self.output((member.name or member.guid) .. " has been resurrected.")
            end
            if not alive[member.guid] and not self.active.defeated[member.guid] then
                self.active.defeated[member.guid] = true
                self.adapter.markDefeated(member.guid)
                self.output((member.name or member.guid) .. " is down and making death saves.")
            elseif alive[member.guid] and self.active.defeated[member.guid] then
                self.active.defeated[member.guid] = nil
                if self.adapter.markRecovered then
                    self.adapter.markRecovered(member.guid)
                end
                local opponents = side == "left"
                    and self.active.teams.right.members
                    or self.active.teams.left.members
                reconnectCombatant(self.adapter, member, opponents)
                self.output((member.name or member.guid) .. " is back in the fight.")
            end
        end
    end
    local _, side = Match.evaluateAlive(self.active.match, alive)
    if self.active.match.phase == "completed" then
        if side == "left" and self.active.waveIndex < self.active.waveCount then
            self:_advanceWave()
        else
            self:_finish(side)
        end
    end
end

function SoloArena:onStatusApplied(guid, status)
    if status ~= "DOWNED" or not self.active then
        return false
    end
    for _, side in ipairs({ "left", "right" }) do
        for _, member in ipairs(self.active.teams[side].members) do
            if member.guid == guid then
                if not self.active.defeated[guid] then
                    self.active.defeated[guid] = true
                    self.adapter.markDefeated(guid)
                    self.output((member.name or guid) .. " is down and making death saves; further attacks can cause failures or death.")
                end
                self:_evaluateNow()
                return true
            end
        end
    end
    return false
end

function SoloArena:onDied(guid)
    if not self.active then
        return false
    end
    for _, side in ipairs({ "left", "right" }) do
        for _, member in ipairs(self.active.teams[side].members) do
            if member.guid == guid then
                self:_evaluateNow()
                return true
            end
        end
    end
    return false
end

function SoloArena:_cleanupBetweenWaves(active)
    local enemyFactions = factionSet(active.teams.right)
    for _, member in ipairs(active.teams.left.members) do
        if self.adapter.recoverBetweenWaves then
            self.adapter.recoverBetweenWaves(member, enemyFactions)
        else
            self.adapter.restoreCharacter(member, enemyFactions)
        end
    end
    for _, member in ipairs(active.teams.right.members) do
        self.adapter.deleteTemporary(member)
    end
    if self.adapter.restoreWaveResources then
        self.adapter.restoreWaveResources(active.teams.left.members)
    elseif self.adapter.fullRestParty then
        self.adapter.fullRestParty(active.teams.left.members)
    end
end

function SoloArena:_spawnNextWave(generation)
    local active = self.active
    if not active or active.generation ~= generation or not active.transitioning then
        return
    end

    local nextWave = active.waveIndex + 1
    local party = active.teams.left
    local fixture = self.fixtures.forWave
        and self.fixtures.forWave(self.run.level, #party.members, nextWave)
        or self.fixtures.forPartySize(self.run.level, #party.members)
    local layout = self.arenaLayouts and self.arenaLayouts.select(
        self.run.id .. "-bout-" .. tostring(self.run.battleIndex) .. "-wave-" .. tostring(nextWave)
    ) or nil

    local ok, err = pcall(function()
        local spawned = self.adapter.spawnFixtureTeam(fixture, party.members[1].guid, layout)
        active.teams = {
            level = self.run.level,
            left = party,
            right = {
                entrantId = fixture.id,
                label = fixture.displayName,
                members = spawned,
            },
        }
        active.match = createWaveMatch(self.run, active.teams, nextWave)
        active.defeated = {}
        active.dead = {}
        active.layout = layout
        active.waveIndex = nextWave
        active.fixture = nil
        self:_persistCombat(active)
        connectTeams(self.adapter, active.teams)
        Match.beginCombat(active.match)
    end)
    if not ok then
        self.output("ERROR preparing the next arena wave: " .. tostring(err))
        self:abort("wave-setup-error")
        return
    end

    active.transitioning = false
    local message = string.format(
        "WAVE %d/%d — L%d Player Party versus %s",
        active.waveIndex,
        active.waveCount,
        self.run.level,
        active.teams.right.label
    )
    self.output(message)
    for _, member in ipairs(party.members) do
        self.adapter.notify(member.guid, message)
    end
    self:_schedulePoll(generation)
end

function SoloArena:_advanceWave()
    local active = self.active
    active.transitioning = true
    self:_cleanupBetweenWaves(active)
    -- Keep an intermission marker in the save: a reload here must still
    -- resurrect fallen allies and restart the battle safely.
    local record = self:_record()
    if record.combat then
        record.combat.enemyGuids = {}
        self:_saveRecord(record)
    end
    local message = string.format(
        "Wave %d/%d cleared. Living allies are fully restored, including spell slots and class resources. Dead allies still require Revivify. Prepare for as long as needed, then confirm when wave %d should begin.",
        active.waveIndex,
        active.waveCount,
        active.waveIndex + 1
    )
    self.output(message)
    for _, member in ipairs(active.teams.left.members) do
        self.adapter.notify(member.guid, message)
    end
    self:_openWaveStartMenu(active.teams.left.members, {
        clearedWave = active.waveIndex,
        nextWave = active.waveIndex + 1,
    })
end

function SoloArena:_cleanup(active)
    local enemyFactions = factionSet(active.teams.right)
    for _, member in ipairs(active.teams.left.members) do
        self.adapter.restoreCharacter(member, enemyFactions)
    end
    for _, member in ipairs(active.teams.right.members) do
        self.adapter.deleteTemporary(member)
    end

    if self.adapter.returnPartyToStaging then
        self.adapter.returnPartyToStaging(active.teams.left.members)
    end
    if self.adapter.fullRestParty then
        self.adapter.fullRestParty(active.teams.left.members)
    end
end

function SoloArena:_printReward(offer)
    self.output(string.format("Victory reward (L%d): two RewardMedium rolls plus one choice:", offer.level))
    for index, choice in ipairs(offer.choices) do
        self.output(string.format("  %d. %s [%s]", index, choice.displayName, choice.rarity))
    end
    self.output("Use !aa_ai_pick <choice 1-6> <recipient number>.")
    for index, member in ipairs(self.rewardRecipients.members) do
        self.output(string.format("  Recipient %d: %s", index, member.name or member.guid))
    end
end

function SoloArena:_finish(resultSide)
    local active = self.active
    self.active = nil
    self:_cleanup(active)
    local result = resultSide == "left" and "win" or resultSide == "right" and "loss" or "draw"
    local opponentLabel = active.teams.right.label
    local level = self.run.level
    local battleIndex, battleCount = gauntletPosition(level)
    -- Survivors press on: any defeat or mutual knockout ends the run.
    SoloRun.recordResult(self.run, result == "win" and "win" or "loss")
    if result == "win" then
        self.rewardRecipients = active.teams.left
        local offer = SoloRun.createRewardOffer(self.run, self.rewardCatalog, {
            seed = self.run.pendingReward.id,
            recentOfferItemIds = self.recentOfferItemIds,
            treasureTableId = "RewardMedium",
        })
        local delivered = self.adapter.deliverVictoryBundle(offer, self.rewardRecipients.members)
        SoloRun.markAutomaticDelivered(self.run)
        local selected, targetLevel = SoloRun.claimReward(self.run, offer.choices[1].id)
        for _, offered in ipairs(offer.choices) do
            table.insert(self.recentOfferItemIds, offered.id)
        end
        self.menu = nil
        local record = self:_record()
        RunRecord.recordVictory(record, {
            level = level,
            battleIndex = battleIndex,
            opponent = opponentLabel,
            waves = active.waveCount,
        })
        if self.run.phase == "completed" then
            RunRecord.crown(record, {
                level = level,
                battleIndex = battleIndex,
                battleCount = battleCount,
                opponent = opponentLabel,
            })
            self:_saveRecord(record)
            self:_celebrateChampions(self.rewardRecipients.members, delivered)
            return selected
        end
        self:_saveRecord(record)
        self.adapter.awardPartyToLevel(self.rewardRecipients.members, targetLevel)
        self.output(string.format(
            "AI arena victory %d/%d. Delivered %d loot rolls and all %d rare candidates across the party; full-rest resources restored. Complete native level-ups to L%d for the next bout.",
            battleIndex,
            battleCount,
            delivered.treasureRolls or 0,
            delivered.rareItems or 0,
            targetLevel
        ))
        for _, member in ipairs(self.rewardRecipients.members) do
            self.adapter.notify(member.guid, string.format(
                "Victory %d/%d! Fully rested and loot delivered. Finish leveling to %d when your party is ready for the next battle.",
                battleIndex,
                battleCount,
                targetLevel
            ))
        end
        return selected
    end

    local record = self:_record()
    RunRecord.eliminate(record, {
        level = level,
        battleIndex = battleIndex,
        battleCount = battleCount,
        wave = active.waveIndex,
        waveCount = active.waveCount,
        opponent = opponentLabel,
        resolution = result == "draw" and "draw" or "defeat",
    })
    self:_saveRecord(record)
    self.menu = nil
    self.endingNoticeShown = true
    self:_announceElimination(active.teams.left.members, record)
    return nil
end

function SoloArena:_announceElimination(members, record)
    local summary = RunRecord.summary(record)
    local messages = {
        "YOUR PARTY HAS FALLEN — THE ASTRAL ARENA RUN IS OVER.",
        summary,
        "Only survivors press on. Start a New Game with Astral Arena Adventure to build a new party.",
    }
    self.output("=== ASTRAL ARENA: RUN OVER ===")
    self.output(summary)
    self.output("The party has been restored in staging, but no further battles will start in this Adventure.")
    for index, message in ipairs(messages) do
        self.adapter.schedule((index - 1) * 1800, function()
            for _, member in ipairs(members) do
                self.adapter.notify(member.guid, message)
            end
        end)
    end
    if self.adapter.openMessage then
        local owner = self:_menuOwner(members)
        if owner then
            local ok, err = pcall(function()
                self.adapter.openMessage(
                    owner,
                    Constants.MenuMessages.runOver,
                    "THE RUN IS OVER. " .. summary .. " Only survivors press on: start a New Game with Astral Arena Adventure to try again."
                )
            end)
            if not ok then
                self.output("WARNING: could not open the run-over message: " .. tostring(err))
            end
        end
    end
end

function SoloArena:_celebrateChampions(members, delivered)
    local messages = {
        "FINAL WAVE CLEARED — THE ASTRAL EXARCHS HAVE FALLEN!",
        "THE ASTRAL ARENA ERUPTS — YOUR PARTY ARE THE CHAMPIONS!",
        string.format(
            "Championship spoils delivered: %d loot rolls and %d rare items. The champions are fully rested.",
            delivered.treasureRolls or 0,
            delivered.rareItems or 0
        ),
    }
    self.output("=== ASTRAL ARENA CHAMPIONS ===")
    for index, message in ipairs(messages) do
        self.adapter.schedule((index - 1) * 1800, function()
            for _, member in ipairs(members) do
                self.adapter.notify(member.guid, message)
            end
        end)
    end
    self.output("The level-12 championship is complete. The party returns to staging with its final spoils and a full rest.")
    self.endingNoticeShown = true
    if self.adapter.openMessage then
        local owner = self:_menuOwner(members)
        if owner then
            pcall(function()
                self.adapter.openMessage(
                    owner,
                    Constants.MenuMessages.champion,
                    "ASTRAL ARENA CHAMPIONS! Your party survived every battle from level 3 to the level-12 championship."
                )
            end)
        end
    end
end

function SoloArena:pick(choiceIndex, recipientIndex)
    if not self.run or self.run.phase ~= "awaiting_reward" then
        error("there is no open AI arena reward", 2)
    end
    choiceIndex = tonumber(choiceIndex)
    recipientIndex = tonumber(recipientIndex) or 1
    local offer = self.run.pendingReward.offer
    local choice = choiceIndex and offer.choices[choiceIndex] or nil
    local recipient = self.rewardRecipients and self.rewardRecipients.members[recipientIndex] or nil
    if not choice then
        error("reward choice must be a number from 1 through 6", 2)
    end
    if not recipient then
        error("recipient number is not in the player party", 2)
    end
    local valid, reason = self.adapter.validateItemTemplate(choice.templateId)
    if not valid then
        error("selected reward failed validation: " .. tostring(reason), 2)
    end

    self.adapter.deliverAutomaticReward(offer, recipient.guid)
    SoloRun.markAutomaticDelivered(self.run)
    self.adapter.deliverItem(choice.templateId, recipient.guid)
    local selected, targetLevel = SoloRun.claimReward(self.run, choice.id)
    for _, offered in ipairs(offer.choices) do
        table.insert(self.recentOfferItemIds, offered.id)
    end
    self.menu = nil
    if self.run.phase == "completed" then
        self:_celebrateChampions(self.rewardRecipients.members, { treasureRolls = 1, rareItems = 1 })
        return selected
    end
    self.adapter.awardPartyToLevel(self.rewardRecipients.members, targetLevel)
    self.output(string.format(
        "%s received %s and the automatic bundle. Complete native level-ups to L%d; the next bout's ready prompt will appear automatically.",
        recipient.name or recipient.guid,
        selected.displayName,
        targetLevel
    ))
    return selected
end

function SoloArena:continue()
    if not self.run then
        error("no AI arena run exists; use !aa_ai_start", 2)
    end
    if self.active then
        error("the current AI arena match is still active", 2)
    end
    if self.run.phase == "seeking_opponent" then
        return self:_startBout(self:_party())
    end
    if self.run.phase ~= "awaiting_level_up" then
        error("AI arena is not waiting for level-up completion", 2)
    end
    local party = self:_party()
    SoloRun.confirmPartyLevel(self.run, party.level)
    return self:_startBout(party)
end

function SoloArena:_showEndingNotice(record)
    if self.endingNoticeShown then
        return
    end
    self.endingNoticeShown = true
    local summary = RunRecord.summary(record)
    self.output(summary)
    local ok, members = pcall(self.adapter.partyMembers)
    if not ok or type(members) ~= "table" then
        return
    end
    local tail = record.outcome == "champion"
        and " Start a New Game with Astral Arena Adventure for another run."
        or " This Adventure's run is over; start a New Game with Astral Arena Adventure to try again."
    for _, member in ipairs(members) do
        self.adapter.notify(member.guid, "Astral Arena: " .. summary .. tail)
    end
end

-- A save made during a wave or an intermission reloads with no live monitor.
-- Delete any surviving temporary enemies, restore the party in staging, and
-- restart the same battle from wave 1. This is not counted as a defeat.
function SoloArena:_recoverInterruptedCombat(record)
    local combat = record.combat
    local members = self.adapter.partyMembers()
    if type(members) ~= "table" or not members[1] then
        return false
    end
    if self.adapter.isPartyInArena and not self.adapter.isPartyInArena(members) then
        return false
    end
    local factions = {}
    for _, faction in ipairs(combat.enemyFactions or {}) do
        factions[faction] = true
    end
    for _, guid in ipairs(combat.enemyGuids or {}) do
        self.adapter.deleteTemporary({ guid = guid, temporary = true })
    end
    for _, member in ipairs(members) do
        self.adapter.restoreCharacter(member, factions)
    end
    if record.stagingOrigin and self.adapter.setStagingOrigin then
        self.adapter.setStagingOrigin(record.stagingOrigin)
    end
    if self.adapter.returnPartyToStaging then
        self.adapter.returnPartyToStaging(members)
    end
    if self.adapter.fullRestParty then
        self.adapter.fullRestParty(members)
    end
    RunRecord.clearCombat(record)
    self:_saveRecord(record)
    self.run = nil
    self.menu = nil
    local message = string.format(
        "A save from the middle of the level-%s battle (wave %s) was loaded. The unfinished battle was reset; the party is restored in staging and the battle restarts from wave 1.",
        tostring(combat.level or "?"),
        tostring(combat.wave or "?")
    )
    self.output(message)
    for _, member in ipairs(members) do
        self.adapter.notify(member.guid, message)
    end
    return true
end

function SoloArena:autoAdvance()
    if self.active then
        return "combat"
    end

    local record = self:_record()
    if RunRecord.isOver(record) then
        self:_showEndingNotice(record)
        return "completed"
    end
    if record.combat then
        if not self:_recoverInterruptedCombat(record) then
            return "outside"
        end
        return "recovered"
    end

    local ok, party = pcall(function()
        return self:_party()
    end)
    if not ok then
        -- Co-op players may finish level-up screens at different times. Mixed
        -- levels are a normal waiting state. Reapply only the missing XP so a
        -- split-screen avatar with independent progression ownership can catch up.
        return self:_repairMixedLevelParty() and "repairing" or "waiting"
    end
    if self.adapter.isPartyInArena and not self.adapter.isPartyInArena(party.members) then
        return "outside"
    end

    if self.campService and self.campService.ensureCamp then
        self.campService:ensureCamp(party.members)
    end

    if self.run then
        if self.run.phase == "completed" then
            return "completed"
        end
        if self.run.phase == "awaiting_level_up" and party.level == self.run.level then
            self:continue()
            return self.run.phase == "completed" and "completed" or "started"
        end
        if self.run.phase == "seeking_opponent" and party.level == self.run.level then
            -- After an abort or a rolled-back setup, offer the same battle
            -- again. The ready prompt still gates every enemy spawn.
            self.restartCooldown = (self.restartCooldown or 0) - 1
            if self.restartCooldown <= 0 then
                self.restartCooldown = 30
                self:_startBout(party)
                return "started"
            end
        end
        return "waiting"
    end

    if not self.bootstrapState then
        if party.level == 1 then
            self:bootstrapParty()
            return "bootstrapped"
        elseif party.level == 3 or party.level == 5 or party.level == 8 or party.level == 10 or party.level == 12 then
            if self.campService
                and self.campService:prepareOnboarding(party.members, party.level) ~= "ready"
            then
                return "camp"
            end
            self:start()
            return "started"
        end
        return "waiting"
    end

    if (self.bootstrapState.phase == "awaiting_level_up" or self.bootstrapState.phase == "completed")
        and party.level == self.bootstrapState.targetLevel then
        if self.campService
            and self.campService:prepareOnboarding(party.members, party.level) ~= "ready"
        then
            return "camp"
        end
        self:start()
        return "started"
    end
    return "waiting"
end

function SoloArena:abort(reason)
    if not self.active then
        error("there is no active AI arena match", 2)
    end
    local active = self.active
    if active.match and active.match.phase ~= "completed" and active.match.phase ~= "aborted" then
        Match.abort(active.match, reason or "manual-abort")
    end
    self.active = nil
    self:_cleanup(active)
    self.run.phase = "seeking_opponent"
    self.run.opponent = nil
    self.menu = nil
    local record = self:_record()
    if record.combat then
        RunRecord.clearCombat(record)
        self:_saveRecord(record)
    end
    -- An abort is a recovery tool, not a defeat. Re-offer the same battle
    -- after a short pause; enemies still wait for the ready prompt.
    self.restartCooldown = 10
    self.output("AI arena match aborted; player party restored and temporary enemies deleted. The same battle's ready prompt returns in about ten seconds.")
end

-- Developer escape hatch for a false elimination caused by an engine bug.
function SoloArena:overrideElimination()
    if self.active then
        error("an AI arena match is active", 2)
    end
    local record = self:_record()
    RunRecord.reopen(record)
    self:_saveRecord(record)
    self.run = nil
    self.bootstrapState = nil
    self.menu = nil
    self.endingNoticeShown = false
    self.restartCooldown = 0
    self.output("DEVELOPER OVERRIDE: the eliminated run was reopened. The current tier will be offered again. This is recorded in the run history.")
end

function SoloArena:reset()
    if self.active then
        self:abort("run-reset")
    end
    self.generation = self.generation + 1
    self.run = nil
    self.bootstrapState = nil
    self.rewardRecipients = nil
    self.recentOfferItemIds = {}
    self.repairNoticeTarget = nil
    self.menu = nil
    self.preparationBundleDelivered = false
    self.output("AI arena session state reset. Awarded XP and items are not removed; reload the pre-test save for a clean reset.")
end

function SoloArena:status()
    local record = self:_record()
    local summary = RunRecord.summary(record)
    if RunRecord.isOver(record) then
        return summary
    end
    if not self.run then
        if self.bootstrapState then
            return ArenaBootstrap.status(self.bootstrapState) .. " | " .. summary
        end
        return "No AI arena battle is prepared. | " .. summary
    end
    return SoloRun.status(self.run) .. " | " .. summary
end

return SoloArena
