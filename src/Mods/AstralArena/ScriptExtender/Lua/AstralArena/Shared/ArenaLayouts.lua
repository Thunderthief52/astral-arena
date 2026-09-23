local Layouts = {}

local VALUES = {
    { id = "vanguard-line", displayName = "Vanguard Line", enemyOffsets = { { 30, -6 }, { 32, -2 }, { 32, 2 }, { 30, 6 } } },
    { id = "astral-cross", displayName = "Astral Cross", enemyOffsets = { { 30, 0 }, { 34, 0 }, { 33, -6 }, { 33, 6 } } },
    { id = "crescent", displayName = "Crescent", enemyOffsets = { { 30, -7 }, { 33, -3 }, { 33, 3 }, { 30, 7 } } },
    { id = "twin-flanks", displayName = "Twin Flanks", enemyOffsets = { { 30, -8 }, { 33, -6 }, { 33, 6 }, { 30, 8 } } },
    { id = "spearhead", displayName = "Spearhead", enemyOffsets = { { 30, 0 }, { 32, -4 }, { 32, 4 }, { 34, 0 } } },
    { id = "broken-ring", displayName = "Broken Ring", enemyOffsets = { { 30, -5 }, { 33, -8 }, { 34, 3 }, { 31, 8 } } },
    { id = "four-corners", displayName = "Four Corners", enemyOffsets = { { 30, -8 }, { 34, -8 }, { 34, 8 }, { 30, 8 } } },
    { id = "deep-v", displayName = "Deep V", enemyOffsets = { { 30, -7 }, { 32, -3 }, { 32, 3 }, { 34, 0 } } },
    { id = "echelon", displayName = "Echelon", enemyOffsets = { { 30, -8 }, { 31, -3 }, { 33, 3 }, { 34, 8 } } },
    { id = "split-ranks", displayName = "Split Ranks", enemyOffsets = { { 30, -7 }, { 30, 7 }, { 34, -4 }, { 34, 4 } } },
    { id = "compass", displayName = "Astral Compass", enemyOffsets = { { 30, 0 }, { 33, -8 }, { 33, 8 }, { 34, 0 } } },
    { id = "hollow-square", displayName = "Hollow Square", enemyOffsets = { { 30, -6 }, { 34, -6 }, { 34, 6 }, { 30, 6 } } },
}

-- Deterministic string hash. The previous polynomial hash reduced modulo 12
-- almost ignored the bout and wave digits, so every run replayed the same few
-- formations. Two coprime moduli plus a high-order bucket spread nearby seeds.
local PRIME_A = 2147483629
local PRIME_B = 1000003

local function hash(value)
    local a = 216613626
    local b = 7919
    local text = tostring(value or "")
    for index = 1, #text do
        local byte = text:byte(index)
        a = (a * 131 + byte) % PRIME_A
        b = (b * 257 + byte * 7 + index) % PRIME_B
    end
    return (a + b * 48271) % PRIME_B
end

function Layouts.all()
    local result = {}
    for _, layout in ipairs(VALUES) do
        table.insert(result, layout)
    end
    return result
end

function Layouts.select(seed)
    return VALUES[math.floor(hash(seed) * #VALUES / PRIME_B) + 1]
end

return Layouts
