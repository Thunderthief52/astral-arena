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
    { guid = "player-a", name = "Player A", isAvatar = true },
    { guid = "player-b", name = "Player B", isAvatar = true },
}

H.test("a packaged menu opens without a runtime localization override", function()
    local previousExt, previousOsi = _G.Ext, _G.Osi
    local opened
    _G.Ext = { Loca = {
        GetTranslatedString = function() return "Packaged readable text" end,
        UpdateTranslatedString = function() error("must use packaged text") end,
    } }
    _G.Osi = { OpenMessageBoxYesNo = function(guid, key) opened = { guid, key } end }
    local ok, err = pcall(Adapter.openYesNo, "player-a", "hpackaged")
    _G.Ext, _G.Osi = previousExt, previousOsi
    H.truthy(ok, err)
    H.equal(opened[1], "player-a")
    H.equal(opened[2], "Packaged readable text")
    H.equal(Adapter.resolveMessageKey(opened[2]), "hpackaged")
end)

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

H.test("party XP award levels a recruited follower without avatar experience data", function()
    local previousExt = _G.Ext
    local previousOsi = _G.Osi
    local setLevel
    local autoLevelled
    _G.Ext = { Entity = { Get = function() return nil end } }
    _G.Osi = {
        GetLevel = function() return 1 end,
        SetLevel = function(guid, level) setLevel = { guid, level } end,
        RequestAutoLevel = function(guid) autoLevelled = guid end,
    }
    local awarded = Adapter.awardPartyToLevel({
        { guid = "hireling", name = "Hireling", level = 1, isAvatar = false },
    }, 3)
    _G.Ext = previousExt
    _G.Osi = previousOsi
    H.equal(awarded, 1)
    H.equal(setLevel[1], "hireling")
    H.equal(setLevel[2], 3)
    H.equal(autoLevelled, "hireling")
end)

H.test("auto-level survives an engine without the auto-level call", function()
    local previousExt = _G.Ext
    local previousOsi = _G.Osi
    local setLevel
    _G.Ext = {}
    _G.Osi = { SetLevel = function(guid, level) setLevel = { guid, level } end }
    Adapter.autoLevel("hireling", 5)
    _G.Ext = previousExt
    _G.Osi = previousOsi
    H.equal(setLevel[2], 5)
end)

H.test("arena menu targets the host avatar when it is in the party", function()
    local previousOsi = _G.Osi
    _G.Osi = { GetHostCharacter = function() return "player-b" end }
    local owner = Adapter.menuOwner(members)
    _G.Osi = previousOsi
    H.equal(owner, "player-b")
end)

H.test("arena menu sends readable text and maps the native response back to its key", function()
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
    H.equal(updated, nil)
    H.equal(opened[1], "player-a")
    H.equal(opened[2], "Retry?")
    H.equal(Adapter.resolveMessageKey("Retry?"), "hmenu")
    H.equal(Adapter.resolveMessageKey("hmenu"), "hmenu")
end)

H.test("unresolved localization handles never appear as prompt text", function()
    local previousExt, previousOsi = _G.Ext, _G.Osi
    local opened=false
    _G.Ext={Loca={GetTranslatedString=function(handle) return handle end}}
    _G.Osi={OpenMessageBoxYesNo=function() opened=true end}
    local ok=pcall(Adapter.openYesNo,"player-a","hunresolved")
    _G.Ext, _G.Osi=previousExt, previousOsi
    H.equal(ok,false)
    H.equal(opened,false)
end)

H.test("the ready action is granted to each party member", function()
    local previousOsi=_G.Osi
    local grants={}
    _G.Osi={AddSpell=function(guid,spell) table.insert(grants,guid .. ":" .. spell) end}
    Adapter.grantReadyAction(members)
    _G.Osi=previousOsi
    H.equal(grants[1],"player-a:Shout_AA_Ready")
    H.equal(grants[2],"player-b:Shout_AA_Ready")
end)

H.test("reward snapshots include nested bags, stack amounts and normalized template UUIDs", function()
    local previousExt,previousOsi=_G.Ext,_G.Osi
    local template="AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    local function owner(item)
        return {InventoryOwner={Inventories={{InventoryContainer={Items={{Item={Uuid={EntityUuid=item}}}}}}}}}
    end
    _G.Ext={Entity={Get=function(guid)
        if guid=="player-a" then return owner("bag") end
        if guid=="bag" then return owner("scroll") end
    end}}
    _G.Osi={GetTemplate=function(item) return item=="scroll" and "OBJ_Scroll_" .. template or "bag-template" end,
        GetStackAmount=function(item) return item=="scroll" and 7 or 1 end}
    local result=Adapter.rewardInventorySnapshot("player-a")
    _G.Ext,_G.Osi=previousExt,previousOsi
    H.equal(result.scroll.templateId,template:lower())
    H.equal(result.scroll.amount,7)
    H.equal(result.bag.amount,1)
end)

H.test("arena downing preserves native death saves without blocking lethal attacks", function()
    local previousExt = _G.Ext
    local previousOsi = _G.Osi
    local addedPassive
    local applied = 0
    _G.Ext = { Utils = { PrintWarning = function() end } }
    _G.Osi = {
        HasPassive = function() return 0 end,
        AddPassive = function(_, passive) addedPassive = passive end,
        ApplyStatus = function() applied = applied + 1 end,
    }
    Adapter.markDefeated("fighter")
    _G.Ext = previousExt
    _G.Osi = previousOsi
    H.equal(addedPassive, "DeathSavingThrows")
    H.equal(applied, 0)
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

H.test("a recovered death-save combatant needs no arena protection cleanup", function()
    local previousExt = _G.Ext
    local previousOsi = _G.Osi
    local removed = 0
    _G.Ext = { Utils = { PrintWarning = function() end } }
    _G.Osi = {
        HasPassive = function() return 1 end,
        RemoveStatus = function() removed = removed + 1 end,
    }
    Adapter.markRecovered("fighter")
    _G.Ext = previousExt
    _G.Osi = previousOsi
    H.equal(removed, 0)
end)

H.test("between-wave cleanup preserves a dead player for manual resurrection", function()
    local previousExt = _G.Ext
    local previousOsi = _G.Osi
    local resurrected = 0
    local healed = 0
    local downedRemoved = 0
    _G.Ext = { Utils = { PrintWarning = function() end } }
    _G.Osi = {
        LeaveCombat = function() end,
        ClearIndividualRelation = function() end,
        RemoveStatus = function() end,
        IsDead = function() return 1 end,
        Resurrect = function() resurrected = resurrected + 1 end,
        SetHitpointsPercentage = function() healed = healed + 1 end,
        RemoveStatusesWithType = function() downedRemoved = downedRemoved + 1 end,
        HasPassive = function() return 1 end,
    }
    local result = Adapter.recoverBetweenWaves({ guid = "fighter" }, { enemy = true })
    _G.Ext = previousExt
    _G.Osi = previousOsi
    H.truthy(result.dead)
    H.equal(result.alive, false)
    H.equal(resurrected, 0)
    H.equal(healed, 0)
    H.equal(downedRemoved, 0)
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

H.test("preparation bundle gives every avatar supplies, revival scrolls, and a complete personal kit", function()
    local previousExt = _G.Ext
    local previousOsi = _G.Osi
    local previousRandomIndex = Adapter.randomIndex
    local generated = {}
    local items = {}
    _G.Ext = {
        Template = {
            GetRootTemplate = function()
                return { TemplateType = "item" }
            end,
        },
    }
    _G.Osi = {
        GenerateTreasure = function(guid, tableId, level)
            table.insert(generated, { guid = guid, tableId = tableId, level = level })
        end,
        TemplateAddTo = function(templateId, guid)
            table.insert(items, templateId .. ":" .. guid)
        end,
    }
    Adapter.randomIndex = function(maximum)
        return maximum
    end
    local delivered = Adapter.deliverPreparationBundle(members, 3, {
        { id = "weapon", templateId = "weapon-template", minimumLevel = 3, maximumLevel = 8 },
        { id = "armor", templateId = "armor-template", minimumLevel = 3, maximumLevel = 8 },
        { id = "too-late", templateId = "late-template", minimumLevel = 8 },
    })
    Adapter.randomIndex = previousRandomIndex
    _G.Ext = previousExt
    _G.Osi = previousOsi
    H.equal(delivered.treasureRolls, 12)
    H.equal(delivered.armoryItems, 22)
    H.equal(delivered.revivifyScrolls, 4)
    H.equal(#generated, 12)
    H.equal(generated[1].tableId, "RewardMedium")
    H.equal(generated[1].level, 3)
    H.equal(generated[7].guid, "player-b")
    H.equal(items[1], "c1c3e4fb-d68c-4e10-afdc-d4550238d50e:player-a")
    H.equal(items[2], "c1c3e4fb-d68c-4e10-afdc-d4550238d50e:player-b")
    H.equal(#items, 24)
    H.truthy(items[3]:find(":player-a", 1, true) ~= nil)
    H.truthy(items[4]:find(":player-b", 1, true) ~= nil)
    H.truthy(items[3]:match("^[^:]+") ~= items[4]:match("^[^:]+"), "the first randomized slot should differ across avatars")
end)
