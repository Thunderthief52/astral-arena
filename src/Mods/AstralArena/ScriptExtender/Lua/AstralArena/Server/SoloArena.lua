local Match = Ext.Require("AstralArena/Core/Match.lua")
local Roster = Ext.Require("AstralArena/Core/Roster.lua")
local SoloRun = Ext.Require("AstralArena/Core/SoloRun.lua")
local ArenaBootstrap = Ext.Require("AstralArena/Core/ArenaBootstrap.lua")
local Constants = Ext.Require("AstralArena/Shared/Constants.lua")

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
    return math.max(0, math.min(10, math.floor(value)))
end

function SoloArena.new(adapter, output, fixtures, rewardCatalog, arenaLayouts, arenaSites)
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
    if #result < 2 then
        error("an AI arena run requires a party at level 3, 5, 8, or 10", 3)
    end
    return result
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
    if menu.kind == "defeat" then
        key = Constants.MenuMessages.defeat
        message = string.format(
            "Astral Arena defeat at level %d. Retry this bout now? Choose No to remain safely in staging.",
            self.run and self.run.level or 5
        )
    elseif menu.kind == "draw" then
        key = Constants.MenuMessages.draw
        message = string.format(
            "The level %d bout ended in a draw. Replay this bout now? Choose No to remain safely in staging.",
            self.run and self.run.level or 5
        )
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
    if not menu or characterGuid ~= menu.ownerGuid or messageKey ~= menu.messageKey then
        return false
    end

    local accepted = menuResultIsYes(result)
    if menu.kind == "defeat" or menu.kind == "draw" then
        if accepted then
            if menu.kind == "defeat" then
                SoloRun.retryDefeat(self.run)
            end
            self.menu = nil
            self:_startBout(self:_party())
        else
            menu.dismissed = true
            self.output("Arena bout paused in staging by player choice. Use !aa_ai_menu to reopen the arena prompt.")
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

function SoloArena:bootstrapParty()
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
    local targetLevel = ArenaBootstrap.begin(state, party.level, #party.members)
    self.bootstrapState = state
    self.adapter.awardPartyToLevel(party.members, targetLevel)
    ArenaBootstrap.markExperienceAwarded(state)
    self.output(string.format(
        "Arena bootstrap awarded the level-3 XP threshold to %d character(s). Complete every native level-up; the initiation bout will begin automatically.",
        #party.members
    ))
    for _, member in ipairs(party.members) do
        self.adapter.notify(member.guid, "Astral Arena: finish leveling to 3. The initiation bout will begin automatically.")
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
    if verbose then
        self.output(string.format("  Reward catalog validated: %d items.", #self.rewardCatalog))
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
    local party = self:_party()
    local levels = progressionFrom(party.level)
    self:_requireArenaParty(party)
    if self.bootstrapState and self.bootstrapState.phase ~= "completed" then
        if self.bootstrapState.phase == "awaiting_level_up" then
            ArenaBootstrap.confirmPartyLevel(self.bootstrapState, party.level, #party.members)
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

    local layout = self.arenaLayouts and self.arenaLayouts.select(
        self.run.id .. "-bout-" .. tostring(self.run.battleIndex) .. "-wave-1"
    ) or nil
    local site = self.arenaSites and (
        self.arenaSites.forLevel and self.arenaSites.forLevel(self.run.level)
        or self.arenaSites.forBout(self.run.battleIndex)
    ) or nil
    local spawned = nil
    local setupOk, setupError = pcall(function()
        if site and self.adapter.prepareArenaSite then
            self.adapter.prepareArenaSite(party.members, site)
        end
        spawned = self.adapter.spawnFixtureTeam(fixture, party.members[1].guid, layout)
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
            members = spawned,
        },
    }
    local match = createWaveMatch(self.run, teams, 1)
    local waveCount = self.fixtures.waveCount and self.fixtures.waveCount(self.run.level) or 1

    self.active = {
        generation = self.generation,
        teams = teams,
        match = match,
        defeated = {},
        countdownRemaining = countdown(options.countdownSeconds),
        layout = layout,
        site = site,
        waveIndex = 1,
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

    self.output(string.format(
        "Prepared AI bout %d/%d at L%d in %s: %d wave(s), with %d player(s) versus %d %s in wave 1%s.",
        self.run.battleIndex,
        #self.run.levels - 1,
        self.run.level,
        site and site.displayName or "the active arena",
        self.active.waveCount,
        #party.members,
        #spawned,
        fixture.displayName,
        layout and (" using " .. layout.displayName .. " formation") or ""
    ))
    if self.active.countdownRemaining == 0 then
        self:_beginCombat(self.generation)
    else
        self:_countdown(self.generation, self.active.countdownRemaining)
    end
    return match
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
    local ok, err = pcall(function()
        connectTeams(self.adapter, self.active.teams)
        Match.beginCombat(self.active.match)
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

function SoloArena:_schedulePoll(generation)
    self.adapter.schedule(250, function()
        if not self.active or self.active.generation ~= generation then
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
        elseif self.active and self.active.generation == generation and not self.active.transitioning then
            self:_schedulePoll(generation)
        end
    end)
end

function SoloArena:_poll()
    local alive = {}
    for _, side in ipairs({ "left", "right" }) do
        for _, member in ipairs(self.active.teams[side].members) do
            alive[member.guid] = self.adapter.isAlive(member.guid)
            if not alive[member.guid] and not self.active.defeated[member.guid] then
                self.active.defeated[member.guid] = true
                self.adapter.markDefeated(member.guid)
                self.output((member.name or member.guid) .. " is down and making death saves.")
            elseif alive[member.guid] and self.active.defeated[member.guid] then
                self.active.defeated[member.guid] = nil
                if self.adapter.markRecovered then
                    self.adapter.markRecovered(member.guid)
                end
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
        active.layout = layout
        active.waveIndex = nextWave
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
    local message = string.format(
        "Wave %d/%d cleared. Downed allies recovered at partial health; no long rest yet. Wave %d arrives in 3 seconds.",
        active.waveIndex,
        active.waveCount,
        active.waveIndex + 1
    )
    self.output(message)
    for _, member in ipairs(active.teams.left.members) do
        self.adapter.notify(member.guid, message)
    end
    local generation = active.generation
    self.adapter.schedule(3000, function()
        self:_spawnNextWave(generation)
    end)
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
    SoloRun.recordResult(self.run, result)
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
        self.adapter.awardPartyToLevel(self.rewardRecipients.members, targetLevel)
        self.menu = nil
        self.output(string.format(
            "AI arena victory. Delivered %d loot rolls and all %d rare candidates across the party; full-rest resources restored. Complete native level-ups to L%d for the next bout.",
            delivered.treasureRolls or 0,
            delivered.rareItems or 0,
            targetLevel
        ))
        for _, member in ipairs(self.rewardRecipients.members) do
            self.adapter.notify(member.guid, string.format(
                "Victory! Party fully rested; loot delivered. Finish leveling to %d for the next bout.",
                targetLevel
            ))
        end
        return selected
    elseif result == "loss" then
        SoloRun.retryDefeat(self.run)
        self.output("Arena defeat. Party fully rested; the same bout will restart automatically in staging.")
    else
        self.output("Arena draw. Party fully rested; the same bout will restart automatically in staging.")
    end
    local generation = self.generation
    for _, member in ipairs(active.teams.left.members) do
        self.adapter.notify(member.guid, "Arena rematch begins in 5 seconds.")
    end
    self.adapter.schedule(5000, function()
        if self.generation ~= generation or self.active or not self.run or self.run.phase ~= "seeking_opponent" then
            return
        end
        local ok, err = pcall(function()
            self:_startBout(self:_party())
        end)
        if not ok then
            self.output("ERROR restarting arena bout: " .. tostring(err))
        end
    end)
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
    self.adapter.awardPartyToLevel(self.rewardRecipients.members, targetLevel)
    self.menu = nil
    self.output(string.format(
        "%s received %s and the automatic bundle. Complete native level-ups to L%d; the next bout will begin automatically.",
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
    if self.run.phase == "completed" then
        self.output("Astral Arena champion complete at level 12.")
        for _, member in ipairs(party.members) do
            self.adapter.notify(member.guid, "Astral Arena complete: your party is champion at level 12.")
        end
        return self.run
    end
    return self:_startBout(party)
end

function SoloArena:autoAdvance()
    if self.active then
        return "combat"
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

    if self.run then
        if self.run.phase == "completed" then
            return "completed"
        end
        if self.run.phase == "awaiting_level_up" and party.level == self.run.level then
            self:continue()
            return self.run.phase == "completed" and "completed" or "started"
        end
        return "waiting"
    end

    if not self.bootstrapState then
        if party.level == 1 then
            self:bootstrapParty()
            return "bootstrapped"
        elseif party.level == 3 or party.level == 5 or party.level == 8 or party.level == 10 then
            self:start()
            return "started"
        elseif party.level == 12 then
            return "completed"
        end
        return "waiting"
    end

    if (self.bootstrapState.phase == "awaiting_level_up" or self.bootstrapState.phase == "completed")
        and party.level == self.bootstrapState.targetLevel then
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
    if active.match.phase ~= "completed" and active.match.phase ~= "aborted" then
        Match.abort(active.match, reason or "manual-abort")
    end
    self.active = nil
    self:_cleanup(active)
    self.run.phase = "seeking_opponent"
    self.run.opponent = nil
    self.output("AI arena match aborted; player party restored and temporary enemies deleted.")
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
    self.output("AI arena session state reset. Awarded XP and items are not removed; reload the pre-test save for a clean reset.")
end

function SoloArena:status()
    if not self.run then
        if self.bootstrapState then
            return ArenaBootstrap.status(self.bootstrapState)
        end
        return "No AI arena run exists."
    end
    return SoloRun.status(self.run)
end

return SoloArena
