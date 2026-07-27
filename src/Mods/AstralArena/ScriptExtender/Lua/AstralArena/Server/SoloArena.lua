local Match = Ext.Require("AstralArena/Core/Match.lua")
local Roster = Ext.Require("AstralArena/Core/Roster.lua")
local SoloRun = Ext.Require("AstralArena/Core/SoloRun.lua")
local ArenaBootstrap = Ext.Require("AstralArena/Core/ArenaBootstrap.lua")

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

function SoloArena.new(adapter, output, fixtures, rewardCatalog, arenaLayouts)
    return setmetatable({
        adapter = adapter,
        output = output,
        fixtures = fixtures,
        rewardCatalog = rewardCatalog,
        arenaLayouts = arenaLayouts,
        run = nil,
        bootstrapState = nil,
        active = nil,
        generation = 0,
        recentOfferItemIds = {},
        rewardRecipients = nil,
    }, SoloArena)
end

function SoloArena:bootstrapParty()
    if self.active or (self.run and self.run.phase ~= "completed") then
        error("an AI arena run is already in progress", 2)
    end
    if self.bootstrapState and self.bootstrapState.phase ~= "completed" then
        error("arena bootstrap has already started; finish leveling or use !aa_ai_reset", 2)
    end
    local party = self:_party()
    self.generation = self.generation + 1
    local state = ArenaBootstrap.new({
        id = "arena-bootstrap-" .. tostring(self.generation),
        targetLevel = 5,
    })
    local targetLevel = ArenaBootstrap.begin(state, party.level, #party.members)
    self.bootstrapState = state
    self.adapter.awardPartyToLevel(party.members, targetLevel)
    ArenaBootstrap.markExperienceAwarded(state)
    self.output(string.format(
        "Arena bootstrap awarded the level-5 XP threshold to %d character(s). Complete every native level-up, then use !aa_ai_start.",
        #party.members
    ))
    return state
end

function SoloArena:_party()
    return Roster.playerParty(self.adapter.partyMembers(), 4)
end

function SoloArena:doctor()
    local party = self:_party()
    self.output(string.format("AI arena party: %d character(s) at level %d.", #party.members, party.level))
    for index, member in ipairs(party.members) do
        self.output(string.format("  Recipient %d: %s [%s]", index, member.name or member.guid, member.guid))
    end
    for _, level in ipairs(self.fixtures.levels()) do
        local fixture = self.fixtures.get(level)
        for _, member in ipairs(fixture.members) do
            local valid, reason = self.adapter.validateCharacterTemplate(member.templateId)
            if not valid then
                error(string.format("L%d fixture %s is invalid: %s", level, member.id, reason), 2)
            end
        end
        self.output(string.format("  L%d fixture validated: %s", level, fixture.displayName))
    end
    for _, item in ipairs(self.rewardCatalog) do
        local valid, reason = self.adapter.validateItemTemplate(item.templateId)
        if not valid then
            error(string.format("reward %s is invalid: %s", item.id, reason), 2)
        end
    end
    self.output(string.format("  Reward catalog validated: %d items.", #self.rewardCatalog))
    return party
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

function SoloArena:start(options)
    options = options or {}
    if self.active then
        error("an AI arena match is already active", 2)
    end
    if self.run and self.run.phase ~= "completed" then
        error("an AI arena run already exists; use status, continue, or reset", 2)
    end
    local party = self:_party()
    if party.level ~= 5 then
        error("a new AI arena run requires a level 5 party", 2)
    end
    if self.bootstrapState and self.bootstrapState.phase ~= "completed" then
        if self.bootstrapState.phase == "awaiting_level_up" then
            ArenaBootstrap.confirmPartyLevel(self.bootstrapState, party.level, #party.members)
        end
        if self.bootstrapState.phase ~= "ready" then
            error("arena bootstrap is incomplete; use !aa_ai_status or !aa_ai_reset", 2)
        end
        ArenaBootstrap.activate(self.bootstrapState)
    end
    self.generation = self.generation + 1
    self.run = SoloRun.new({
        id = "ai-run-" .. tostring(self.generation),
        partyId = "local-player-party",
    })
    self.recentOfferItemIds = {}
    SoloRun.confirmPartyLevel(self.run, party.level)
    return self:_startBout(party, options)
end

function SoloArena:_startBout(party, options)
    options = options or {}
    local fixture = self.fixtures.get(self.run.level)
    if not fixture then
        error("no AI fixture exists for level " .. tostring(self.run.level), 2)
    end
    SoloRun.assignOpponent(self.run, fixture)

    local layout = self.arenaLayouts and self.arenaLayouts.select(
        self.run.id .. "-bout-" .. tostring(self.run.battleIndex)
    ) or nil
    local spawned = self.adapter.spawnFixtureTeam(fixture, party.members[1].guid, layout)
    local teams = {
        level = self.run.level,
        left = party,
        right = {
            entrantId = fixture.id,
            label = fixture.displayName,
            members = spawned,
        },
    }
    local match = Match.new({
        id = self.run.id .. "-bout-" .. tostring(self.run.battleIndex),
        leftEntrantId = party.entrantId,
        rightEntrantId = fixture.id,
        level = self.run.level,
        maxPartySize = 4,
    })
    Match.setRoster(match, "left", guids(teams.left))
    Match.setRoster(match, "right", guids(teams.right))
    Match.setReady(match, "left", true)
    Match.setReady(match, "right", true)
    Match.beginPreparation(match)

    self.active = {
        generation = self.generation,
        teams = teams,
        match = match,
        defeated = {},
        countdownRemaining = countdown(options.countdownSeconds),
        layout = layout,
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
        "Prepared AI bout %d/3 at L%d: Player Party versus %s%s.",
        self.run.battleIndex,
        self.run.level,
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
    self.output(string.format("FIGHT — L%d Player Party versus %s", self.run.level, self.active.teams.right.label))
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
            self:abort("poll-error")
        elseif self.active and self.active.generation == generation then
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
                self.output((member.name or member.guid) .. " is defeated.")
            end
        end
    end
    local _, side = Match.evaluateAlive(self.active.match, alive)
    if self.active.match.phase == "completed" then
        self:_finish(side)
    end
end

function SoloArena:_cleanup(active)
    local enemyFactions = factionSet(active.teams.right)
    for _, member in ipairs(active.teams.left.members) do
        self.adapter.restoreCharacter(member, enemyFactions)
    end
    for _, member in ipairs(active.teams.right.members) do
        self.adapter.deleteTemporary(member)
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
        self.output("AI arena victory.")
        self:_printReward(offer)
    elseif result == "loss" then
        self.output("AI arena run defeated. Reload the pre-test save or reset to try again.")
    else
        self.output("AI arena draw. Use !aa_ai_continue to replay this tier.")
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
    self.adapter.awardPartyToLevel(self.rewardRecipients.members, targetLevel)
    self.output(string.format(
        "%s received %s and the automatic bundle. Complete native level-ups to L%d, then use !aa_ai_continue.",
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
        return self.run
    end
    return self:_startBout(party)
end

function SoloArena:abort(reason)
    if not self.active then
        error("there is no active AI arena match", 2)
    end
    local active = self.active
    Match.abort(active.match, reason or "manual-abort")
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
    self.run = nil
    self.bootstrapState = nil
    self.rewardRecipients = nil
    self.recentOfferItemIds = {}
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
