local H = require("tests.test_helper")
local Layouts = require("AstralArena.Shared.ArenaLayouts")

H.test("arena supplies twelve distinct encounter layouts", function()
    local seen = {}
    local layouts = Layouts.all()
    H.equal(#layouts, 12)
    for _, layout in ipairs(layouts) do
        H.equal(#layout.enemyOffsets, 4)
        H.truthy(not seen[layout.id], "layout IDs must be unique")
        seen[layout.id] = true
    end
end)

H.test("arena layout selection is deterministic", function()
    H.equal(Layouts.select("same-run").id, Layouts.select("same-run").id)
end)
