local H = require("tests.test_helper")
local Adapter = require("AstralArena.Server.Bg3Adapter")

local function withExperienceMode(mode, test)
    local previousExt = _G.Ext
    local previousOsi = _G.Osi
    local experience = { ["player-a"] = 0, ["player-b"] = 0 }
    local levels = { ["player-a"] = 1, ["player-b"] = 1 }
    local calls = {}

    _G.Ext = {
        Entity = {
            Get = function(guid)
                return { Experience = { TotalExperience = experience[guid] } }
            end,
        },
    }
    _G.Osi = {
        GetLevel = function(guid)
            return levels[guid]
        end,
        AddExplorationExperience = function(guid, gain)
            table.insert(calls, { guid = guid, gain = gain })
            if mode == "party-wide" then
                for memberGuid in pairs(experience) do
                    experience[memberGuid] = experience[memberGuid] + gain
                end
            else
                experience[guid] = experience[guid] + gain
            end
        end,
    }

    local ok, err = pcall(test, experience, calls, levels)
    _G.Ext = previousExt
    _G.Osi = previousOsi
    if not ok then error(err, 0) end
end

local members = {
    { guid = "player-a", name = "Player A" },
    { guid = "player-b", name = "Player B" },
}

H.test("party XP award reaches independently owned split-screen avatars", function()
    withExperienceMode("per-avatar", function(experience, calls)
        local awarded = Adapter.awardPartyToLevel(members, 5)
        H.equal(experience["player-a"], 6500)
        H.equal(experience["player-b"], 6500)
        H.equal(#calls, 2)
        H.equal(awarded, 2)
    end)
end)

H.test("party XP award accepts a character still completing native level-up choices", function()
    withExperienceMode("per-avatar", function(experience, calls)
        experience["player-a"] = 6500
        local awarded = Adapter.awardPartyToLevel(members, 5)
        H.equal(experience["player-a"], 6500)
        H.equal(experience["player-b"], 6500)
        H.equal(#calls, 1)
        H.equal(calls[1].guid, "player-b")
        H.equal(awarded, 1)
    end)
end)

H.test("party XP award does not multiply ordinary party-wide experience", function()
    withExperienceMode("party-wide", function(experience, calls)
        local awarded = Adapter.awardPartyToLevel(members, 5)
        H.equal(experience["player-a"], 6500)
        H.equal(experience["player-b"], 6500)
        H.equal(#calls, 1)
        H.equal(awarded, 1)
    end)
end)

H.test("arena menu targets the host avatar when it is in the party", function()
    local previousOsi = _G.Osi
    _G.Osi = { GetHostCharacter = function() return "player-b" end }
    local owner = Adapter.menuOwner(members)
    _G.Osi = previousOsi
    H.equal(owner, "player-b")
end)

H.test("arena menu opens a native localized yes-no prompt", function()
    local previousExt = _G.Ext
    local previousOsi = _G.Osi
    local updated
    local opened
    _G.Ext = {
        Loca = {
            UpdateTranslatedString = function(key, message)
                updated = { key, message }
                return true
            end,
        },
        Utils = { PrintWarning = function() end },
    }
    _G.Osi = {
        OpenMessageBoxYesNo = function(guid, key)
            opened = { guid, key }
        end,
    }
    Adapter.openYesNo("player-a", "hmenu", "Retry?")
    _G.Ext = previousExt
    _G.Osi = previousOsi
    H.equal(updated[1], "hmenu")
    H.equal(updated[2], "Retry?")
    H.equal(opened[1], "player-a")
    H.equal(opened[2], "hmenu")
end)

H.test("arena downing preserves native death saves and blocks AI farming", function()
    local previousExt = _G.Ext
    local previousOsi = _G.Osi
    local calls = {}
    _G.Ext = { Utils = { PrintWarning = function() end } }
    _G.Osi = {
        ApplyStatus = function(guid, status) table.insert(calls, "status:" .. guid .. ":" .. status) end,
    }
    Adapter.markDefeated("fighter")
    _G.Ext = previousExt
    _G.Osi = previousOsi
    H.equal(calls[1], "status:fighter:INVULNERABLE_NOT_SHOWN")
    H.equal(#calls, 1)
end)

H.test("arena preparation enables death saves and allows zero-hit-point downing", function()
    local previousExt = _G.Ext
    local previousOsi = _G.Osi
    local immortal
    local addedPassive
    _G.Ext = { Utils = { PrintWarning = function() end } }
    _G.Osi = {
        RemoveStatusesWithType = function() end,
        RemoveStatus = function() end,
        SetCanFight = function() end,
        SetCanJoinCombat = function() end,
        SetImmortal = function(_, value) immortal = value end,
        IsDead = function() return 0 end,
        HasPassive = function() return 0 end,
        AddPassive = function(_, passive) addedPassive = passive end,
        PROC_CharacterFullRestore = function() end,
    }
    Adapter.prepareCharacter("fighter")
    _G.Ext = previousExt
    _G.Osi = previousOsi
    H.equal(immortal, 0)
    H.equal(addedPassive, "DeathSavingThrows")
end)

H.test("one hit point still fights but zero hit points is downed", function()
    local previousOsi = _G.Osi
    local hitpoints = 1
    _G.Osi = {
        IsDead = function() return 0 end,
        GetHitpoints = function() return hitpoints end,
    }
    H.truthy(Adapter.isAlive("fighter"))
    hitpoints = 0
    H.equal(Adapter.isAlive("fighter"), false)
    _G.Osi = previousOsi
end)

H.test("a recovered death-save combatant loses temporary protection", function()
    local previousExt = _G.Ext
    local previousOsi = _G.Osi
    local removed
    _G.Ext = { Utils = { PrintWarning = function() end } }
    _G.Osi = {
        RemoveStatus = function(guid, status)
            removed = guid .. ":" .. status
        end,
    }
    Adapter.markRecovered("fighter")
    _G.Ext = previousExt
    _G.Osi = previousOsi
    H.equal(removed, "fighter:INVULNERABLE_NOT_SHOWN")
end)

H.test("between-round recovery invokes party restore and refreshes every avatar", function()
    local previousExt = _G.Ext
    local previousOsi = _G.Osi
    local restoredParty
    local refreshed = {}
    _G.Ext = { Utils = { PrintWarning = function() end } }
    _G.Osi = {
        RestoreParty = function(guid) restoredParty = guid end,
        PROC_CharacterFullRestore = function(guid) table.insert(refreshed, "full:" .. guid) end,
        ResetCooldowns = function(guid) table.insert(refreshed, "cooldown:" .. guid) end,
    }
    Adapter.fullRestParty(members)
    _G.Ext = previousExt
    _G.Osi = previousOsi
    H.equal(restoredParty, "player-a")
    H.equal(#refreshed, 4)
end)

H.test("victory bundle gives four loot rolls per avatar and distributes six rares", function()
    local previousExt = _G.Ext
    local previousOsi = _G.Osi
    local generated = 0
    local items = {}
    _G.Ext = {
        Template = {
            GetRootTemplate = function()
                return { TemplateType = "item" }
            end,
        },
    }
    _G.Osi = {
        GenerateTreasure = function() generated = generated + 1 end,
        TemplateAddTo = function(templateId, recipient)
            table.insert(items, templateId .. ":" .. recipient)
        end,
    }
    local choices = {}
    for index = 1, 6 do
        table.insert(choices, { templateId = "item-" .. index })
    end
    local result = Adapter.deliverVictoryBundle({
        level = 8,
        automatic = { treasureTableId = "RewardMedium", rolls = 2 },
        choices = choices,
    }, members)
    _G.Ext = previousExt
    _G.Osi = previousOsi
    H.equal(generated, 8)
    H.equal(result.treasureRolls, 8)
    H.equal(result.rareItems, 6)
    H.equal(items[1], "item-1:player-a")
    H.equal(items[2], "item-2:player-b")
    H.equal(items[6], "item-6:player-b")
end)
