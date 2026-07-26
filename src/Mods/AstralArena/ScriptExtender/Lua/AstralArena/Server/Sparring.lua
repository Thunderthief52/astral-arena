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

function Sparring.new(adapter, output)
    return setmetatable({
        adapter = adapter,
        output = output,
        active = nil,
        lastResult = nil,
        generation = 0,
    }, Sparring)
end

function Sparring:scan()
    local members = self.adapter.partyMembers()
    local groups = Roster.groupByUser(members)
    self.output(string.format("Found %d assigned multiplayer user(s).", #groups))
    for _, group in ipairs(groups) do
        self.output(string.format(
            "User %d controls %d: %s",
            group.userId,
            #group.members,
            memberNames(group)
        ))
        for _, member in ipairs(group.members) do
            self.output(string.format(
                "  L%d %s [%s]",
                member.level,
                member.name or "Unknown",
                member.guid
            ))
        end
    end
    return groups
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

function Sparring:startAuto()
    if self.active then
        error("a sparring match is already active; use !aa_abort first", 2)
    end

    local teams = Roster.autoTeams(self.adapter.partyMembers(), 4)
    local match = Match.new({
        id = "sparring-" .. tostring(self.generation + 1),
        leftEntrantId = "user-" .. tostring(teams.left.userId),
        rightEntrantId = "user-" .. tostring(teams.right.userId),
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
    }

    local setupOk, setupError = pcall(function()
        prepareGroups(self.adapter, teams)
        connectTeams(self.adapter, teams)
        Match.beginCombat(match)
    end)
    if not setupOk then
        local active = self.active
        self.active = nil
        self:_cleanup(active)
        error("match setup failed and was rolled back: " .. tostring(setupError), 2)
    end

    local announcement = string.format(
        "Astral Arena L%d: User %d (%s) versus User %d (%s)",
        teams.level,
        teams.left.userId,
        memberNames(teams.left),
        teams.right.userId,
        memberNames(teams.right)
    )
    self.output(announcement)
    self.adapter.notify(teams.left.members[1].guid, announcement)
    self.adapter.notify(teams.right.members[1].guid, announcement)
    self:_schedulePoll(self.generation)
    return match
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
            level = active.teams.level,
        }
    else
        result = {
            resolution = "draw",
            level = active.teams.level,
        }
    end

    self.active = nil
    self.lastResult = result
    self:_cleanup(active)

    local message
    if result.winnerUserId ~= nil then
        message = "Astral Arena winner: User " .. tostring(result.winnerUserId)
    else
        message = "Astral Arena result: draw"
    end
    self.output(message)
    self.adapter.notify(active.teams.left.members[1].guid, message)
    self.adapter.notify(active.teams.right.members[1].guid, message)
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
        return string.format(
            "Active L%d match: User %d versus User %d (%d defeated)",
            self.active.teams.level,
            self.active.teams.left.userId,
            self.active.teams.right.userId,
            defeatedCount
        )
    elseif self.lastResult then
        if self.lastResult.winnerUserId ~= nil then
            return "Last winner: User " .. tostring(self.lastResult.winnerUserId)
        end
        return "Last result: draw"
    end
    return "No sparring match has run this session."
end

return Sparring
