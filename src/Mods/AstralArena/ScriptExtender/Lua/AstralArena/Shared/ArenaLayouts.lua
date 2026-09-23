local Layouts = {}

local VALUES = {
    { id = "vanguard-line", displayName = "Vanguard Line", enemyOffsets = { { 45, -6 }, { 47, -2 }, { 47, 2 }, { 45, 6 } } },
    { id = "astral-cross", displayName = "Astral Cross", enemyOffsets = { { 45, 0 }, { 49, 0 }, { 48, -6 }, { 48, 6 } } },
    { id = "crescent", displayName = "Crescent", enemyOffsets = { { 45, -7 }, { 48, -3 }, { 48, 3 }, { 45, 7 } } },
    { id = "twin-flanks", displayName = "Twin Flanks", enemyOffsets = { { 45, -8 }, { 48, -6 }, { 48, 6 }, { 45, 8 } } },
    { id = "spearhead", displayName = "Spearhead", enemyOffsets = { { 45, 0 }, { 47, -4 }, { 47, 4 }, { 49, 0 } } },
    { id = "broken-ring", displayName = "Broken Ring", enemyOffsets = { { 45, -5 }, { 48, -8 }, { 49, 3 }, { 46, 8 } } },
    { id = "four-corners", displayName = "Four Corners", enemyOffsets = { { 45, -8 }, { 49, -8 }, { 49, 8 }, { 45, 8 } } },
    { id = "deep-v", displayName = "Deep V", enemyOffsets = { { 45, -7 }, { 47, -3 }, { 47, 3 }, { 49, 0 } } },
    { id = "echelon", displayName = "Echelon", enemyOffsets = { { 45, -8 }, { 46, -3 }, { 48, 3 }, { 49, 8 } } },
    { id = "split-ranks", displayName = "Split Ranks", enemyOffsets = { { 45, -7 }, { 45, 7 }, { 49, -4 }, { 49, 4 } } },
    { id = "compass", displayName = "Astral Compass", enemyOffsets = { { 45, 0 }, { 48, -8 }, { 48, 8 }, { 49, 0 } } },
    { id = "hollow-square", displayName = "Hollow Square", enemyOffsets = { { 45, -6 }, { 49, -6 }, { 49, 6 }, { 45, 6 } } },
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
