local H = require("tests.test_helper")

local previousExt = _G.Ext
_G.Ext = {
    Require = function(path)
        return require((path:gsub("%.lua$", ""):gsub("/", ".")))
    end,
}
local AutoKit = require("AstralArena.Core.AutoKit")
local AutoKitService = require("AstralArena.Server.AutoKitService")
local Catalog = require("AstralArena.Shared.HirelingCatalog")
local RunRecord = require("AstralArena.Core.RunRecord")
_G.Ext = previousExt

local STATS = {
    Plate = { Slot = "Breast", ArmorType = "Plate", ArmorClass = 18, Rarity = "Common", ["Proficiency Group"] = "HeavyArmor" },
    PlatePlusOne = { Slot = "Breast", ArmorType = "Plate", ArmorClass = 18, Rarity = "Uncommon", Boosts = "AC(1)", ["Proficiency Group"] = "HeavyArmor" },
    ChainShirt = { Slot = "Breast", ArmorType = "ChainShirt", ArmorClass = 13, Rarity = "Common", ["Proficiency Group"] = "MediumArmor" },
    Studded = { Slot = "Breast", ArmorType = "StuddedLeather", ArmorClass = 12, Rarity = "Uncommon", ["Proficiency Group"] = "LightArmor" },
    Robe = { Slot = "Breast", ArmorType = "Cloth", ArmorClass = 10, Rarity = "Uncommon", Boosts = "Ability(Intelligence,1)" },
    Greatsword = { Slot = "Melee Main Weapon", Damage = "2d6", Rarity = "Uncommon", Boosts = "WeaponEnchantment(1)", ["Weapon Properties"] = "Melee;Twohanded;Heavy", ["Proficiency Group"] = "Greatswords;MartialWeapons" },
    Longsword = { Slot = "Melee Main Weapon", Damage = "1d8", Rarity = "Uncommon", Boosts = "WeaponEnchantment(1)", ["Weapon Properties"] = "Melee;Versatile", ["Proficiency Group"] = "Longswords;MartialWeapons" },
    Mace = { Slot = "Melee Main Weapon", Damage = "1d6", Rarity = "Uncommon", Boosts = "WeaponEnchantment(1)", ["Weapon Properties"] = "Melee", ["Proficiency Group"] = "Maces;SimpleWeapons" },
    Rapier = { Slot = "Melee Main Weapon", Damage = "1d8", Rarity = "Uncommon", Boosts = "WeaponEnchantment(1)", ["Weapon Properties"] = "Melee;Finesse", ["Proficiency Group"] = "Rapiers;MartialWeapons" },
    Quarterstaff = { Slot = "Melee Main Weapon", Damage = "1d6", Rarity = "Uncommon", ["Weapon Properties"] = "Melee;Versatile", ["Proficiency Group"] = "Quarterstaffs;SimpleWeapons" },
    Longbow = { Slot = "Ranged Main Weapon", Damage = "1d8", Rarity = "Uncommon", Boosts = "WeaponEnchantment(1)", ["Weapon Properties"] = "Ammunition;Twohanded;Heavy", ["Proficiency Group"] = "Longbows;MartialWeapons" },
    Shield = { Slot = "Melee Offhand Weapon", ArmorClass = 2, Rarity = "Common", ["Proficiency Group"] = "Shields" },
    RingCommon = { Slot = "Ring", Rarity = "Common" },
    RingRare = { Slot = "Ring", Rarity = "Rare" },
    RingUncommon = { Slot = "Ring", Rarity = "Uncommon" },
    HelmInt = { Slot = "Helmet", Rarity = "Uncommon", Boosts = "Ability(Intelligence,1)" },
    HelmPlain = { Slot = "Helmet", Rarity = "Uncommon" },
}

local function item(id, statName)
    local fields = { id = id, Name = statName }
    for key, value in pairs(STATS[statName]) do
        fields[key] = value
    end
    return AutoKit.describe(fields)
end

local function chosen(changes)
    local result = {}
    for _, change in ipairs(changes) do
        result[change.slot] = change.item.id
    end
    return result
end

H.test("auto-kit puts a fighter in its heaviest armour and a two-handed weapon without a shield", function()
    local items = { item("plate", "Plate"), item("plate1", "PlatePlusOne"), item("gs", "Greatsword"), item("ls", "Longsword"), item("shield", "Shield") }
    local picks = chosen(AutoKit.chooseLoadout(AutoKit.PROFILES.Fighter, items, {}))
    H.equal(picks.Breast, "plate1")
    H.equal(picks.MeleeMainHand, "gs")
    H.equal(picks.MeleeOffHand, nil)
end)

H.test("auto-kit gives a cleric medium armour, a simple one-hander and a shield", function()
    local items = { item("plate", "Plate"), item("chain", "ChainShirt"), item("gs", "Greatsword"), item("mace", "Mace"), item("ls", "Longsword"), item("shield", "Shield") }
    local picks = chosen(AutoKit.chooseLoadout(AutoKit.PROFILES.Cleric, items, {}))
    H.equal(picks.Breast, "chain")
    H.equal(picks.MeleeMainHand, "mace")
    H.equal(picks.MeleeOffHand, "shield")
end)

H.test("auto-kit keeps wizards in robes with a staff and prefers an Intelligence helmet", function()
    local items = { item("plate", "Plate"), item("robe", "Robe"), item("staff", "Quarterstaff"), item("gs", "Greatsword"), item("helmA", "HelmPlain"), item("helmB", "HelmInt") }
    local picks = chosen(AutoKit.chooseLoadout(AutoKit.PROFILES.Wizard, items, {}))
    H.equal(picks.Breast, "robe")
    H.equal(picks.MeleeMainHand, "staff")
    H.equal(picks.Helmet, "helmB")
end)

H.test("auto-kit arms rogues with finesse weapons and rangers with a bow", function()
    local rogue = chosen(AutoKit.chooseLoadout(AutoKit.PROFILES.Rogue, { item("ls", "Longsword"), item("rapier", "Rapier"), item("studded", "Studded"), item("chain", "ChainShirt") }, {}))
    H.equal(rogue.MeleeMainHand, "rapier")
    H.equal(rogue.Breast, "studded")
    local ranger = chosen(AutoKit.chooseLoadout(AutoKit.PROFILES.Ranger, { item("bow", "Longbow"), item("ls", "Longsword") }, {}))
    H.equal(ranger.RangedMainHand, "bow")
end)

H.test("auto-kit fills both ring slots with the two best rings and never swaps for worse gear", function()
    local items = { item("r1", "RingCommon"), item("r2", "RingRare"), item("r3", "RingUncommon"), item("plate", "Plate") }
    local picks = chosen(AutoKit.chooseLoadout(AutoKit.PROFILES.Fighter, items, { Breast = item("plate1", "PlatePlusOne") }))
    H.equal(picks.Ring, "r2")
    H.equal(picks.Ring2, "r3")
    H.equal(picks.Breast, nil)
end)

H.test("auto-kit build steps unlock by level and are never repeated", function()
    local steps = AutoKit.pendingSteps("Fighter", 5, {})
    H.equal(#steps, 1)
    H.equal(steps[1].id, "fighter-gwm")
    H.equal(#AutoKit.pendingSteps("Fighter", 12, { ["fighter-gwm"] = true }), 3)
    H.equal(#AutoKit.pendingSteps("Bard", 12, {}), 0)
    for className in pairs(AutoKit.PROFILES) do
        H.truthy(AutoKit.BUILDS[className] ~= nil, className .. " needs a build plan")
    end
end)

local function serviceFixture()
    local record = RunRecord.new()
    local store = { load = function() return record end, save = function(value) record = value end }
    local adapter = { equipped = {}, spells = {}, passives = {}, boosts = {}, notes = {} }
    local fighter = Catalog[1]
    adapter.inventory = {
        [fighter.characterGuid] = {
            { id = "plate1", Name = "PlatePlusOne", Slot = "Breast", ArmorType = "Plate", ArmorClass = 18, Rarity = "Uncommon", Boosts = "AC(1)" },
            { id = "gs", Name = "Greatsword", Slot = "Melee Main Weapon", Damage = "2d6", Rarity = "Uncommon", Boosts = "WeaponEnchantment(1)", ["Weapon Properties"] = "Melee;Twohanded", ["Proficiency Group"] = "Greatswords;MartialWeapons" },
        },
    }
    function adapter.characterItems(guid) return adapter.inventory[guid] or {} end
    function adapter.equippedItems(guid) return adapter.equipped[guid] or {} end
    function adapter.equipItem(guid, id)
        adapter.equipped[guid] = adapter.equipped[guid] or {}
        for _, fields in ipairs(adapter.inventory[guid]) do
            if fields.id == id then
                local descriptor = AutoKit.describe(fields)
                adapter.equipped[guid][descriptor.slot] = fields
            end
        end
    end
    function adapter.statExists(name) return name ~= "GreatWeaponMaster_AllIn" end
    function adapter.addSpell(guid, name) table.insert(adapter.spells, name) end
    function adapter.addPassive(guid, name) table.insert(adapter.passives, name) end
    function adapter.addBoosts(guid, boost) table.insert(adapter.boosts, boost) end
    function adapter.notify(guid, message) table.insert(adapter.notes, message) end
    local output = {}
    local service = AutoKitService.new(adapter, function(line) table.insert(output, line) end, Catalog, store)
    return service, adapter, fighter, function() return record end, output
end

H.test("auto-kit service levels and equips a hireling once and leaves players alone", function()
    local service, adapter, fighter, getRecord = serviceFixture()
    local members = {
        { guid = "player-a", level = 8, isAvatar = true },
        { guid = "S_GLO_Hirelings_Fighter_" .. fighter.characterGuid, level = 8, isAvatar = false },
    }
    adapter.inventory[members[2].guid] = adapter.inventory[fighter.characterGuid]
    service:refresh(members)
    H.equal(adapter.passives[1], "GreatWeaponMaster_BonusAttack")
    H.equal(#adapter.passives, 2) -- GWM bonus attack + Alert; the missing AllIn name is skipped
    H.equal(adapter.boosts[1], "Ability(Strength,2)")
    H.equal(adapter.equipped[members[2].guid].Breast.id, "plate1")
    H.equal(adapter.equipped[members[2].guid].MeleeMainHand.id, "gs")
    H.equal(adapter.equipped["player-a"], nil)
    H.truthy(getRecord().autoKit[fighter.characterGuid]["fighter-gwm"])
    service:refresh(members)
    H.equal(#adapter.passives, 2)
    H.equal(#adapter.boosts, 1)
end)
