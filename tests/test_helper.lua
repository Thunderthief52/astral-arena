local Helper = {
    tests = {},
    passed = 0,
    failed = 0,
}

function Helper.test(name, fn)
    table.insert(Helper.tests, { name = name, fn = fn })
end

function Helper.equal(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. string.format(" (expected %s, got %s)", tostring(expected), tostring(actual)), 2)
    end
end

function Helper.truthy(value, message)
    if not value then
        error(message or "expected a truthy value", 2)
    end
end

function Helper.raises(fn, pattern)
    local ok, err = pcall(fn)
    if ok then
        error("expected function to raise", 2)
    end
    if pattern and not tostring(err):match(pattern) then
        error("error did not match '" .. pattern .. "': " .. tostring(err), 2)
    end
end

function Helper.run()
    for _, item in ipairs(Helper.tests) do
        local ok, err = xpcall(item.fn, debug.traceback)
        if ok then
            Helper.passed = Helper.passed + 1
            io.write("PASS ", item.name, "\n")
        else
            Helper.failed = Helper.failed + 1
            io.write("FAIL ", item.name, "\n", err, "\n")
        end
    end
    io.write(string.format("\n%d passed, %d failed\n", Helper.passed, Helper.failed))
    return Helper.failed == 0
end

return Helper

