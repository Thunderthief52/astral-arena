local Util
local Rewards
if Ext and Ext.Require then
    Util = Ext.Require("AstralArena/Core/Util.lua")
    Rewards = Ext.Require("AstralArena/Core/Rewards.lua")
else
    Util = require("AstralArena.Core.Util")
    Rewards = require("AstralArena.Core.Rewards")
end

local SoloRun = {}

local DEFAULT_LEVELS = { 5, 8, 10, 12 }

local function assertPhase(run, wanted)
    if run.phase ~= wanted then
        error(string.format("solo run must be in %s phase, not %s", wanted, tostring(run.phase)), 3)
    end
end

local function battleCount(run)
    return #run.levels - 1
end

function SoloRun.new(options)
    options = options or {}
    Util.assertNonEmptyString(options.id, "solo run id")
    Util.assertNonEmptyString(options.partyId, "solo party id")
    local levels = Util.copy(options.levels or DEFAULT_LEVELS)
    if #levels < 2 then
        error("solo run needs at least one combat level and one reward level", 2)
    end
    for index, level in ipairs(levels) do
        if type(level) ~= "number" or level < 1 or level > 12 or level % 1 ~= 0 then
            error("solo run levels must be integers from 1 through 12", 2)
        end
        if index > 1 and level <= levels[index - 1] then
            error("solo run levels must increase", 2)
        end
    end

    return {
        schemaVersion = 1,
        id = options.id,
        partyId = options.partyId,
        levels = levels,
        battleIndex = 1,
        level = levels[1],
        phase = "awaiting_party",
        opponent = nil,
        bouts = {},
        pendingReward = nil,
        completion = nil,
    }
end

function SoloRun.confirmPartyLevel(run, level)
    if run.phase ~= "awaiting_party" and run.phase ~= "awaiting_level_up" then
        error("solo run is not waiting for party level confirmation", 2)
    end
    if level ~= run.level then
        error(string.format("party must be level %d", run.level), 2)
    end

    if run.battleIndex > battleCount(run) then
        run.phase = "completed"
        run.completion = "champion"
    else
        run.phase = "seeking_opponent"
    end
    return run.phase
end

function SoloRun.assignOpponent(run, fixture)
    assertPhase(run, "seeking_opponent")
    if type(fixture) ~= "table" then
        error("AI fixture must be a table", 2)
    end
    Util.assertNonEmptyString(fixture.id, "AI fixture id")
    if fixture.level ~= run.level then
        error(string.format("AI fixture must be level %d", run.level), 2)
    end
    if type(fixture.members) ~= "table" or #fixture.members < 1 or #fixture.members > 4 then
        error("AI fixture must contain one to four members", 2)
    end
    run.opponent = {
        id = fixture.id,
        displayName = fixture.displayName or fixture.id,
        level = fixture.level,
    }
    run.phase = "ready"
end

function SoloRun.beginCombat(run)
    assertPhase(run, "ready")
    run.phase = "combat"
end

function SoloRun.recordResult(run, result)
    assertPhase(run, "combat")
    if result ~= "win" and result ~= "loss" and result ~= "draw" then
        error("solo result must be win, loss, or draw", 2)
    end

    local bout = {
        index = run.battleIndex,
        matchLevel = run.level,
        rewardLevel = run.levels[run.battleIndex + 1],
        opponentId = run.opponent.id,
        result = result,
    }
    table.insert(run.bouts, bout)
    run.opponent = nil

    if result == "loss" then
        run.phase = "completed"
        run.completion = "defeated"
    elseif result == "draw" then
        run.phase = "seeking_opponent"
    else
        run.pendingReward = {
            id = string.format("%s-bout-%d", run.id, run.battleIndex),
            matchLevel = bout.matchLevel,
            rewardLevel = bout.rewardLevel,
            status = "awaiting_offer",
            offer = nil,
        }
        run.phase = "awaiting_reward"
    end
    return bout
end

function SoloRun.retryDefeat(run)
    if run.phase ~= "completed" or run.completion ~= "defeated" then
        error("solo run is not waiting for a defeat retry", 2)
    end
    run.phase = "seeking_opponent"
    run.completion = nil
    run.opponent = nil
    run.pendingReward = nil
    return run.phase
end

function SoloRun.createRewardOffer(run, catalog, options)
    assertPhase(run, "awaiting_reward")
    options = options or {}
    if run.pendingReward.status ~= "awaiting_offer" then
        error("reward offer has already been created", 2)
    end
    local context = run.pendingReward
    local offer = Rewards.createOffer(catalog, {
        id = context.id,
        recipientId = run.partyId,
        mode = "tournament",
        result = "win",
        matchId = "solo-" .. tostring(run.battleIndex),
        level = context.rewardLevel,
        seed = options.seed or context.id,
        ownedItemIds = options.ownedItemIds,
        recentOfferItemIds = options.recentOfferItemIds,
        treasureTableId = options.treasureTableId,
    })
    context.offer = offer
    context.status = "open"
    return offer
end

function SoloRun.markAutomaticDelivered(run)
    assertPhase(run, "awaiting_reward")
    if not run.pendingReward.offer then
        error("reward offer has not been created", 2)
    end
    return Rewards.markAutomaticDelivered(run.pendingReward.offer)
end

function SoloRun.claimReward(run, choiceId)
    assertPhase(run, "awaiting_reward")
    local pending = run.pendingReward
    if not pending.offer then
        error("reward offer has not been created", 2)
    end
    if pending.offer.automatic.status ~= "delivered" then
        error("automatic reward must be delivered before claiming equipment", 2)
    end
    local selected = Rewards.claim(pending.offer, choiceId)
    pending.status = "claimed"
    run.battleIndex = run.battleIndex + 1
    run.level = run.levels[run.battleIndex]
    run.phase = "awaiting_level_up"
    return selected, run.level
end

function SoloRun.status(run)
    if run.phase == "completed" then
        return string.format("Solo run %s: %s after %d bout(s)", run.id, run.completion, #run.bouts)
    end
    return string.format(
        "Solo run %s: L%d, stage %d/%d, %s",
        run.id,
        run.level,
        math.min(run.battleIndex, battleCount(run)),
        battleCount(run),
        run.phase
    )
end

return SoloRun
