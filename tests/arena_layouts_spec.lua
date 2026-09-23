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
        for _, offset in ipairs(layout.enemyOffsets) do
            H.truthy(offset[1] >= 45, "enemy formations must begin at least 45 metres from the player line")
            H.truthy(offset[1] <= 49, "enemy formations must remain inside the audited long-range lane")
            H.truthy(math.abs(offset[2]) <= 8, "enemy formations must remain inside the audited clear lane")
        end
    end
end)

H.test("arena layout selection is deterministic", function()
    H.equal(Layouts.select("same-run").id, Layouts.select("same-run").id)
end)

H.test("consecutive bouts and waves draw varied formations", function()
    local seen = {}
    local count = 0
    for bout = 1, 5 do
        local id = Layouts.select("ai-run-1-bout-" .. bout .. "-wave-1").id
        if not seen[id] then
            seen[id] = true
            count = count + 1
        end
    end
    H.truthy(count >= 3, "five opening waves should use at least three formations")
    local all = {}
    local distinct = 0
    for index = 1, 240 do
        local id = Layouts.select("seed-" .. index).id
        if not all[id] then
            all[id] = true
            distinct = distinct + 1
        end
    end
    H.equal(distinct, 12)
end)
