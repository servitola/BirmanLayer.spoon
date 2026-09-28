-- Run: hs -c 'dofile(os.getenv("HOME") .. "/path/to/BirmanLayer.spoon/tests/bench_endtoend.lua")' </dev/null
-- Hands off the keyboard for about two minutes: it types into its own window and uses the clipboard.
-- Result: BENCH_OUT (default /tmp/birmanlayer-bench.txt). BirmanLayer must be running.
local N = tonumber(os.getenv("BENCH_N")) or 100
local OUT = os.getenv("BENCH_OUT") or "/tmp/birmanlayer-bench.txt"
local KARABINER_COMMAND = "printf '\\302\\251' | /usr/bin/pbcopy"
local KARABINER_HOLD = 0.030
local RIGHT_OPTION = 0x80040

local html = [[<html><body><input id="i" style="width:90%;font-size:28px" autofocus><script>
var i = document.getElementById('i');
i.addEventListener('input', function () {
  window.webkit.messageHandlers.bench.postMessage({ t: performance.timeOrigin + performance.now(), v: i.value });
});
function reset() { i.value = ''; i.focus(); }
</script></body></html>]]

local function nowMs() return hs.timer.secondsSinceEpoch() * 1000 end

local got
local content = hs.webview.usercontent.new("bench"):setCallback(function(message) got = message.body end)
local view = hs.webview.new({ x = 200, y = 200, w = 520, h = 120 }, {}, content):html(html):allowTextEntry(true)
view:show():bringToFront(true)
spoon.ScreenGlow:pulse(420)

local function press(code, flags)
    for _, isDown in ipairs({ true, false }) do
        local event = hs.eventtap.event.newKeyEvent(code, isDown)
        if flags then event:rawFlags(flags) end
        event:post()
    end
end

local function pasteCommandV()
    for _, isDown in ipairs({ true, false }) do
        hs.eventtap.event.newKeyEvent(9, isDown):setFlags({ cmd = true }):post()
    end
end

local CONDITIONS = {
    { name = "floor: a Unicode key event posted directly, no Spoon", want = "x", run = function()
        for _, isDown in ipairs({ true, false }) do
            hs.eventtap.event.newKeyEvent(0, isDown):setUnicodeString("x"):post()
        end
    end },
    { name = "BirmanLayer, right ⌥ + c", want = "©", run = function() press(8, RIGHT_OPTION) end },
    { name = "Karabiner-style: shell pbcopy, 30 ms, ⌘V", want = "©", run = function()
        hs.pasteboard.setContents("STALE")
        hs.task.new("/bin/sh", nil, { "-c", KARABINER_COMMAND }):start()
        hs.timer.doAfter(KARABINER_HOLD, pasteCommandV)
    end },
}

local results = {}
local function record(load, condition, sample)
    local key = load .. " | " .. condition.name
    results[key] = results[key] or { load = load, name = condition.name, times = {}, wrong = 0, missing = 0, seen = {} }
    local r = results[key]
    if not sample then r.missing = r.missing + 1
    elseif sample.v ~= condition.want then
        r.wrong = r.wrong + 1
        r.seen[sample.v] = true
    else table.insert(r.times, sample.t - sample.t0) end
end

local function focusWindow()
    hs.application.applicationsForBundleID("org.hammerspoon.Hammerspoon")[1]:activate()
    view:bringToFront(true)
end

local function trial(load, condition, done, attempts)
    attempts = attempts or 0
    if attempts > 25 then error("the benchmark window cannot get keyboard focus") end
    view:evaluateJavaScript("reset(); document.hasFocus()", function(hasFocus)
        if hasFocus ~= true then
            focusWindow()
            return hs.timer.doAfter(0.2, function() trial(load, condition, done, attempts + 1) end)
        end
        hs.timer.doAfter(0.08, function()
            got = nil
            local t0 = nowMs()
            condition.run()
            hs.timer.doAfter(0.35, function()
                record(load, condition, got and { t = got.t, v = got.v, t0 = t0 } or nil)
                done()
            end)
        end)
    end)
end

local function runPhase(load, done)
    local step = 0
    local total = N * #CONDITIONS
    local function nextTrial()
        if step >= total then return done() end
        step = step + 1
        trial(load, CONDITIONS[(step - 1) % #CONDITIONS + 1], nextTrial)
    end
    nextTrial()
end

local function percentile(sorted, p) return sorted[math.max(1, math.ceil(#sorted * p))] end

local function report()
    local lines = { ("N = %d per line; ms from the trigger to the character arriving in a WebKit text field"):format(N),
        "machine: " .. hs.host.localizedName() .. ", Hammerspoon " .. hs.processInfo.version, "" }
    local keys = {}
    for key in pairs(results) do table.insert(keys, key) end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local r = results[key]
        table.sort(r.times)
        local n = #r.times
        table.insert(lines, n == 0 and ("%s: no good samples (wrong %d, missing %d)"):format(key, r.wrong, r.missing)
            or ("%s: median %.1f, p95 %.1f, max %.1f (ok %d, wrong content %d, nothing arrived %d)"):format(
                key, percentile(r.times, 0.5), percentile(r.times, 0.95), r.times[n], n, r.wrong, r.missing))
        if r.wrong > 0 then
            local values = {}
            for value in pairs(r.seen) do table.insert(values, ("%q"):format(value)) end
            table.insert(lines, "    wrong values: " .. table.concat(values, ", "))
        end
    end
    local file = io.open(OUT, "w")
    file:write(table.concat(lines, "\n"), "\n")
    file:close()
end

local busy = {}
local function startLoad()
    for _ = 1, 10 do
        table.insert(busy, hs.task.new("/bin/sh", nil, { "-c", "while :; do :; done" }):start())
    end
end
local function stopLoad()
    for _, task in ipairs(busy) do task:terminate() end
    busy = {}
end

hs.timer.doAfter(0.6, function()
    focusWindow()
    runPhase("idle", function()
        startLoad()
        runPhase("10 busy processes", function()
            stopLoad()
            hs.pasteboard.clearContents()
            view:delete()
            spoon.ScreenGlow:stop()
            report()
        end)
    end)
end)
return "started; result in " .. OUT
