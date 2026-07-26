local Fixtures = {}

local BY_LEVEL = {
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
    },
}

function Fixtures.get(level)
    return BY_LEVEL[level]
end

function Fixtures.levels()
    return { 5, 8, 10 }
end

return Fixtures
