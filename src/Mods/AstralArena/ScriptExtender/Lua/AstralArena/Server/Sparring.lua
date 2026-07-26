local Match = Ext.Require("AstralArena/Core/Match.lua")
local Roster = Ext.Require("AstralArena/Core/Roster.lua")

local Sparring = {}
Sparring.__index = Sparring

local function memberNames(group)
    local names = {}
    for _, member in ipairs(group.members) do
        table.insert(names, member.name or member.guid)
    end
    return table.concat(names, ", ")
end

local function factions(group)
    local values = {}
    for _, member in ipairs(group.members) do
        if member.faction and member.faction ~= "" then
            values[member.faction] = true
        end
    end
    return values
end

local function clampCountdown(value)
    value = tonumber(value) or 3
    return math.max(0, math.min(10, math.floor(value)))
end

function Sparring.new(adapter, output)
    return setmetatable({
        adapter = adapter,
        output = output,
        active = nil,
        lastResult = nil,
        generation = 0,
    }, Sparring)
end

function Sparring:scan(members)
    members = members or self.adapter.partyMembers()
    local groups = Roster.groupByUser(members)
    local avatars = Roster.avatarMembers(members)
    self.output(string.format("Found %d assigned multiplayer user(s).", #groups))
    for _, group in ipairs(groups) do
        self.output(string.format(
            "%s controls %d: %s",
            group.label,
            #group.members,
            memberNames(group)
        ))
        for _, member in ipairs(group.members) do
            local avatarSuffix = member.isAvatar
                and string.format("; player avatar user=%s", tostring(member.avatarUserId))
                or ""
            self.output(string.format(
                "  L%d %s [%s%s]",
                member.level,
                member.name or "Unknown",
                member.guid,
                avatarSuffix
            ))
        end
    end
    self.output(string.format("Detected %d player-avatar component(s).", #avatars))
    for index, member in ipairs(avatars) do
        self.output(string.format(
            "  Avatar %d: L%d %s [%s; avatar user=%s; reserved user=%s]",
            index,
            member.level,
            member.name or "Unknown",
            member.guid,
            tostring(member.avatarUserId),
            tostring(member.userId)
        ))
    end
    return members, groups, avatars
end

function Sparring:doctor()
    local members = self.adapter.partyMembers()
    self:scan(members)
    local teams = Roster.resolveTeams(members, 4)
    if teams.mode == "split-screen-avatars" then
        self.output(string.format(
            "READY via split-screen fallback: %s versus %s. %d non-avatar party member(s) will not fight.",
            memberNames(teams.left),
            memberNames(teams.right),
            teams.ignoredPartyMembers
        ))
    else
        self.output(string.format(
            "READY via multiplayer assignments: %s (%s) versus %s (%s).",
            teams.left.label,
            memberNames(teams.left),
            teams.right.label,
            memberNames(teams.right)
        ))
    end
    return teams
end

local function prepareGroups(adapter, teams)
    for _, side in ipairs({ "left", "right" }) do
        for _, member in ipairs(teams[side].members) do
            adapter.prepareCharacter(member.guid)
        end
    end
end

local function connectTeams(adapter, teams)
    for _, left in ipairs(teams.left.members) do
        for _, right in ipairs(teams.right.members) do
            adapter.makeHostile(left.guid, right.guid)
            adapter.enterCombat(left.guid, right.guid)
        end
    end
end

function Sparring:_notifyBoth(teams, message)
    self.adapter.notify(teams.left.members[1].guid, message)
    self.adapter.notify(teams.right.members[1].guid, message)
end

function Sparring:startAuto(options)
    options = options or {}
    if self.active then
        error("a sparring match is already active; use !aa_abort first", 2)
    end

    local teams = Roster.resolveTeams(self.adapter.partyMembers(), 4)
    local match = Match.new({
        id = "sparring-" .. tostring(self.generation + 1),
        leftEntrantId = teams.left.entrantId,
        rightEntrantId = teams.right.entrantId,
        level = teams.level,
        maxPartySize = 4,
    })
    Match.setRoster(match, "left", Roster.guids(teams.left))
    Match.setRoster(match, "right", Roster.guids(teams.right))
    Match.setReady(match, "left", true)
    Match.setReady(match, "right", true)
    Match.beginPreparation(match)

    self.generation = self.generation + 1
    self.active = {
        generation = self.generation,
        teams = teams,
        match = match,
        defeated = {},
        countdownRemaining = clampCountdown(options.countdownSeconds),
    }

    local setupOk, setupError = pcall(function()
        prepareGroups(self.adapter, teams)
    end)
    if not setupOk then
        local active = self.active
        self.active = nil
        self:_cleanup(active)
        error("match setup failed and was rolled back: " .. tostring(setupError), 2)
    end

    if teams.mode == "split-screen-avatars" then
        self.output(string.format(
            "Using split-screen avatar fallback; %d non-avatar party member(s) are spectators.",
            teams.ignoredPartyMembers
        ))
    end
    self.output(string.format(
        "Prepared L%d: %s (%s) versus %s (%s).",
        teams.level,
        teams.left.label,
        memberNames(teams.left),
        teams.right.label,
        memberNames(teams.right)
    ))

    if self.active.countdownRemaining == 0 then
        self:_beginCombat(self.generation)
    else
        self:_countdown(self.generation, self.active.countdownRemaining)
    end
    return match
end

function Sparring:rematch(options)
    if self.active then
        error("a sparring match is already active; use !aa_abort first", 2)
    end
    if not self.lastResult then
        error("there is no completed match to replay; use !aa_spar", 2)
    end
    return self:startAuto(options)
end

function Sparring:_countdown(generation, remaining)
    if not self.active or self.active.generation ~= generation then
        return
    end
    self.active.countdownRemaining = remaining
    local message = "Astral Arena begins in " .. tostring(remaining) .. "..."
    self.output(message)
    self:_notifyBoth(self.active.teams, message)
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

function Sparring:_beginCombat(generation)
    if not self.active or self.active.generation ~= generation then
        return
    end
    local active = self.active
    local combatOk, combatError = pcall(function()
        connectTeams(self.adapter, active.teams)
        Match.beginCombat(active.match)
    end)
    if not combatOk then
        self.output("ERROR starting combat: " .. tostring(combatError))
        self:abort("combat-start-error")
        return
    end

    local announcement = string.format(
        "FIGHT — L%d %s (%s) versus %s (%s)",
        active.teams.level,
        active.teams.left.label,
        memberNames(active.teams.left),
        active.teams.right.label,
        memberNames(active.teams.right)
    )
    self.output(announcement)
    self:_notifyBoth(active.teams, announcement)
    self:_schedulePoll(generation)
end

function Sparring:_schedulePoll(generation)
    self.adapter.schedule(250, function()
        if not self.active or self.active.generation ~= generation then
            return
        end
        local ok, err = pcall(function()
            self:_poll()
        end)
        if not ok then
            self.output("ERROR while checking combat: " .. tostring(err))
            self:abort("poll-error")
        elseif self.active and self.active.generation == generation then
            self:_schedulePoll(generation)
        end
    end)
end

function Sparring:_poll()
    local alive = {}
    for _, side in ipairs({ "left", "right" }) do
        for _, member in ipairs(self.active.teams[side].members) do
            local isAlive = self.adapter.isAlive(member.guid)
            alive[member.guid] = isAlive
            if not isAlive and not self.active.defeated[member.guid] then
                self.active.defeated[member.guid] = true
                self.adapter.markDefeated(member.guid)
                self.output((member.name or member.guid) .. " is defeated.")
            end
        end
    end

    local _, resultSide = Match.evaluateAlive(self.active.match, alive)
    if self.active.match.phase == "completed" then
        self:_finish(resultSide)
    end
end

function Sparring:_cleanup(active)
    local leftFactions = factions(active.teams.left)
    local rightFactions = factions(active.teams.right)
    for _, member in ipairs(active.teams.left.members) do
        self.adapter.restoreCharacter(member, rightFactions)
    end
    for _, member in ipairs(active.teams.right.members) do
        self.adapter.restoreCharacter(member, leftFactions)
    end
end

function Sparring:_finish(resultSide)
    local active = self.active
    local result
    if resultSide == "left" or resultSide == "right" then
        local winners = active.teams[resultSide]
        result = {
            resolution = "defeat",
            winnerSide = resultSide,
            winnerUserId = winners.userId,
            winnerLabel = winners.label,
            level = active.teams.level,
            mode = active.teams.mode,
        }
    else
        result = {
            resolution = "draw",
            level = active.teams.level,
            mode = active.teams.mode,
        }
    end

    self.active = nil
    self.lastResult = result
    self:_cleanup(active)

    local message
    if result.winnerLabel then
        message = "Astral Arena winner: " .. result.winnerLabel
    else
        message = "Astral Arena result: draw"
    end
    self.output(message)
    self:_notifyBoth(active.teams, message)
    return result
end

function Sparring:forfeit(side)
    if not self.active then
        error("there is no active sparring match", 2)
    end
    if side ~= "left" and side ~= "right" then
        error("side must be 'left' or 'right'", 2)
    end
    Match.forfeit(self.active.match, side)
    return self:_finish(side == "left" and "right" or "left")
end

function Sparring:abort(reason)
    if not self.active then
        error("there is no active sparring match", 2)
    end
    local active = self.active
    Match.abort(active.match, reason or "manual-abort")
    self.active = nil
    self:_cleanup(active)
    self.output("Sparring match aborted and characters restored.")
end

function Sparring:status()
    if self.active then
        local defeatedCount = 0
        for _ in pairs(self.active.defeated) do
            defeatedCount = defeatedCount + 1
        end
        if self.active.match.phase == "preparation" then
            return string.format(
                "Preparing L%d %s versus %s (countdown %d)",
                self.active.teams.level,
                self.active.teams.left.label,
                self.active.teams.right.label,
                self.active.countdownRemaining
            )
        end
        return string.format(
            "Active L%d match: %s versus %s (%d defeated)",
            self.active.teams.level,
            self.active.teams.left.label,
            self.active.teams.right.label,
            defeatedCount
        )
    elseif self.lastResult then
        if self.lastResult.winnerLabel then
            return "Last winner: " .. self.lastResult.winnerLabel
        end
        return "Last result: draw"
    end
    return "No sparring match has run this session."
end

return Sparring
