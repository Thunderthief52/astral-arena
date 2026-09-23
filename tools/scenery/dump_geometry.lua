-- Prints the runtime site and formation geometry as JSON for validate_scenery.py.
package.path = "./src/Mods/AstralArena/ScriptExtender/Lua/?.lua;" .. package.path
local Sites = require("AstralArena.Shared.ArenaSites")
local Layouts = require("AstralArena.Shared.ArenaLayouts")
local function list(values, fn)
    local parts = {}
    for _, value in ipairs(values) do table.insert(parts, fn(value)) end
    return "[" .. table.concat(parts, ",") .. "]"
end
local function pair(p) return string.format("[%s,%s]", tostring(p[1]), tostring(p[2])) end
local function site(s)
    return string.format('{"id":"%s","offset":[%s,%s,%s],"party":%s}', s.id, s.offset[1], s.offset[2], s.offset[3], list(s.partyOffsets, pair))
end
local staging = Sites.staging()
io.write('{"staging":', site(staging), ',"sites":', list(Sites.allCombat(), site),
    ',"layouts":', list(Layouts.all(), function(l) return string.format('{"id":"%s","enemies":%s}', l.id, list(l.enemyOffsets, pair)) end), "}\n")
