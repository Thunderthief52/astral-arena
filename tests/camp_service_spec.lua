local H = require("tests.test_helper")

local previousExt = _G.Ext
_G.Ext = {
    Require = function(path)
        return require((path:gsub("%.lua$", ""):gsub("/", ".")))
    end,
}
local CampService = require("AstralArena.Server.CampService")
local Catalog = require("AstralArena.Shared.HirelingCatalog")
_G.Ext = previousExt

local function fixture()
    local state
    local members = {
        { guid = "player-a", name = "Player A", userId = 0, level = 3, isAvatar = true },
        { guid = "player-b", name = "Player B", userId = 1, level = 3, isAvatar = true },
    }
    local gold = { ["player-a"] = 0, ["player-b"] = 0 }
    local adapter = { menus = {}, notifications = {}, hires = {} }
    function adapter.partyMembers() return members end
    function adapter.ensureCampService()
        error("automatic onboarding must never spawn campaign world entities")
    end
    function adapter.addGold(guid, amount) gold[guid] = (gold[guid] or 0) + amount end
    function adapter.getGold(guid) return gold[guid] or 0 end
    function adapter.notify(guid, message) table.insert(adapter.notifications, { guid, message }) end
    function adapter.menuOwner() return "player-a" end
    function adapter.openYesNo(guid, key, message)
        table.insert(adapter.menus, { guid = guid, key = key, message = message })
    end
    function adapter.hireFollower(candidate, _, level, callback)
        table.insert(adapter.hires, { candidate = candidate, level = level })
        table.insert(members, {
            guid = candidate.characterGuid,
            name = candidate.displayName,
            level = level,
            isAvatar = false,
        })
        callback(true)
    end
    local persistence = {}
    function persistence.LoadOrCreate()
        state = state or {
            schemaVersion = 1,
            fundedCharacters = {},
            hiredCharacters = {},
            onboardingComplete = false,
        }
        return state
    end
    function persistence.Save(value) state = value end
    local output = {}
    local service = CampService.new(adapter, function(message) table.insert(output, message) end, Catalog, persistence)
    return service, adapter, members, gold, function() return state end, output
end

H.test("arena camp grants each avatar starting gold exactly once without spawning world entities", function()
    local service, adapter, members, gold = fixture()
    service:ensureCamp(members)
    service:ensureCamp(members)
    H.equal(gold["player-a"], 300)
    H.equal(gold["player-b"], 300)
    H.equal(#adapter.notifications, 2)
end)

H.test("Withers onboarding hires level-matched followers and stops at four", function()
    local service, adapter, members, gold, getState = fixture()
    H.equal(service:prepareOnboarding(members, 3), "waiting")
    H.truthy(adapter.menus[1].message:find("Eldra Luthrinn", 1, true) ~= nil)
    service:handleMenuResponse("player-a", adapter.menus[1].key, 1)
    H.equal(#members, 3)
    H.equal(gold["player-a"], 200)
    H.equal(adapter.hires[1].level, 3)
    local secondMenu = adapter.menus[#adapter.menus]
    H.truthy(secondMenu.message:find("Zenith Feur'sel", 1, true) ~= nil)
    service:handleMenuResponse("player-a", secondMenu.key, true)
    H.equal(#members, 4)
    H.equal(gold["player-a"], 100)
    H.truthy(getState().onboardingComplete)
    H.truthy(service:recruitedCharacters()[Catalog[1].characterGuid])
    H.truthy(service:recruitedCharacters()[Catalog[2].characterGuid])
end)

H.test("declining Withers candidates eventually releases automatic progression", function()
    local service, adapter, members, _, getState = fixture()
    service:prepareOnboarding(members, 3)
    for _ = 1, #Catalog do
        local menu = adapter.menus[#adapter.menus]
        service:handleMenuResponse("player-a", menu.key, 0)
    end
    H.truthy(getState().onboardingComplete)
    H.equal(service:prepareOnboarding(members, 3), "ready")
end)

H.test("a failed hire refunds its gold", function()
    local service, adapter, members, gold = fixture()
    adapter.hireFollower = function(_, _, _, callback) callback(false, "no summon") end
    service:prepareOnboarding(members, 3)
    local menu = adapter.menus[#adapter.menus]
    service:handleMenuResponse("player-a", menu.key, 1)
    H.equal(gold["player-a"], 300)
end)
