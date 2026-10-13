-- AutoKit: deterministic "best build" and "best gear" decisions for arena
-- hirelings. Pure Lua: the server adapter reads item stats from the engine and
-- applies the choices; everything that decides lives here so it can be tested.
local AutoKit = {}

local RARITY = { Common = 0, Uncommon = 1, Rare = 2, VeryRare = 3, Legendary = 4 }

local ACCESSORY_SLOTS = { Helmet = true, Gloves = true, Boots = true, Cloak = true, Amulet = true, Ring = true }

-- Class profiles: what each hireling can use well and how it fights.
--   armor:   armour weights it is proficient with (Cloth is always allowed)
--   weapons: proficiency words that make a weapon usable
--   style:   "great-weapon" | "sword-and-board" | "finesse" | "archer" | "caster"
--   dex:     the Dexterity modifier the scoring assumes for armour caps
--   key:     the ability the build pushes (used to prefer accessories)
AutoKit.PROFILES = {
    Fighter = {
        armor = { Light = true, Medium = true, Heavy = true }, shields = true,
        weapons = { SimpleWeapons = true, MartialWeapons = true },
        style = "great-weapon", dex = 1, key = "Strength",
    },
    Paladin = {
        armor = { Light = true, Medium = true, Heavy = true }, shields = true,
        weapons = { SimpleWeapons = true, MartialWeapons = true },
        style = "great-weapon", dex = 0, key = "Strength",
    },
    Cleric = {
        armor = { Light = true, Medium = true }, shields = true,
        weapons = { SimpleWeapons = true },
        style = "sword-and-board", dex = 1, key = "Wisdom",
    },
    Wizard = {
        armor = {}, shields = false,
        weapons = { Daggers = true, Quarterstaffs = true, LightCrossbows = true, Darts = true, Slings = true },
        style = "caster", dex = 2, key = "Intelligence",
    },
    Rogue = {
        armor = { Light = true }, shields = false,
        weapons = { SimpleWeapons = true, HandCrossbows = true, Longswords = true, Rapiers = true, Shortswords = true },
        style = "finesse", dex = 4, key = "Dexterity",
    },
    Ranger = {
        armor = { Light = true, Medium = true }, shields = true,
        weapons = { SimpleWeapons = true, MartialWeapons = true },
        style = "archer", dex = 4, key = "Dexterity",
    },
}

local ARMOR_WEIGHT = {
    Cloth = "Cloth", None = "Cloth",
    Padded = "Light", Leather = "Light", StuddedLeather = "Light",
    Hide = "Medium", ChainShirt = "Medium", ScaleMail = "Medium", BreastPlate = "Medium", HalfPlate = "Medium",
    RingMail = "Heavy", ChainMail = "Heavy", Splint = "Heavy", Plate = "Heavy",
}

local function split(text)
    local values = {}
    for word in tostring(text or ""):gmatch("[^;,%s]+") do
        values[word] = true
    end
    return values
end

local function averageDice(text)
    local total = 0
    for count, sides in tostring(text or ""):gmatch("(%d+)d(%d+)") do
        total = total + tonumber(count) * (tonumber(sides) + 1) / 2
    end
    return total
end

local function enchantment(boosts)
    local value = tostring(boosts or ""):match("WeaponEnchantment%((%-?%d+)%)")
    return tonumber(value) or 0
end

local function acBonus(boosts)
    local value = tostring(boosts or ""):match("AC%((%-?%d+)%)")
    return tonumber(value) or 0
end

-- Turns raw stat fields (as the engine exposes them) into a plain descriptor.
function AutoKit.describe(fields)
    if type(fields) ~= "table" then
        return nil
    end
    local slot = fields.Slot
    local boosts = table.concat({ tostring(fields.Boosts or ""), tostring(fields.DefaultBoosts or ""), tostring(fields.PassivesOnEquip or "") }, ";")
    local item = {
        id = fields.id,
        name = fields.Name or fields.id,
        rarity = RARITY[fields.Rarity] or 0,
        boosts = boosts,
        groups = split(fields["Proficiency Group"]),
    }
    if slot == "Breast" then
        item.kind = "armor"
        item.slot = "Breast"
        item.weight = ARMOR_WEIGHT[fields.ArmorType] or "Cloth"
        item.armorClass = tonumber(fields.ArmorClass) or 10
        item.bonusAC = acBonus(boosts)
    elseif slot == "Melee Offhand Weapon" and (fields.ArmorClass ~= nil or split(fields["Proficiency Group"]).Shields) then
        item.kind = "shield"
        item.slot = "MeleeOffHand"
        item.armorClass = tonumber(fields.ArmorClass) or 2
        item.bonusAC = acBonus(boosts)
    elseif slot == "Melee Main Weapon" or slot == "Melee Offhand Weapon" or slot == "Ranged Main Weapon" then
        local properties = split(fields["Weapon Properties"])
        item.kind = "weapon"
        item.ranged = slot == "Ranged Main Weapon" or properties.Ammunition == true
        item.slot = item.ranged and "RangedMainHand" or "MeleeMainHand"
        item.twoHanded = properties.Twohanded == true
        item.finesse = properties.Finesse == true
        item.light = properties.Light == true
        item.damage = averageDice(fields.Damage)
        item.enchant = enchantment(boosts)
    elseif ACCESSORY_SLOTS[slot] then
        item.kind = "accessory"
        item.slot = slot
    else
        return nil
    end
    return item
end

local function proficientWeapon(profile, item)
    for group in pairs(item.groups) do
        if profile.weapons[group] then
            return true
        end
    end
    return false
end

-- Higher is better; nil means the profile should never equip the item.
function AutoKit.score(profile, item)
    if not item or not profile then
        return nil
    end
    if item.kind == "armor" then
        if item.weight ~= "Cloth" and not profile.armor[item.weight] then
            return nil
        end
        local dexCap = item.weight == "Heavy" and 0 or item.weight == "Medium" and 2 or profile.dex
        local ac = item.armorClass + item.bonusAC + math.min(profile.dex, dexCap)
        return ac * 10 + item.rarity
    elseif item.kind == "shield" then
        if not profile.shields or profile.style ~= "sword-and-board" then
            return nil
        end
        return (item.armorClass + item.bonusAC) * 10 + item.rarity
    elseif item.kind == "weapon" then
        if not proficientWeapon(profile, item) then
            return nil
        end
        local value = item.damage + item.enchant * 2.5 + item.rarity
        local style = profile.style
        if item.ranged then
            return value + (style == "archer" and 20 or 0)
        end
        if style == "great-weapon" then
            value = value + (item.twoHanded and 10 or 0)
        elseif style == "sword-and-board" then
            if item.twoHanded then
                return nil
            end
        elseif style == "finesse" then
            if not item.finesse then
                value = value - 8
            end
        elseif style == "caster" then
            value = value + (item.groups.Quarterstaffs and 4 or 0)
        end
        return value
    elseif item.kind == "accessory" then
        local value = item.rarity * 10
        if profile.key and item.boosts:find(profile.key, 1, true) then
            value = value + 5
        end
        return value
    end
    return nil
end

-- items:    descriptors the character carries (equipped ones included)
-- equipped: map slot -> descriptor currently worn
-- Returns a list of { slot = ..., item = descriptor } upgrades to equip.
function AutoKit.chooseLoadout(profile, items, equipped)
    equipped = equipped or {}
    local best = {}
    local rings = {}
    for _, item in ipairs(items or {}) do
        local value = AutoKit.score(profile, item)
        if value then
            if item.slot == "Ring" then
                table.insert(rings, { item = item, score = value })
            else
                local current = best[item.slot]
                if not current or value > current.score then
                    best[item.slot] = { item = item, score = value }
                end
            end
        end
    end
    table.sort(rings, function(a, b)
        if a.score == b.score then
            return tostring(a.item.id) < tostring(b.item.id)
        end
        return a.score > b.score
    end)

    local changes = {}
    local slots = {}
    for slot in pairs(best) do
        table.insert(slots, slot)
    end
    table.sort(slots)
    -- A two-handed main weapon leaves no room for a shield.
    local main = best.MeleeMainHand and best.MeleeMainHand.item
    if main and main.twoHanded then
        best.MeleeOffHand = nil
    end
    for _, slot in ipairs(slots) do
        local choice = best[slot]
        if choice then
            local worn = equipped[slot]
            local wornScore = worn and AutoKit.score(profile, worn) or nil
            if worn == nil or wornScore == nil or choice.score > wornScore + 0.01 then
                if not (worn and worn.id == choice.item.id) then
                    table.insert(changes, { slot = slot, item = choice.item })
                end
            end
        end
    end
    local ringSlots = { "Ring", "Ring2" }
    for index, slot in ipairs(ringSlots) do
        local choice = rings[index]
        if choice then
            local worn = equipped[slot]
            local wornScore = worn and AutoKit.score(profile, worn) or nil
            local alreadyWorn = (equipped.Ring and equipped.Ring.id == choice.item.id)
                or (equipped.Ring2 and equipped.Ring2.id == choice.item.id)
            if not alreadyWorn and (worn == nil or wornScore == nil or choice.score > wornScore + 0.01) then
                table.insert(changes, { slot = slot, item = choice.item })
            end
        end
    end
    return changes
end

-- Build plans. Every step has a stable id so it is applied exactly once.
-- Spell and passive entries list alternative engine names; the adapter uses
-- the first one that exists in the loaded game data and skips unknown ones.
local function step(level, id, fields)
    fields.level = level
    fields.id = id
    return fields
end

AutoKit.BUILDS = {
    Fighter = {
        step(4, "fighter-gwm", { passives = { { "GreatWeaponMaster_BonusAttack" }, { "GreatWeaponMaster_AllIn" } }, label = "Great Weapon Master" }),
        step(6, "fighter-str-6", { boosts = { "Ability(Strength,2)" }, label = "+2 Strength" }),
        step(8, "fighter-alert", { passives = { { "Alert" } }, label = "Alert" }),
        step(12, "fighter-con-12", { boosts = { "Ability(Constitution,2)" }, label = "+2 Constitution" }),
    },
    Paladin = {
        step(2, "paladin-spells-2", { spells = { { "Target_Bless" }, { "Target_ShieldOfFaith" }, { "Target_CureWounds" } }, label = "Bless, Shield of Faith, Cure Wounds" }),
        step(4, "paladin-gwm", { passives = { { "GreatWeaponMaster_BonusAttack" }, { "GreatWeaponMaster_AllIn" } }, label = "Great Weapon Master" }),
        step(5, "paladin-spells-5", { spells = { { "Shout_Aid", "Target_Aid" } }, label = "Aid" }),
        step(8, "paladin-str-8", { boosts = { "Ability(Strength,2)" }, label = "+2 Strength" }),
        step(9, "paladin-spells-9", { spells = { { "Target_Revivify" } }, label = "Revivify" }),
        step(12, "paladin-alert", { passives = { { "Alert" } }, label = "Alert" }),
    },
    Cleric = {
        step(1, "cleric-spells-1", { spells = { { "Target_Bless" }, { "Target_HealingWord" }, { "Projectile_GuidingBolt" } }, label = "Bless, Healing Word, Guiding Bolt" }),
        step(3, "cleric-spells-3", { spells = { { "Target_SpiritualWeapon", "Target_SpiritualWeapon_Cleric" }, { "Shout_Aid", "Target_Aid" } }, label = "Spiritual Weapon, Aid" }),
        step(4, "cleric-wis-4", { boosts = { "Ability(Wisdom,2)" }, label = "+2 Wisdom" }),
        step(5, "cleric-spells-5", { spells = { { "Shout_SpiritGuardians" }, { "Target_Revivify" }, { "Shout_MassHealingWord", "Target_MassHealingWord" } }, label = "Spirit Guardians, Revivify, Mass Healing Word" }),
        step(7, "cleric-spells-7", { spells = { { "Target_Banishment" }, { "Target_GuardianOfFaith" } }, label = "Banishment, Guardian of Faith" }),
        step(8, "cleric-wis-8", { boosts = { "Ability(Wisdom,2)" }, label = "+2 Wisdom" }),
        step(12, "cleric-alert", { passives = { { "Alert" } }, label = "Alert" }),
    },
    Wizard = {
        step(1, "wizard-spells-1", { spells = { { "Projectile_MagicMissile" }, { "Shout_Shield_Wizard", "Target_Shield_Wizard", "Shout_Shield" } }, label = "Magic Missile, Shield" }),
        step(3, "wizard-spells-3", { spells = { { "Target_MistyStep" }, { "Target_HoldPerson" }, { "Projectile_ScorchingRay" } }, label = "Misty Step, Hold Person, Scorching Ray" }),
        step(4, "wizard-int-4", { boosts = { "Ability(Intelligence,2)" }, label = "+2 Intelligence" }),
        step(5, "wizard-spells-5", { spells = { { "Projectile_Fireball" }, { "Target_Haste" }, { "Target_Counterspell" } }, label = "Fireball, Haste, Counterspell" }),
        step(7, "wizard-spells-7", { spells = { { "Target_GreaterInvisibility" }, { "Target_Banishment" } }, label = "Greater Invisibility, Banishment" }),
        step(8, "wizard-int-8", { boosts = { "Ability(Intelligence,2)" }, label = "+2 Intelligence" }),
        step(9, "wizard-spells-9", { spells = { { "Cone_ConeOfCold", "Target_ConeOfCold" } }, label = "Cone of Cold" }),
        step(11, "wizard-spells-11", { spells = { { "Projectile_ChainLightning", "Target_ChainLightning" }, { "Projectile_Disintegrate", "Target_Disintegrate" } }, label = "Chain Lightning, Disintegrate" }),
        step(12, "wizard-alert", { passives = { { "Alert" } }, label = "Alert" }),
    },
    Rogue = {
        step(4, "rogue-dex-4", { boosts = { "Ability(Dexterity,2)" }, label = "+2 Dexterity" }),
        step(8, "rogue-dex-8", { boosts = { "Ability(Dexterity,2)" }, label = "+2 Dexterity" }),
        step(10, "rogue-alert", { passives = { { "Alert" } }, label = "Alert" }),
        step(12, "rogue-sharpshooter", { passives = { { "Sharpshooter_AllIn" }, { "Sharpshooter_Bonuses" } }, label = "Sharpshooter" }),
    },
    Ranger = {
        step(1, "ranger-spells-1", { spells = { { "Target_HuntersMark" } }, label = "Hunter's Mark" }),
        step(4, "ranger-sharpshooter", { passives = { { "Sharpshooter_AllIn" }, { "Sharpshooter_Bonuses" } }, label = "Sharpshooter" }),
        step(5, "ranger-spells-5", { spells = { { "Shout_PassWithoutTrace", "Target_PassWithoutTrace" }, { "Target_CureWounds" } }, label = "Pass Without Trace, Cure Wounds" }),
        step(8, "ranger-dex-8", { boosts = { "Ability(Dexterity,2)" }, label = "+2 Dexterity" }),
        step(12, "ranger-alert", { passives = { { "Alert" } }, label = "Alert" }),
    },
}

-- Steps the character has reached but not yet received.
function AutoKit.pendingSteps(className, level, applied)
    applied = applied or {}
    local result = {}
    for _, entry in ipairs(AutoKit.BUILDS[className] or {}) do
        if entry.level <= (tonumber(level) or 0) and not applied[entry.id] then
            table.insert(result, entry)
        end
    end
    return result
end

return AutoKit
