local H = require("tests.test_helper")
local Rewards = require("AstralArena.Core.Rewards")

local function catalog()
    local result = {}
    local rarities = { "Uncommon", "Rare", "Very Rare", "Legendary" }
    local categories = { "weapon", "armor", "jewelry", "utility" }
    for index = 1, 20 do
        local rarity = rarities[((index - 1) % #rarities) + 1]
        table.insert(result, {
            id = string.format("item-%02d", index),
            templateId = string.format("template-%02d", index),
            displayName = string.format("Item %02d", index),
            rarity = rarity,
            category = categories[((index - 1) % #categories) + 1],
            minimumLevel = rarity == "Uncommon" and 1 or 5,
            maximumLevel = 12,
        })
    end
    return result
end

local function offer(options, items)
    options = options or {}
    options.id = options.id or "offer-1"
    options.recipientId = options.recipientId or "party-1"
    options.mode = options.mode or "tournament"
    options.result = options.result or "win"
    options.level = options.level or 8
    options.seed = options.seed or "stable-seed"
    return Rewards.createOffer(items or catalog(), options)
end

local function choiceIds(value)
    local result = {}
    for _, choice in ipairs(value.choices) do
        table.insert(result, choice.id)
    end
    return table.concat(result, ",")
end

H.test("the same reward seed produces the same six choices", function()
    local first = offer()
    local second = offer()
    H.equal(#first.choices, 6)
    H.equal(choiceIds(first), choiceIds(second))
end)

H.test("catalog input order does not change a seeded offer", function()
    local forward = catalog()
    local reverse = {}
    for index = #forward, 1, -1 do
        table.insert(reverse, forward[index])
    end
    H.equal(choiceIds(offer(nil, forward)), choiceIds(offer(nil, reverse)))
end)

H.test("reward choices obey level rarity bands", function()
    local earlyItems = {}
    for index = 1, 8 do
        table.insert(earlyItems, {
            id = "uncommon-" .. index,
            templateId = "template-u-" .. index,
            rarity = "Uncommon",
            category = "category-" .. index,
        })
    end
    table.insert(earlyItems, {
        id = "legendary-too-early",
        templateId = "template-legendary",
        rarity = "Legendary",
        category = "weapon",
    })

    local result = offer({ level = 4 }, earlyItems)
    for _, choice in ipairs(result.choices) do
        H.equal(choice.rarity, "uncommon")
    end
end)

H.test("story debug summoned and explicitly excluded items never enter offers", function()
    local items = {}
    local unsafeFlags = { "storyItem", "debugOnly", "summonedOnly", "excluded" }
    for index, flag in ipairs(unsafeFlags) do
        local item = {
            id = "unsafe-" .. index,
            templateId = "unsafe-template-" .. index,
            rarity = "Rare",
            category = "weapon",
        }
        item[flag] = true
        table.insert(items, item)
    end
    for index = 1, 8 do
        table.insert(items, {
            id = "safe-" .. index,
            templateId = "safe-template-" .. index,
            rarity = "Rare",
            category = "category-" .. index,
        })
    end

    local result = offer(nil, items)
    for _, choice in ipairs(result.choices) do
        H.truthy(choice.id:match("^safe%-"))
    end
end)

H.test("malformed level ranges are ignored instead of crashing generation", function()
    local items = catalog()
    table.insert(items, {
        id = "bad-level-range",
        templateId = "bad-level-template",
        rarity = "Rare",
        category = "weapon",
        minimumLevel = "five",
    })
    H.equal(#offer(nil, items).choices, 6)
end)

H.test("owned items are excluded and recent offers are avoided when possible", function()
    local result = offer({
        ownedItemIds = { "item-02" },
        recentOfferItemIds = { "item-01", "item-05" },
    })
    local ids = "," .. choiceIds(result) .. ","
    H.equal(ids:find(",item%-02,"), nil)
    H.equal(ids:find(",item%-01,"), nil)
    H.equal(ids:find(",item%-05,"), nil)
end)

H.test("a reward choice can only be claimed once", function()
    local result = offer()
    local selected = Rewards.claim(result, result.choices[3].id)
    H.equal(result.status, "claimed")
    H.equal(result.selectedChoiceId, selected.id)
    H.raises(function()
        Rewards.claim(result, result.choices[1].id)
    end, "not open")
end)

H.test("an item outside the offer cannot be claimed", function()
    local result = offer()
    H.raises(function()
        Rewards.claim(result, "invented-item")
    end, "not part")
    H.equal(result.status, "open")
end)

H.test("live tournament rewards only qualify winners", function()
    H.truthy(offer({ mode = "tournament", result = "win" }))
    H.equal(offer({ mode = "tournament", result = "loss" }), nil)
end)

H.test("level-pool rewards qualify wins losses and draws", function()
    for _, result in ipairs({ "win", "loss", "draw" }) do
        H.truthy(offer({ mode = "level_pool", result = result }))
    end
end)

H.test("campaign sparring rewards remain disabled unless explicitly enabled", function()
    H.equal(offer({ mode = "sparring", result = "win" }), nil)
    H.truthy(offer({
        mode = "sparring",
        result = "win",
        enableSparringRewards = true,
    }))
end)

H.test("automatic reward delivery is tracked separately from the rare choice", function()
    local result = offer()
    H.equal(result.automatic.status, "pending")
    H.equal(result.automatic.rolls, 2)
    Rewards.markAutomaticDelivered(result)
    H.equal(result.automatic.status, "delivered")
    H.equal(result.status, "open")
    H.raises(function()
        Rewards.markAutomaticDelivered(result)
    end, "not pending")
end)

H.test("undersized catalogs fail instead of padding an offer with duplicates", function()
    local items = {}
    for index = 1, 5 do
        table.insert(items, {
            id = "small-" .. index,
            templateId = "small-template-" .. index,
            rarity = "Rare",
            category = "category-" .. index,
        })
    end
    H.raises(function()
        offer(nil, items)
    end, "6 are required")
end)

H.test("duplicate root templates cannot appear twice in one offer", function()
    local items = {}
    for index = 1, 8 do
        table.insert(items, {
            id = "duplicate-check-" .. index,
            templateId = index < 3 and "same-template" or "unique-template-" .. index,
            rarity = "Rare",
            category = "category-" .. index,
        })
    end
    local result = offer(nil, items)
    local sameTemplateCount = 0
    for _, choice in ipairs(result.choices) do
        if choice.templateId == "same-template" then
            sameTemplateCount = sameTemplateCount + 1
        end
    end
    H.equal(sameTemplateCount, 1)
end)

H.test("unique groups prevent alternate versions appearing together", function()
    local items = {}
    for index = 1, 8 do
        table.insert(items, {
            id = "group-check-" .. index,
            templateId = "group-template-" .. index,
            rarity = "Rare",
            category = "category-" .. index,
            uniqueGroup = index < 3 and "same-family" or nil,
        })
    end
    local result = offer(nil, items)
    local familyCount = 0
    for _, choice in ipairs(result.choices) do
        if choice.uniqueGroup == "same-family" then
            familyCount = familyCount + 1
        end
    end
    H.equal(familyCount, 1)
end)
