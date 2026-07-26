package.path = table.concat({
    "./src/Mods/AstralArena/ScriptExtender/Lua/?.lua",
    "./src/Mods/AstralArena/ScriptExtender/Lua/?/init.lua",
    package.path,
}, ";")

local Bracket = require("AstralArena.Core.Bracket")

local state = Bracket.new({ id = "deterministic-demo" })
for seed = 1, 8 do
    Bracket.register(state, {
        id = "seed-" .. seed,
        displayName = "Entrant " .. seed,
    })
end
Bracket.seed(state)

local winners = {
    QF1 = "seed-1",
    QF2 = "seed-4",
    QF3 = "seed-2",
    QF4 = "seed-3",
    SF1 = "seed-1",
    SF2 = "seed-2",
    F1 = "seed-1",
}

for _, matchId in ipairs({ "QF1", "QF2", "QF3", "QF4", "SF1", "SF2", "F1" }) do
    Bracket.recordWinner(state, matchId, winners[matchId], "simulation")
end

print(Bracket.summary(state))

