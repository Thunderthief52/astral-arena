local Constants = Ext.Require("AstralArena/Shared/Constants.lua")

local CampService = {}
CampService.__index = CampService

local STARTING_GOLD = 300
local HIRELING_COST = 100
local MAX_PARTY_SIZE = 4

local function menuResultIsYes(result)
    return result == true or result == 1 or result == "1"
end

local function isAvatar(member)
    -- Test adapters and old saves may not expose UserAvatar yet. A reserved
    -- player user id remains a safe fallback and excludes native hirelings.
    if member.isAvatar ~= nil then
        return member.isAvatar == true
    end
    return type(member.userId) == "number" and member.userId >= 0 and member.userId < 65535
end

function CampService.new(adapter, output, catalog, persistence)
    return setmetatable({
        adapter = adapter,
        output = output,
        catalog = catalog,
        persistence = persistence,
        menu = nil,
        pending = false,
    }, CampService)
end

function CampService:_state()
    return self.persistence.LoadOrCreate()
end

function CampService:_save(state)
    self.persistence.Save(state)
end

function CampService:ensureCamp(members)
    if type(members) ~= "table" or not members[1] then
        return false
    end
    local state = self:_state()
    local changed = false
    -- Never clone campaign NPC or item templates into the Adventure at runtime.
    -- BG3 attaches their campaign story components during EnteredLevel and may
    -- terminate before onboarding opens. The menu provides the hiring service
    -- without creating any world entities.
    for _, member in ipairs(members) do
        if isAvatar(member) and not state.fundedCharacters[member.guid] then
            self.adapter.addGold(member.guid, STARTING_GOLD)
            state.fundedCharacters[member.guid] = true
            changed = true
            self.adapter.notify(member.guid, "Withers has advanced you 300 gold for arena hirelings.")
        end
    end
    if changed then
        self:_save(state)
    end
    return true
end

function CampService:_nextCandidate(startIndex)
    local state = self:_state()
    for index = startIndex or 1, #self.catalog do
        local candidate = self.catalog[index]
        if not state.hiredCharacters[candidate.characterGuid] then
            return index, candidate
        end
    end
    return nil, nil
end

function CampService:_completeMenu()
    local state = self:_state()
    state.onboardingComplete = true
    self:_save(state)
    self.menu = nil
    self.output("Withers closes the ledger. Astral Arena progression may continue.")
end

function CampService:_showMenu()
    local menu = self.menu
    if not menu then
        return false
    end
    local members = self.adapter.partyMembers()
    if #members >= MAX_PARTY_SIZE then
        self:_completeMenu()
        return false
    end
    local index, candidate = self:_nextCandidate(menu.candidateIndex)
    if not candidate then
        self:_completeMenu()
        return false
    end
    menu.candidateIndex = index
    menu.candidate = candidate
    menu.messageKey = Constants.MenuMessages.hireling
    local remaining = #self.catalog - index
    local tail = remaining > 0
        and "Choose No to view another class."
        or "Choose No to close the ledger and continue to the arena."
    local message = string.format(
        "WITHERS' LEDGER — Hire %s, %s, for %d gold? Party: %d/%d. Your gold: %d. %s",
        candidate.displayName,
        candidate.className,
        HIRELING_COST,
        #members,
        MAX_PARTY_SIZE,
        self.adapter.getGold(menu.ownerGuid),
        tail
    )
    self.adapter.openYesNo(menu.ownerGuid, menu.messageKey, message)
    return true
end

function CampService:open(characterGuid, startIndex)
    if self.pending then
        self.adapter.notify(characterGuid, "Withers is completing the current summons.")
        return false
    end
    local members = self.adapter.partyMembers()
    self.onboardingLevel = members[1] and members[1].level or self.onboardingLevel
    if #members >= MAX_PARTY_SIZE then
        self.adapter.notify(characterGuid, "Your party already has four members.")
        return false
    end
    self.menu = {
        ownerGuid = characterGuid,
        candidateIndex = startIndex or 1,
    }
    return self:_showMenu()
end

function CampService:prepareOnboarding(members, level)
    self:ensureCamp(members)
    local state = self:_state()
    if state.onboardingComplete or #members >= MAX_PARTY_SIZE then
        if not state.onboardingComplete then
            state.onboardingComplete = true
            self:_save(state)
        end
        return "ready"
    end
    if self.pending or self.menu then
        return "waiting"
    end
    self.onboardingLevel = level
    self:open(self.adapter.menuOwner(members), 1)
    return "waiting"
end

function CampService:handleMenuResponse(characterGuid, messageKey, result)
    local menu = self.menu
    if not menu or characterGuid ~= menu.ownerGuid or messageKey ~= menu.messageKey then
        return false
    end
    local candidate = menu.candidate
    if not menuResultIsYes(result) then
        menu.candidateIndex = menu.candidateIndex + 1
        self:_showMenu()
        return true
    end
    if self.adapter.getGold(characterGuid) < HIRELING_COST then
        self.adapter.notify(characterGuid, "Withers requires 100 gold. Choose another buyer or return later.")
        menu.candidateIndex = menu.candidateIndex + 1
        self:_showMenu()
        return true
    end

    local level = self.onboardingLevel
    if not level then
        local members = self.adapter.partyMembers()
        level = members[1] and members[1].level or 3
    end
    self.adapter.addGold(characterGuid, -HIRELING_COST)
    self.pending = true
    self.menu = nil
    self.adapter.hireFollower(candidate, characterGuid, level, function(success, reason)
        self.pending = false
        local state = self:_state()
        if success then
            state.hiredCharacters[candidate.characterGuid] = true
            self:_save(state)
            self.output(string.format("Withers recruited %s (%s) at level %d.", candidate.displayName, candidate.className, level))
            self.adapter.notify(characterGuid, candidate.displayName .. " has joined the arena party.")
        else
            self.adapter.addGold(characterGuid, HIRELING_COST)
            self.adapter.notify(characterGuid, "The summons failed; Withers returned your 100 gold.")
            self.output("Hireling summons failed: " .. tostring(reason or "unknown engine error"))
        end
        local members = self.adapter.partyMembers()
        if #members >= MAX_PARTY_SIZE then
            self:_completeMenu()
        else
            self:open(characterGuid, menu.candidateIndex + 1)
        end
    end)
    return true
end

return CampService
