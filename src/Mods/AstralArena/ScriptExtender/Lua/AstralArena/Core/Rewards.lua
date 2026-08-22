local Util
if Ext and Ext.Require then
    Util = Ext.Require("AstralArena/Core/Util.lua")
else
    Util = require("AstralArena.Core.Util")
end

local Rewards = {}

local MODULUS = 2147483647
local MULTIPLIER = 48271

local RARITY = {
    common = { rank = 1, weight = 60 },
    uncommon = { rank = 2, weight = 32 },
    rare = { rank = 3, weight = 14 },
    veryrare = { rank = 4, weight = 5 },
    legendary = { rank = 5, weight = 1 },
}

local LEVEL_BANDS = {
    { id = "levels-1-4", minimumLevel = 1, maximumLevel = 4, minimumRarity = "uncommon", maximumRarity = "uncommon" },
    { id = "levels-5-8", minimumLevel = 5, maximumLevel = 8, minimumRarity = "uncommon", maximumRarity = "rare" },
    { id = "levels-9-10", minimumLevel = 9, maximumLevel = 10, minimumRarity = "rare", maximumRarity = "veryrare" },
    { id = "levels-11-12", minimumLevel = 11, maximumLevel = 12, minimumRarity = "rare", maximumRarity = "legendary" },
}

local POLICIES = {
    tournament = {
        automaticRolls = 2,
        choiceCount = 6,
        qualifyingResults = { win = true },
    },
    level_pool = {
        automaticRolls = 2,
        choiceCount = 6,
        qualifyingResults = { win = true, loss = true, draw = true },
    },
    sparring = {
        automaticRolls = 0,
        choiceCount = 0,
        qualifyingResults = {},
    },
}

local function normalizeRarity(rarity)
    if type(rarity) ~= "string" then
        return nil
    end
    return rarity:lower():gsub("[%s_%-]", "")
end

local function copyArray(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        table.insert(result, value)
    end
    return result
end

local function toSet(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        result[value] = true
    end
    return result
end

local function hashSeed(value)
    local hash = 216613626
    local text = tostring(value or "")
    for index = 1, #text do
        hash = (hash * 131 + text:byte(index)) % MODULUS
    end
    if hash == 0 then
        return 1
    end
    return hash
end

local function newRandom(seed)
    local state = hashSeed(seed)
    return function(maximum)
        state = (state * MULTIPLIER) % MODULUS
        if maximum == nil then
            return state / MODULUS
        end
        return (state % maximum) + 1
    end
end

local function levelBand(level)
    if type(level) ~= "number" or level < 1 or level > 12 or level % 1 ~= 0 then
        error("reward level must be an integer from 1 through 12", 3)
    end
    for _, band in ipairs(LEVEL_BANDS) do
        if level >= band.minimumLevel and level <= band.maximumLevel then
            return band
        end
    end
end

local function eligibleByRarity(item, band)
    local rarity = RARITY[normalizeRarity(item.rarity)]
    local minimum = RARITY[band.minimumRarity]
    local maximum = RARITY[band.maximumRarity]
    return rarity and rarity.rank >= minimum.rank and rarity.rank <= maximum.rank
end

local function isCatalogItemValid(item)
    return type(item) == "table"
        and type(item.id) == "string" and item.id ~= ""
        and type(item.templateId) == "string" and item.templateId ~= ""
        and type(item.category) == "string" and item.category ~= ""
        and RARITY[normalizeRarity(item.rarity)] ~= nil
end

local function filterCatalog(catalog, options, band, suppressRecent)
    local owned = toSet(options.ownedItemIds)
    local recent = toSet(options.recentOfferItemIds)
    local allowedCategories = options.allowedCategories and toSet(options.allowedCategories) or nil
    local eligible = {}

    for _, item in ipairs(catalog or {}) do
        local minimumLevel = item.minimumLevel or 1
        local maximumLevel = item.maximumLevel or 12
        local validLevelRange = type(minimumLevel) == "number"
            and type(maximumLevel) == "number"
            and minimumLevel >= 1
            and maximumLevel >= minimumLevel
        local valid = isCatalogItemValid(item)
            and not item.excluded
            and not item.storyItem
            and not item.debugOnly
            and not item.summonedOnly
            and item.pool ~= "automatic"
            and validLevelRange
            and options.level >= minimumLevel
            and options.level <= maximumLevel
            and eligibleByRarity(item, band)
            and not owned[item.id]
            and (not allowedCategories or allowedCategories[item.category])
            and (not suppressRecent or not recent[item.id])

        if valid then
            local stored = Util.copy(item)
            stored.rarity = normalizeRarity(stored.rarity)
            stored.weight = stored.weight or RARITY[stored.rarity].weight
            if type(stored.weight) == "number" and stored.weight > 0 then
                table.insert(eligible, stored)
            end
        end
    end

    table.sort(eligible, function(left, right)
        if left.id == right.id then
            return left.templateId < right.templateId
        end
        return left.id < right.id
    end)

    local candidates = {}
    local seenIds = {}
    local seenTemplates = {}
    for _, item in ipairs(eligible) do
        if not seenIds[item.id] and not seenTemplates[item.templateId] then
            table.insert(candidates, item)
            seenIds[item.id] = true
            seenTemplates[item.templateId] = true
        end
    end
    return candidates
end

local function candidatesForOffer(catalog, options, band)
    local preferred = filterCatalog(catalog, options, band, true)
    if #preferred >= options.choiceCount then
        return preferred
    end

    local result = preferred
    local selected = {}
    for _, item in ipairs(preferred) do
        selected[item.id] = true
    end
    for _, item in ipairs(filterCatalog(catalog, options, band, false)) do
        if not selected[item.id] then
            table.insert(result, item)
            selected[item.id] = true
        end
    end
    return result
end

local function withoutCategoryOverflow(candidates, categoryCounts, categoryLimit)
    local constrained = {}
    for _, item in ipairs(candidates) do
        if (categoryCounts[item.category] or 0) < categoryLimit then
            table.insert(constrained, item)
        end
    end
    if #constrained > 0 then
        return constrained
    end
    return candidates
end

local function weightedIndex(candidates, random)
    local total = 0
    for _, item in ipairs(candidates) do
        total = total + item.weight
    end
    local target = random() * total
    local cumulative = 0
    for index, item in ipairs(candidates) do
        cumulative = cumulative + item.weight
        if target < cumulative then
            return index
        end
    end
    return #candidates
end

local function removeCandidateAndUniqueGroup(candidates, selected)
    local result = {}
    for _, item in ipairs(candidates) do
        if item.id ~= selected.id
            and item.templateId ~= selected.templateId
            and (not selected.uniqueGroup or item.uniqueGroup ~= selected.uniqueGroup)
        then
            table.insert(result, item)
        end
    end
    return result
end

function Rewards.levelBand(level)
    return Util.copy(levelBand(level))
end

function Rewards.policy(mode, result, options)
    options = options or {}
    local policy = POLICIES[mode]
    if not policy then
        error("unknown reward mode: " .. tostring(mode), 2)
    end

    if mode == "sparring" and options.enableSparringRewards then
        policy = POLICIES.level_pool
    end

    return {
        enabled = policy.qualifyingResults[result] == true,
        automaticRolls = policy.automaticRolls,
        choiceCount = policy.choiceCount,
        mode = mode,
        result = result,
    }
end

function Rewards.createOffer(catalog, options)
    options = options or {}
    Util.assertNonEmptyString(options.id, "reward offer id")
    Util.assertNonEmptyString(options.recipientId, "reward recipient id")
    Util.assertNonEmptyString(options.mode, "reward mode")
    Util.assertNonEmptyString(options.result, "reward result")

    local policy = Rewards.policy(options.mode, options.result, {
        enableSparringRewards = options.enableSparringRewards,
    })
    if not policy.enabled then
        return nil
    end

    local band = levelBand(options.level)
    local choiceCount = options.choiceCount or policy.choiceCount
    if type(choiceCount) ~= "number" or choiceCount < 1 or choiceCount % 1 ~= 0 then
        error("choiceCount must be a positive integer", 2)
    end

    local selectionOptions = {
        level = options.level,
        choiceCount = choiceCount,
        ownedItemIds = copyArray(options.ownedItemIds),
        recentOfferItemIds = copyArray(options.recentOfferItemIds),
        allowedCategories = options.allowedCategories and copyArray(options.allowedCategories) or nil,
    }
    local candidates = candidatesForOffer(catalog, selectionOptions, band)
    if #candidates < choiceCount then
        error(string.format(
            "reward catalog has %d eligible choices; %d are required",
            #candidates,
            choiceCount
        ), 2)
    end

    local random = newRandom(options.seed or options.id)
    local categoryCounts = {}
    local choices = {}
    local categoryLimit = options.categoryLimit or 2
    if type(categoryLimit) ~= "number" or categoryLimit < 1 or categoryLimit % 1 ~= 0 then
        error("categoryLimit must be a positive integer", 2)
    end

    while #choices < choiceCount do
        local selectionPool = withoutCategoryOverflow(candidates, categoryCounts, categoryLimit)
        local selected = selectionPool[weightedIndex(selectionPool, random)]
        table.insert(choices, {
            id = selected.id,
            templateId = selected.templateId,
            displayName = selected.displayName or selected.id,
            rarity = selected.rarity,
            category = selected.category,
            modId = selected.modId,
            uniqueGroup = selected.uniqueGroup,
        })
        categoryCounts[selected.category] = (categoryCounts[selected.category] or 0) + 1
        candidates = removeCandidateAndUniqueGroup(candidates, selected)
        if #candidates == 0 and #choices < choiceCount then
            error("reward catalog cannot satisfy uniqueness constraints", 2)
        end
    end

    return {
        schemaVersion = 1,
        id = options.id,
        recipientId = options.recipientId,
        mode = options.mode,
        result = options.result,
        matchId = options.matchId,
        level = options.level,
        levelBandId = band.id,
        seed = tostring(options.seed or options.id),
        automatic = {
            status = "pending",
            rolls = policy.automaticRolls,
            levelBandId = band.id,
            treasureTableId = options.treasureTableId,
        },
        choices = choices,
        status = "open",
        selectedChoiceId = nil,
    }
end

function Rewards.claim(offer, choiceId)
    if type(offer) ~= "table" or offer.status ~= "open" then
        error("reward offer is not open", 2)
    end
    Util.assertNonEmptyString(choiceId, "reward choice id")

    local selected
    for _, choice in ipairs(offer.choices or {}) do
        if choice.id == choiceId then
            selected = choice
            break
        end
    end
    if not selected then
        error("reward choice is not part of this offer", 2)
    end

    offer.status = "claimed"
    offer.selectedChoiceId = selected.id
    return Util.copy(selected)
end

function Rewards.markAutomaticDelivered(offer)
    if type(offer) ~= "table" or type(offer.automatic) ~= "table" then
        error("reward offer has no automatic reward", 2)
    end
    if offer.automatic.status ~= "pending" then
        error("automatic reward is not pending", 2)
    end
    offer.automatic.status = "delivered"
    return offer.automatic
end

return Rewards
