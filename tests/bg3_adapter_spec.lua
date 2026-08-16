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
