local H = require("tests.test_helper")

local previousExt = _G.Ext
_G.Ext = {
    Require = function(path)
        return require((path:gsub("%.lua$", ""):gsub("/", ".")))
    end,
}
local Sparring = require("AstralArena.Server.Sparring")
_G.Ext = previousExt

local function fakeAdapter()
    local adapter = {
        alive = { left = true, right = true },
        scheduled = nil,
        prepared = {},
        restored = {},
        defeated = {},
        hostilePairs = 0,
        combatPairs = 0,
        notifications = {},
        queue = {},
    }

    function adapter.partyMembers()
        return {
            { guid = "left", name = "Left", userId = 0, level = 5, faction = "faction-left" },
            { guid = "right", name = "Right", userId = 1, level = 5, faction = "faction-right" },
        }
    end

    function adapter.prepareCharacter(guid)
        if adapter.failPreparation then
            error("engine refused setup")
        end
        table.insert(adapter.prepared, guid)
    end

    function adapter.makeHostile()
        adapter.hostilePairs = adapter.hostilePairs + 1
    end

    function adapter.enterCombat()
        adapter.combatPairs = adapter.combatPairs + 1
    end

    function adapter.isAlive(guid)
        return adapter.alive[guid]
    end

    function adapter.markDefeated(guid)
        adapter.defeated[guid] = true
    end

    function adapter.restoreCharacter(member)
        table.insert(adapter.restored, member.guid)
    end

    function adapter.schedule(_, callback)
        adapter.scheduled = callback
        table.insert(adapter.queue, callback)
    end

    function adapter.notify(_, message)
        table.insert(adapter.notifications, message)
    end

    return adapter
end

H.test("sparring prepares two user-owned teams and starts combat", function()
    local adapter = fakeAdapter()
    local messages = {}
    local sparring = Sparring.new(adapter, function(message)
        table.insert(messages, message)
    end)

    local match = sparring:startAuto({ countdownSeconds = 0 })
    H.equal(match.phase, "combat")
    H.equal(#adapter.prepared, 2)
    H.equal(adapter.hostilePairs, 1)
    H.equal(adapter.combatPairs, 1)
    H.truthy(adapter.scheduled)
end)

H.test("sparring detects defeat, declares a winner, and restores both teams", function()
    local adapter = fakeAdapter()
    local sparring = Sparring.new(adapter, function() end)
    sparring:startAuto({ countdownSeconds = 0 })

    adapter.alive.right = false
    table.remove(adapter.queue, 1)()

    H.equal(sparring.active, nil)
    H.equal(sparring.lastResult.winnerUserId, 0)
    H.truthy(adapter.defeated.right)
    H.equal(#adapter.restored, 2)
end)

H.test("manual abort restores both teams without a winner", function()
    local adapter = fakeAdapter()
    local sparring = Sparring.new(adapter, function() end)
    sparring:startAuto({ countdownSeconds = 0 })
    sparring:abort("test")

    H.equal(sparring.active, nil)
    H.equal(sparring.lastResult, nil)
    H.equal(#adapter.restored, 2)
end)

H.test("a partial engine setup failure rolls back both teams", function()
    local adapter = fakeAdapter()
    adapter.failPreparation = true
    local sparring = Sparring.new(adapter, function() end)

    H.raises(function()
        sparring:startAuto({ countdownSeconds = 0 })
    end, "rolled back")
    H.equal(sparring.active, nil)
    H.equal(#adapter.restored, 2)
end)

H.test("sparring counts down before applying hostility", function()
    local adapter = fakeAdapter()
    local sparring = Sparring.new(adapter, function() end)
    local match = sparring:startAuto({ countdownSeconds = 2 })

    H.equal(match.phase, "preparation")
    H.equal(adapter.hostilePairs, 0)
    table.remove(adapter.queue, 1)()
    H.equal(match.phase, "preparation")
    table.remove(adapter.queue, 1)()
    H.equal(match.phase, "combat")
    H.equal(adapter.hostilePairs, 1)
end)

H.test("sparring uses the avatar fallback for collapsed split-screen ownership", function()
    local adapter = fakeAdapter()
    function adapter.partyMembers()
        return {
            {
                guid = "left",
                name = "Left",
                userId = 0,
                level = 5,
                faction = "faction-left",
                isAvatar = true,
                avatarUserId = 0,
            },
            {
                guid = "right",
                name = "Right",
                userId = 0,
                level = 5,
                faction = "faction-right",
                isAvatar = true,
                avatarUserId = 1,
            },
        }
    end
    local sparring = Sparring.new(adapter, function() end)
    sparring:startAuto({ countdownSeconds = 0 })

    H.equal(sparring.active.teams.mode, "split-screen-avatars")
    H.equal(sparring.active.teams.left.label, "Couch Player 1")
    H.equal(sparring.active.teams.right.label, "Couch Player 2")
end)

H.test("rematch rescans teams after a completed match", function()
    local adapter = fakeAdapter()
    local sparring = Sparring.new(adapter, function() end)
    sparring:startAuto({ countdownSeconds = 0 })
    adapter.alive.right = false
    table.remove(adapter.queue, 1)()
    adapter.alive.right = true

    local match = sparring:rematch({ countdownSeconds = 0 })
    H.equal(match.phase, "combat")
    H.equal(match.id, "sparring-2")
end)
