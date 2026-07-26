local Util = {}

function Util.copy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        error("cannot copy a cyclic table", 2)
    end

    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        result[Util.copy(key, seen)] = Util.copy(child, seen)
    end
    seen[value] = nil
    return result
end

function Util.assertNonEmptyString(value, label)
    if type(value) ~= "string" or value == "" then
        error((label or "value") .. " must be a non-empty string", 3)
    end
end

function Util.arrayContains(values, wanted)
    for _, value in ipairs(values) do
        if value == wanted then
            return true
        end
    end
    return false
end

function Util.countKeys(values)
    local count = 0
    for _ in pairs(values or {}) do
        count = count + 1
    end
    return count
end

return Util

