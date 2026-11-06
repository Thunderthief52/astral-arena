-- Disposable-save terrain probe. Never shipped in the normal release PAK.
Ext.Events.SessionLoaded:Subscribe(function()
    Ext.Timer.WaitFor(3000, function()
        local guid = Osi.GetHostCharacter()
        if not guid or Osi.GetRegion(guid) ~= "AA_Arena_Main" then return end
        local x, y, z = Osi.GetPosition(guid)
        if math.abs(x - 34.75) > 1 or math.abs(z - 53.75) > 1 then return end
        local result = { setup = "teleported beside north Echelon stair; subsequent movement is user-controlled", origin = {x,y,z}, samples = {} }
        Osi.TeleportToPosition(guid, 39.5, 0, -56.5, "", 0, 0, 0, 0, 1)
        local count = 0
        local function sample()
            count = count + 1
            local sx, sy, sz = Osi.GetPosition(guid)
            table.insert(result.samples, { second = count, position = {sx,sy,sz} })
            Ext.IO.SaveFile("AstralArena/terrain-live-probe.json", Ext.Json.Stringify(result))
            if count < 600 then Ext.Timer.WaitFor(1000, sample) end
        end
        Ext.Timer.WaitFor(1000, sample)
    end)
end)