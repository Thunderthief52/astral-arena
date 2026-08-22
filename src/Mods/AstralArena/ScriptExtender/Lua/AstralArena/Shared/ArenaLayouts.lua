local Layouts = {}

local VALUES = {
    { id = "vanguard-line", displayName = "Vanguard Line", enemyOffsets = { { 20, -6 }, { 22, -2 }, { 22, 2 }, { 20, 6 } } },
    { id = "astral-cross", displayName = "Astral Cross", enemyOffsets = { { 20, 0 }, { 25, 0 }, { 23, -6 }, { 23, 6 } } },
    { id = "crescent", displayName = "Crescent", enemyOffsets = { { 20, -7 }, { 23, -3 }, { 23, 3 }, { 20, 7 } } },
    { id = "twin-flanks", displayName = "Twin Flanks", enemyOffsets = { { 19, -8 }, { 24, -6 }, { 24, 6 }, { 19, 8 } } },
    { id = "spearhead", displayName = "Spearhead", enemyOffsets = { { 19, 0 }, { 22, -4 }, { 22, 4 }, { 26, 0 } } },
    { id = "broken-ring", displayName = "Broken Ring", enemyOffsets = { { 19, -5 }, { 23, -8 }, { 25, 3 }, { 20, 8 } } },
    { id = "four-corners", displayName = "Four Corners", enemyOffsets = { { 20, -8 }, { 25, -8 }, { 25, 8 }, { 20, 8 } } },
    { id = "deep-v", displayName = "Deep V", enemyOffsets = { { 20, -7 }, { 22, -3 }, { 22, 3 }, { 26, 0 } } },
    { id = "echelon", displayName = "Echelon", enemyOffsets = { { 19, -8 }, { 21, -3 }, { 23, 3 }, { 26, 8 } } },
    { id = "split-ranks", displayName = "Split Ranks", enemyOffsets = { { 20, -7 }, { 20, 7 }, { 26, -4 }, { 26, 4 } } },
    { id = "compass", displayName = "Astral Compass", enemyOffsets = { { 19, 0 }, { 23, -8 }, { 23, 8 }, { 26, 0 } } },
    { id = "hollow-square", displayName = "Hollow Square", enemyOffsets = { { 20, -6 }, { 25, -6 }, { 25, 6 }, { 20, 6 } } },
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
