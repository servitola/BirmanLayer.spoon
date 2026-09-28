-- Run: hs -c 'return dofile(os.getenv("HOME") .. "/projects/dotfiles/hammerspoon/Spoons/BirmanLayer.spoon/tests/test_birman_layer.lua")' </dev/null
-- Fake events: nothing is typed or posted.
local failures, checks = {}, 0
local function eq(got, want, label)
    checks = checks + 1
    if got ~= want then
        table.insert(failures, string.format("%s: got %s, want %s", label, tostring(got), tostring(want)))
    end
end

local SPOON = debug.getinfo(1, "S").source:sub(2):match("(.*/)tests/")
local L = dofile(SPOON .. "init.lua"):init()
eq(L.version:match("^(%d+%.%d+)%.%d+$"), dofile(SPOON .. "typography_table.lua").version, "the version starts with Birman's")
local props = hs.eventtap.event.properties
local RALT, LALT, RCMD, RCTRL, LCMD, LCTRL, LSHIFT, RSHIFT = 0x40, 0x20, 0x10, 0x2000, 0x08, 0x01, 0x02, 0x04
local HYPER = RALT | RCMD | RCTRL | RSHIFT
local K = { a = 0, f = 3, h = 4, g = 5, x = 7, c = 8, r = 15, ["2"] = 19, ["6"] = 22, [";"] = 41, ["-"] = 27, ["]"] = 30, ["["] = 33,
            i = 34, q = 12, [","] = 43, ["."] = 47, ["/"] = 44, space = 49, escape = 53, v = 9, section = 10, grave = 50 }
local ABC, RUSSIAN_PC, GREEK = "com.apple.keylayout.ABC", "com.apple.keylayout.RussianWin", "com.apple.keylayout.Greek"

local MARK = 0x52414C54
local out, source, clock = {}, ABC, 1e12
L._emit = function(text) table.insert(out, text) end
L._forward = function(event) table.insert(out, "<" .. event:getKeyCode() .. ">") end
L._currentSource = function() return source end
local realTypesCyrillic = L._typesCyrillic
local CYRILLIC = { [RUSSIAN_PC] = true, ["com.example.Cyrillic"] = true }
L._typesCyrillic = function() return CYRILLIC[source] == true end
eq(type(realTypesCyrillic()), "boolean", "the real Cyrillic probe answers on the active layout")
L._now = function() return clock end

local function press(code, flags, repeating, userData, chars)
    local event = {
        getKeyCode = function() return code end,
        rawFlags = function() return flags or 0 end,
        getCharacters = function() return chars or "" end,
        getProperty = function(_, p)
            if p == props.keyboardEventAutorepeat then return repeating and 1 or 0 end
            if p == props.eventSourceUserData then return userData or 0 end
            return 0
        end,
    }
    return L._handle(event)
end

local function typed()
    local s = table.concat(out)
    out = {}
    return s
end

local function restart(configure)
    L.overrides, L.baseFixups, L.rightOptionOnly = {}, false, true
    if configure then configure() end
    L:start(); L:stop()
end

local taps, newTap = {}, hs.eventtap.new
hs.eventtap.new = function(...)
    local t = newTap(...)
    table.insert(taps, t)
    return t
end
L.excludedBundles = { "com.nvidia.gfnpc.mall" }
local front = nil
L._frontBundle = function() return front end
L:start(); L:start()
hs.eventtap.new = newTap
eq(L:state().running, true, "start() enables the tap")
eq(taps[1]:isEnabled(), false, "second start() stops the first tap")
eq(#taps, 2, "each start() creates exactly one tap")
L:stop()
eq(L:state().running, false, "stop() disables the tap")
eq(taps[2]:isEnabled(), false, "stop() disables the live tap")

press(K["/"], RALT | LSHIFT)
local clicked = L._onEvent({ getType = function() return hs.eventtap.event.types.leftMouseDown end })
eq(clicked, false, "a click is never consumed"); eq(L:state().dead, nil, "a click drops a pending dead key")
local keyed = L._onEvent({ getType = function() return hs.eventtap.event.types.keyDown end, getKeyCode = function() return K.c end,
    rawFlags = function() return RALT end, getCharacters = function() return "" end,
    getProperty = function() return 0 end })
eq(keyed, true, "key events go to the handler"); eq(typed(), "©", "…and type")

eq(press(K.c, RALT, false, MARK), false, "own posted event passes through"); eq(typed(), "", "own event types nothing")

eq(press(K.c, RALT), true, "right⌥c consumed");            eq(typed(), "©", "right⌥c")
eq(press(K["-"], RALT), true, "right⌥- consumed");         eq(typed(), "—", "right⌥-")
press(K["-"], RALT | LSHIFT);                               eq(typed(), "–", "⇧right⌥-")
press(K["2"], RALT | RSHIFT);                               eq(typed(), "¹⁄₂", "right⇧right⌥2")
press(K[","], RALT); press(K["."], RALT);                   eq(typed(), "«»", "right⌥, .")
press(K.c, RALT, true);                                     eq(typed(), "©", "auto-repeat types again")
eq(press(K.g, RALT), true, "empty Birman cell consumed");   eq(typed(), "", "empty Birman cell types nothing")
eq(press(K.f, RALT | LSHIFT), true, "empty ⇧⌥ cell consumed"); eq(typed(), "", "empty ⇧⌥ cell types nothing")

eq(press(K.c, LALT), false, "left⌥ passes through");        eq(typed(), "", "left⌥ types nothing")
eq(press(K.c, RALT | LALT), false, "both ⌥ pass through")
eq(press(K.v, HYPER), false, "Hyper passes through")
eq(press(K.v, HYPER | LCMD), false, "Hyper+⌘ passes through")
eq(press(K.c, RALT | LCMD), false, "right⌥+left⌘ passes through")
eq(press(K.c, RALT | LCTRL), false, "right⌥+left⌃ passes through")
eq(press(K.c, 0), false, "plain key passes through");       eq(typed(), "", "nothing typed on pass-through")

eq(press(K.section, 0), false, "no base fixups by default"); eq(typed(), "", "§ left to Apple")
eq(press(K.grave, LSHIFT), false, "no ⇧` fixup by default")

source = "Some Other Layout"
press(K.c, RALT);                                           eq(typed(), "©", "any input source gets the ⌥ layer")
source = nil
press(K.c, RALT);                                           eq(typed(), "©", "no input source gets the ⌥ layer")
source = ABC

restart(function() L.baseFixups = true end)
eq(press(K.section, 0), true, "§ key consumed");            eq(typed(), "`", "abc § → `")
press(K.section, LSHIFT);                                   eq(typed(), "~", "abc ⇧§ → ~")
press(K.grave, 0);                                          eq(typed(), "\\", "abc ` key → \\")
eq(press(K.grave, LSHIFT), false, "abc ⇧` has no fixup")
for _, flags in ipairs({ LCMD, RCMD, LCTRL, LALT, LCMD | LSHIFT }) do
    eq(press(K.section, flags), false, "modified § passes through (" .. flags .. ")")
end
eq(press(K.a, 0), false, "key without a fixup passes through"); eq(typed(), "", "nothing typed for modified fixups")
source = "Some Other Layout"
eq(press(K.section, 0), false, "unknown input source gets no fixups")
source = nil
eq(press(K.section, 0), false, "no input source gets no fixups")
source = RUSSIAN_PC
eq(press(K.grave, LSHIFT), true, "ru ⇧` consumed");         eq(typed(), "Ё", "ru ⇧` → Ё")
eq(press(K.grave, 0), false, "ru ` has no fixup")
eq(press(K.grave, LSHIFT | LCMD), false, "ru ⌘⇧` passes through")
eq(press(K.grave, LSHIFT | RALT | LALT), false, "ru ⇧ both ⌥ ` passes through")
press(K.h, RALT); press(K[","], RALT);                      eq(typed(), "₽«", "ru right⌥h ,")
source = ABC

restart()
eq(press(K["/"], RALT | LSHIFT), true, "dead acute consumed")
eq(L:state().dead and L:state().dead.state, "acute", "dead acute armed")
eq(typed(), "", "dead key types nothing")
eq(press(K.a, 0, false, nil, "a"), true, "a after acute consumed"); eq(typed(), "á", "acute + a")
eq(L:state().dead, nil, "state cleared after compose")
press(K["/"], RALT | LSHIFT); press(K.a, LSHIFT, false, nil, "A"); eq(typed(), "Á", "acute + A")

press(K["/"], RALT | LSHIFT); press(K["/"], RALT | LSHIFT, true)
eq(L:state().dead and L:state().dead.state, "acute", "auto-repeat of a held dead key keeps the state")
press(K["/"], RALT | LSHIFT);                               eq(typed(), "\u{301}", "acute twice = combining stress")

press(K["/"], RALT | LSHIFT)
eq(press(K.x, 0, false, nil, "x"), true, "unrelated key consumed and re-posted")
eq(typed(), "´<7>", "terminator, then the key itself")

press(K["/"], RALT | LSHIFT)
press(K.c, RALT);                                           eq(typed(), "´©", "terminator, then the layer")

press(K["/"], RALT | LSHIFT)
press(K.space, 0, false, nil, " ");                         eq(typed(), "´", "acute + space types the accent")

restart(function() L.baseFixups = true end)
press(K["/"], RALT | LSHIFT)
press(K.section, 0, false, nil, "§");                       eq(typed(), "´`", "terminator, then the fixup")
restart()

press(K["/"], RALT | LSHIFT)
eq(press(K.escape, 0), true, "escape consumed");            eq(typed(), "", "escape cancels silently")
eq(L:state().dead, nil, "escape clears the state")

press(K["/"], RALT | LSHIFT)
clock = clock + 2.9e9
eq(L:state().dead and L:state().dead.state, "acute", "state alive at 2.9 s")
clock = clock + 0.2e9
eq(L:state().dead, nil, "state expires after 3 s")
eq(press(K.a, 0, false, nil, "a"), false, "a after timeout passes through"); eq(typed(), "", "no terminator after timeout")

source = RUSSIAN_PC
press(K["/"], RALT | LSHIFT); press(K.f, 0, false, nil, "а"); eq(typed(), "´<3>", "ru acute + а: terminator, key")
press(K["/"], RALT | LSHIFT); press(K.r, 0, false, nil, "к"); eq(typed(), "ќ", "ru acute + к")
source = "com.example.Cyrillic"
press(K["/"], RALT | LSHIFT); press(K.r, 0, false, nil, "к"); eq(typed(), "ќ", "any Cyrillic layout composes by character")
source = ABC

press(K["/"], RALT | LSHIFT)
eq(press(K.a, RCMD | RALT, false, nil, "a"), false, "⌘ in a dead state passes through")
eq(L:state().dead, nil, "⌘ clears the state")
press(K["/"], RALT | LSHIFT)
eq(press(K.escape, LCMD), false, "⌘Escape in a dead state is a shortcut, not a cancel")

press(K["/"], RALT | LSHIFT)
eq(press(K.section, RALT | LSHIFT), true, "grave dead key in the acute state consumed")
eq(typed(), "´", "acute terminator only, not composed into the next state")
eq(L:state().dead and L:state().dead.state, "grave", "grave armed after the acute terminator")
press(K.a, 0, false, nil, "a");                             eq(typed(), "à", "grave + a")

press(K["/"], RALT | LSHIFT)
L._appActivated("com.example.other")
eq(L:state().dead, nil, "app switch clears the dead state")
eq(press(K.a, 0, false, nil, "a"), false, "a after app switch passes through"); eq(typed(), "", "no terminator after app switch")

L._appActivated("com.nvidia.gfnpc.mall")
eq(press(K.c, RALT), false, "excluded app: right⌥c passes through")
eq(press(K.section, 0), false, "excluded app: no fixups");   eq(typed(), "", "excluded app types nothing")
L._appActivated(nil)
eq(press(K.c, RALT), true, "app without a bundle id is not excluded"); eq(typed(), "©", "layer back on")
front = "com.nvidia.gfnpc.mall"; restart()
eq(press(K.c, RALT), false, "start() honors the app that is already in front")
front = nil; restart()
L._appActivated("com.blizzard.heroesofthestorm")
eq(press(K.c, RALT), true, "bundle outside excludedBundles is not excluded"); typed()
L._appActivated(nil)

press(K["/"], RALT | LSHIFT)
eq(press(K.c, LALT), true, "left⌥ in a dead state: the state ends and the key is passed on"); eq(typed(), "´<8>", "terminator, then the left⌥ key")

restart(function() L.rightOptionOnly = false end)
eq(press(K.c, LALT), true, "both-keys mode: left⌥c consumed");   eq(typed(), "©", "left⌥c types ©")
press(K.c, RALT);                                           eq(typed(), "©", "right⌥c still types ©")
press(K.c, LALT | RALT);                                    eq(typed(), "©", "both ⌥ together type ©")
press(K["-"], LALT | LSHIFT);                               eq(typed(), "–", "⇧left⌥-")
eq(press(K.c, LALT | LCMD), false, "left⌥ with left⌘ passes through")
eq(press(K.c, LALT | LCTRL), false, "left⌥ with left⌃ passes through")
eq(press(K.v, HYPER), false, "Hyper passes through")
press(K["/"], LALT | LSHIFT);                               eq(L:state().dead and L:state().dead.state, "acute", "left⌥ enters a dead key")
press(K.a, 0, false, nil, "a");                             eq(typed(), "á", "acute + a")
press(K["/"], LALT | LSHIFT); press(K["/"], LALT | LSHIFT); eq(typed(), "\u{301}", "acute twice with left⌥ = stress mark")
eq(press(K.c, 0), false, "plain key passes through");       eq(typed(), "", "nothing typed")
restart()
eq(press(K.c, LALT), false, "the default is right ⌥ only")
restart()

restart(function()
    L.baseFixups = true
    L.overrides = { ["*"] = { fixups = { [ABC] = { ["`"] = { base = "@" } } } } }
end)
press(K.grave, 0);                                          eq(typed(), "@", "overrides can carry fixups, by key name")
press(K.section, 0);                                        eq(typed(), "`", "…and the rest of the fixups stay")

restart(function()
    L.overrides = {
        ["*"] = { keys = { c = { opt = "X" }, x = { opt = { pass = true } }, h = { shift_opt = false } } },
        ["com.example.Layout"] = {
            keys = { [K.g] = { opt = "G" } },
            dead = { acute = { compose = { ["ы"] = "ы́" }, keys = { i = { opt = "!" } } } },
            terminators = { acute = "'" },
        },
    }
end)
press(K.c, RALT);                                           eq(typed(), "X", "overrides[\"*\"] replaces a cell, by key name")
eq(press(K.x, RALT), false, "a { pass = true } cell is left to Apple")
eq(press(K.h, RALT | LSHIFT), true, "a false cell is consumed");  eq(typed(), "", "a false cell types nothing")
press(K.h, RALT);                                           eq(typed(), "₽", "cells an override does not name keep Birman's")
press(K.g, RALT);                                           eq(typed(), "", "an override for another layout does not apply")
source = "com.example.Layout"
press(K.g, RALT);                                           eq(typed(), "G", "overrides[source] applies to that layout, by key code")
press(K.c, RALT);                                           eq(typed(), "X", "overrides[source] sits on top of overrides[\"*\"]")
press(K["/"], RALT | LSHIFT); press(K.a, 0, false, nil, "ы"); eq(typed(), "ы́", "overrides add a composed character")
press(K["/"], RALT | LSHIFT); press(K.a, 0, false, nil, "a"); eq(typed(), "á", "the rest of the state is intact")
press(K["/"], RALT | LSHIFT); press(K.i, RALT);            eq(typed(), "!", "overrides add a ⌥ cell to a state, by key name")
press(K["/"], RALT | LSHIFT); press(K.x, 0, false, nil, "x"); eq(typed(), "'<7>", "overrides replace a terminator")
source = ABC

eq(pcall(function() L.overrides = { ["*"] = { keys = { nosuchkey = { opt = "x" } } } }; L:start() end), false,
   "an unknown key name in overrides is an error")
restart()

restart()
press(K["6"], RALT | LSHIFT); press(K["6"], RALT | LSHIFT); eq(typed(), "\u{302}\u{302}", "English: ⇧⌥6 twice types two combining circumflexes, as Birman's does")
press(K[";"], RALT | LSHIFT); press(K.i, RALT);            eq(typed(), "¨і", "English: ¨ then ⌥i is the accent, then і")
source = RUSSIAN_PC
press(K["6"], RALT | LSHIFT); press(K["6"], RALT | LSHIFT); eq(typed(), "\u{302}", "Russian: ⇧⌥6 twice types one")
press(K[";"], RALT | LSHIFT); press(K.i, RALT);            eq(typed(), "ï", "Russian: ¨ then ⌥i types ï")
press(K[";"], RALT | LSHIFT); press(K.grave, 0, false, nil, "ё"); eq(typed(), "¨<50>", "Russian: the second ё key does not compose")
source = ABC
restart(function()
    L.overrides = { ["*"] = { dead = {
        circumflex = { keys = { ["6"] = { shift_opt = "\u{302}" } } },
        diaeresis = { keys = { i = { opt = "ï", shift_opt = "Ї" } } },
    } },
    [RUSSIAN_PC] = { dead = { breve = { keys = { ["`"] = { base = "ӗ", shift = "Ӗ" } } } } } }
end)
press(K["6"], RALT | LSHIFT); press(K["6"], RALT | LSHIFT); eq(typed(), "\u{302}", "README: overrides make ⇧⌥6 twice one circumflex in English")
press(K[";"], RALT | LSHIFT); press(K.i, RALT);            eq(typed(), "ï", "README: overrides make ¨ then ⌥i type ï in English")
press(K.q, RALT | LSHIFT); press(K.grave, 0, false, nil, "`");  eq(typed(), "˘<50>", "README: the second-ё override does not reach Latin layouts")
source = RUSSIAN_PC
press(K.q, RALT | LSHIFT); press(K.grave, 0, false, nil, "ё");  eq(typed(), "ӗ", "README: the second ё key composes with the override")
press(K.q, RALT | LSHIFT); press(K.grave, LSHIFT, false, nil, "Ё"); eq(typed(), "Ӗ", "README: and with Shift")
source = ABC
restart()

-- official_cases.json: every press Birman's layouts define.
local cases = hs.json.read(SPOON .. "tests/official_cases.json")
eq(#cases > 3000, true, "official cases loaded")
local FLAGS = { base = 0, shift = LSHIFT, opt = RALT, shift_opt = RALT | LSHIFT }
local entry = {}
for _, c in ipairs(cases) do
    local _, state, code, layer, _, want = table.unpack(c)
    if state == "" and type(want) == "table" and not entry[want.dead] then entry[want.dead] = { code, layer } end
end
for _, c in ipairs(cases) do
    local script, state, code, layer, char, want = table.unpack(c)
    local label = string.format("%s %s%s kVK%d %s", script, state, state == "" and "" or " +", code, layer)
    L._appActivated(nil)
    typed()
    source = script == "ru" and RUSSIAN_PC or ABC
    if state ~= "" then
        local enter = entry[state]
        press(enter[1], FLAGS[enter[2]])
        eq(L:state().dead and L:state().dead.state, state, label .. ": enters the state")
    end
    local consumed = press(code, FLAGS[layer], false, nil, char)
    if type(want) == "table" then
        eq(L:state().dead and L:state().dead.state, want.dead, label .. ": enters " .. want.dead)
    else
        eq(typed(), want, label)
        eq(L:state().dead, nil, label .. ": state cleared")
    end
    eq(consumed, true, label .. ": consumed")
end

if #failures > 0 then
    return "FAIL (" .. #failures .. "/" .. checks .. "): " .. table.concat(failures, "; "):sub(1, 3000)
end
return "PASS " .. checks
