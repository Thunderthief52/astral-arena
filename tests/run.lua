package.path = table.concat({
    "./src/Mods/AstralArena/ScriptExtender/Lua/?.lua",
    "./src/Mods/AstralArena/ScriptExtender/Lua/?/init.lua",
    "./?.lua",
    package.path,
}, ";")

local Helper = require("tests.test_helper")
require("tests.bracket_spec")
require("tests.match_spec")
require("tests.level_pool_run_spec")
require("tests.roster_spec")
require("tests.sparring_spec")

if not Helper.run() then
    os.exit(1)
end
