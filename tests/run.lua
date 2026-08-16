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
require("tests.rewards_spec")
require("tests.solo_run_spec")
require("tests.solo_arena_spec")
require("tests.bg3_adapter_spec")
require("tests.arena_bootstrap_spec")
require("tests.arena_layouts_spec")
require("tests.arena_sites_spec")
require("tests.adventure_handoff_spec")

if not Helper.run() then
    os.exit(1)
end
