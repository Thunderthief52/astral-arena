local Fixtures = {}

local BY_LEVEL = {
    [3] = {
        id = "astral-initiation",
        displayName = "Astral Initiates",
        level = 3,
        members = {
            { id = "gish", displayName = "Initiate Spellblade", role = "gish", templateId = "9a8b2d7f-e1a3-456a-8c66-c362cb6d1539" },
            { id = "raider", displayName = "Initiate Archer", role = "ranged", templateId = "74672dc8-497c-4d9c-92b7-7347ab643e43" },
            { id = "warrior", displayName = "Initiate Warrior", role = "frontline", templateId = "814b1e10-eafc-4739-9b17-7a8a4e99be9f" },
        },
        selectionOrder = { "warrior", "raider", "gish" },
        waveOrders = {
            { "warrior", "raider", "gish" },
            { "gish", "raider", "warrior" },
        },
    },
    [5] = {
        id = "astral-vanguard",
        displayName = "Astral Vanguard",
        level = 5,
        members = {
            { id = "devastator", displayName = "Vanguard Devastator", role = "caster", templateId = "52540830-11e2-4f7a-9647-f2b84aa3d7d7" },
            { id = "gish", displayName = "Vanguard Gish", role = "gish", templateId = "9a8b2d7f-e1a3-456a-8c66-c362cb6d1539" },
            { id = "raider", displayName = "Vanguard Raider", role = "ranged", templateId = "74672dc8-497c-4d9c-92b7-7347ab643e43" },
            { id = "warrior", displayName = "Vanguard Warrior", role = "frontline", templateId = "814b1e10-eafc-4739-9b17-7a8a4e99be9f" },
        },
        selectionOrder = { "warrior", "raider", "gish", "devastator" },
        waveOrders = {
            { "warrior", "raider", "gish", "devastator" },
            { "gish", "devastator", "warrior", "raider" },
        },
    },
    [8] = {
        id = "astral-bastion",
        displayName = "Astral Bastion",
        level = 8,
        members = {
            { id = "ranger", displayName = "Bastion Ranger", role = "ranged", templateId = "4b5f8dbe-04c4-4d0c-a8ac-a1366ca3d49e" },
            { id = "defender-a", displayName = "Bastion Defender", role = "frontline", templateId = "13f41c47-7fbc-4dd2-a9a4-8873e9e84221" },
            { id = "attacker", displayName = "Bastion Attacker", role = "striker", templateId = "254d5482-1788-4f2c-8e07-e5357eb44719" },
            { id = "defender-b", displayName = "Bastion Shield", role = "frontline", templateId = "3423bf45-3295-43d7-843b-fe0be417dc31" },
        },
        selectionOrder = { "defender-a", "ranger", "attacker", "defender-b" },
        waveOrders = {
            { "defender-a", "ranger", "attacker", "defender-b" },
            { "defender-b", "attacker", "ranger", "defender-a" },
            { "defender-a", "attacker", "defender-b", "ranger" },
        },
    },
    [10] = {
        id = "astral-judicators",
        displayName = "Astral Judicators",
        level = 10,
        members = {
            { id = "fist-a", displayName = "Judicator Fist", role = "frontline", templateId = "99361f29-697d-414e-b927-16d5fdff093b" },
            { id = "fist-b", displayName = "Judicator Enforcer", role = "frontline", templateId = "d1d7c7a6-2d8a-4632-9ae6-0a201876a1b2" },
            { id = "cleric", displayName = "Judicator Cleric", role = "support", templateId = "2774a43e-db7a-49d4-90b2-e07097b0b531" },
            { id = "caster", displayName = "Judicator Caster", role = "caster", templateId = "1a80541e-f990-4a07-ba08-008b9992f7be" },
        },
        selectionOrder = { "fist-a", "caster", "cleric", "fist-b" },
        waveOrders = {
            { "fist-a", "caster", "cleric", "fist-b" },
            { "fist-b", "cleric", "caster", "fist-a" },
            { "fist-a", "cleric", "fist-b", "caster" },
        },
    },
    [12] = {
        id = "astral-exarchs",
        displayName = "Astral Exarchs",
        level = 12,
        members = {
            { id = "blade", displayName = "Exarch Blade", role = "frontline", templateId = "99361f29-697d-414e-b927-16d5fdff093b" },
            { id = "oracle", displayName = "Exarch Oracle", role = "support", templateId = "2774a43e-db7a-49d4-90b2-e07097b0b531" },
            { id = "weaver", displayName = "Exarch Weaver", role = "caster", templateId = "1a80541e-f990-4a07-ba08-008b9992f7be" },
            { id = "executioner", displayName = "Exarch Executioner", role = "striker", templateId = "254d5482-1788-4f2c-8e07-e5357eb44719" },
        },
        selectionOrder = { "blade", "oracle", "weaver", "executioner" },
        waveOrders = {
            { "blade", "oracle", "weaver", "executioner" },
            { "executioner", "weaver", "blade", "oracle" },
            { "oracle", "blade", "executioner", "weaver" },
            { "weaver", "executioner", "oracle", "blade" },
        },
    },
}

function Fixtures.get(level)
    return BY_LEVEL[level]
end

function Fixtures.forWave(level, partySize, waveIndex)
    local fixture = BY_LEVEL[level]
    if not fixture then
        return nil
    end

    partySize = math.max(1, math.floor(tonumber(partySize) or 1))
    waveIndex = math.floor(tonumber(waveIndex) or 1)
    if waveIndex < 1 or waveIndex > #(fixture.waveOrders or {}) then
        error(string.format("fixture level %d does not define wave %d", level, waveIndex), 2)
    end
    local memberCount = math.min(#fixture.members, partySize)
    local byId = {}
    for _, member in ipairs(fixture.members) do
        byId[member.id] = member
    end

    local members = {}
    local selectionOrder = fixture.waveOrders[waveIndex] or fixture.selectionOrder or {}
    for _, memberId in ipairs(selectionOrder) do
        if #members >= memberCount then
            break
        end
        if byId[memberId] then
            table.insert(members, byId[memberId])
        end
    end
    if #members < memberCount then
        for _, member in ipairs(fixture.members) do
            if #members >= memberCount then
                break
            end
            local alreadySelected = false
            for _, selected in ipairs(members) do
                alreadySelected = alreadySelected or selected.id == member.id
            end
            if not alreadySelected then
                table.insert(members, member)
            end
        end
    end

    local scaled = {}
    for key, value in pairs(fixture) do
        if key ~= "members" then
            scaled[key] = value
        end
    end
    scaled.members = members
    scaled.fullMemberCount = #fixture.members
    scaled.partySize = partySize
    scaled.waveIndex = waveIndex
    scaled.waveCount = #(fixture.waveOrders or {})
    return scaled
end

function Fixtures.forPartySize(level, partySize)
    return Fixtures.forWave(level, partySize, 1)
end

function Fixtures.waveCount(level)
    local fixture = BY_LEVEL[level]
    return fixture and #(fixture.waveOrders or {}) or 0
end

function Fixtures.levels()
    return { 3, 5, 8, 10, 12 }
end

return Fixtures
