local Layouts = {}

local VALUES = {
    { id = "vanguard-line", displayName = "Vanguard Line", enemyOffsets = { { 9, -5 }, { 10, -2 }, { 10, 2 }, { 9, 5 } } },
    { id = "astral-cross", displayName = "Astral Cross", enemyOffsets = { { 8, 0 }, { 11, 0 }, { 10, -4 }, { 10, 4 } } },
    { id = "crescent", displayName = "Crescent", enemyOffsets = { { 8, -5 }, { 11, -2 }, { 11, 2 }, { 8, 5 } } },
    { id = "twin-flanks", displayName = "Twin Flanks", enemyOffsets = { { 7, -6 }, { 11, -5 }, { 11, 5 }, { 7, 6 } } },
    { id = "spearhead", displayName = "Spearhead", enemyOffsets = { { 7, 0 }, { 10, -3 }, { 10, 3 }, { 13, 0 } } },
    { id = "broken-ring", displayName = "Broken Ring", enemyOffsets = { { 7, -4 }, { 10, -6 }, { 12, 2 }, { 8, 6 } } },
    { id = "four-corners", displayName = "Four Corners", enemyOffsets = { { 8, -6 }, { 12, -6 }, { 12, 6 }, { 8, 6 } } },
    { id = "deep-v", displayName = "Deep V", enemyOffsets = { { 8, -5 }, { 10, -2 }, { 10, 2 }, { 13, 0 } } },
    { id = "echelon", displayName = "Echelon", enemyOffsets = { { 7, -6 }, { 9, -2 }, { 11, 2 }, { 13, 6 } } },
    { id = "split-ranks", displayName = "Split Ranks", enemyOffsets = { { 8, -5 }, { 8, 5 }, { 13, -3 }, { 13, 3 } } },
    { id = "compass", displayName = "Astral Compass", enemyOffsets = { { 7, 0 }, { 10, -6 }, { 10, 6 }, { 13, 0 } } },
    { id = "hollow-square", displayName = "Hollow Square", enemyOffsets = { { 8, -4 }, { 12, -4 }, { 12, 4 }, { 8, 4 } } },
}

local function hash(value)
    local result = 216613626
    local text = tostring(value or "")
    for index = 1, #text do
        result = (result * 131 + text:byte(index)) % 2147483647
    end
    return result
end

function Layouts.all()
    local result = {}
    for _, layout in ipairs(VALUES) do
        table.insert(result, layout)
    end
    return result
end

function Layouts.select(seed)
    return VALUES[(hash(seed) % #VALUES) + 1]
end

return Layouts
