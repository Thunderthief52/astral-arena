local Sites = {}

local STAGING = {
    id = "staging",
    displayName = "Astral Staging",
    offset = { 0, 0, 0 },
    partyOffsets = {
        { 0, 0 },
        { -2, -2 },
        { -2, 2 },
        { -4, 0 },
    },
    safe = true,
}

local COMBAT = {
    {
        id = "astral-flats",
        displayName = "Astral Flats",
        offset = { 0, 0, 28 },
        partyOffsets = { { 0, 0 }, { -2, -2 }, { -2, 2 }, { -4, 0 } },
        visualIdentity = "open ground and long sight lines",
    },
    {
        id = "crescent-ruin",
        displayName = "Crescent Ruin",
        offset = { 48, 0, 0 },
        partyOffsets = { { 0, 0 }, { -2, -3 }, { -2, 3 }, { -4, 0 } },
        visualIdentity = "a curved ruin with broken flanks",
    },
    {
        id = "echelon-steps",
        displayName = "Echelon Steps",
        offset = { 80, 0, 28 },
        partyOffsets = { { 0, 0 }, { -2, -2 }, { -4, 0 }, { -6, 2 } },
        visualIdentity = "a stepped approach with staggered ranks",
    },
}

function Sites.staging()
    return STAGING
end

function Sites.allCombat()
    local result = {}
    for _, site in ipairs(COMBAT) do
        table.insert(result, site)
    end
    return result
end

function Sites.forBout(battleIndex)
    battleIndex = math.max(1, math.floor(tonumber(battleIndex) or 1))
    return COMBAT[((battleIndex - 1) % #COMBAT) + 1]
end

function Sites.forLevel(level)
    local byLevel = {
        [3] = COMBAT[1],
        [5] = COMBAT[1],
        [8] = COMBAT[2],
        [10] = COMBAT[3],
        [12] = COMBAT[3],
    }
    return byLevel[tonumber(level)] or Sites.forBout(1)
end

return Sites
