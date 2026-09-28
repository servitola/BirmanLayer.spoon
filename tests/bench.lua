-- Run: hs -c 'return dofile(os.getenv("HOME") .. "/path/to/BirmanLayer.spoon/tests/bench.lua")' </dev/null
-- Times the Spoon's own work per keystroke; nothing is typed or posted.
local SPOON = debug.getinfo(1, "S").source:sub(2):match("(.*/)tests/")
local L = dofile(SPOON .. "init.lua"):init()
L._emit = function() end
L._currentSource = function() return "com.apple.keylayout.ABC" end
L._typesCyrillic = function() return false end

local function key(code, flags)
    local event = hs.eventtap.event.newKeyEvent(code, true)
    event:rawFlags(flags)
    return event
end

local function microseconds(fn, n)
    fn()
    local start = hs.timer.absoluteTime()
    for _ = 1, n do fn() end
    return (hs.timer.absoluteTime() - start) / n / 1000
end

local rightAltC, plain = key(8, 0x40), key(0, 0)
return string.format("handle(right ⌥ + c): %.1f µs | handle(plain key): %.1f µs | build the two Unicode events: %.1f µs",
    microseconds(function() L._handle(rightAltC) end, 20000),
    microseconds(function() L._handle(plain) end, 20000),
    microseconds(function()
        for _, isDown in ipairs({ true, false }) do
            hs.eventtap.event.newKeyEvent(0, isDown):setFlags({}):setUnicodeString("—")
        end
    end, 5000))
