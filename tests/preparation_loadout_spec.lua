local H = require("tests.test_helper")
local Loadout = require("AstralArena.Shared.PreparationLoadout")

H.test("every preparation loadout has proficiency choices and all accessory slots", function()
    local slots = {}
    local templates = {}
    for _, item in ipairs(Loadout) do
        H.truthy(type(item.templateId) == "string" and #item.templateId == 36)
        H.equal(templates[item.templateId], nil)
        templates[item.templateId] = true
        slots[item.slot] = true
    end
    for _, required in ipairs({
        "melee-weapon", "caster-weapon", "ranged-weapon",
        "light-armour", "medium-armour", "heavy-armour",
        "helmet", "gloves", "boots", "amulet", "ring",
    }) do
        H.truthy(slots[required], "missing preparation slot " .. required)
    end
    H.equal(#Loadout, 11)
end)
