local H = require("tests.test_helper")
local Loadout = require("AstralArena.Shared.PreparationLoadout")

H.test("preparation uses audited random pools for every equipment slot", function()
    local slots = {}
    local templates = {}
    for _, item in ipairs(Loadout) do
        H.truthy(type(item.templateId) == "string" and #item.templateId == 36)
        H.equal(templates[item.templateId], nil)
        templates[item.templateId] = true
        slots[item.slot] = (slots[item.slot] or 0) + 1
    end
    for _, required in ipairs({
        "melee-weapon", "caster-weapon", "ranged-weapon",
        "light-armour", "medium-armour", "heavy-armour",
        "helmet", "gloves", "boots", "amulet", "ring",
    }) do
        H.truthy((slots[required] or 0) >= 2, "preparation slot needs multiple random candidates: " .. required)
    end
    H.equal(#Loadout, 39)
end)
