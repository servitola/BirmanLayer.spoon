**English** · [Русский](how-it-works.ru.md)

# How it works

This is Ilya Birman's layout on the right ⌥, put there by an unofficial Spoon. The original is at
<https://ilyabirman.ru/typography-layout/>.

## The one difference from Birman's Mac layout

His layout replaces the ⌥ layer on **both** Option keys, because a Mac keyboard layout cannot tell them apart in practice (its format names a right Option, but Ukelele users [report](https://groups.google.com/g/ukelele-users/c/6jviMBPlqCY) that it does not work as a separate key). By default the Spoon puts it on the **right** one
only, the way Windows does with AltGr, and leaves the left ⌥ as Apple's own, so ⌥ shortcuts and Apple's ⌥
characters stay. Every character and dead key is Birman's; only the key that reaches them differs.

Switch it with `layer.rightOptionOnly`: `true` (default) is the Windows way, `false` is Birman's Mac way,
with the layer on both Option keys (then a bare ⌥ shortcut types Birman's character; ⌥ with ⌘ or ⌃ still
works as a shortcut).

## It does not care which layout is active

The layer itself is not keyed to an input source name; only the opt-in `baseFixups` names layouts (ABC, Russian – PC).

- The ⌥ layers are **positional**: the same physical key gives the same character whether ABC,
  Russian, Greek, German or Dvorak is active, exactly as on Windows.
- A dead key composes by **the character the next key types** in the active layout. After
  ⇧⌥`/` the `a` key of ABC gives `á`, the `к` key of any Russian layout gives `ќ`, and a layout the
  table has never heard of falls back to "accent, then the key". Add your own letters with
  [`overrides`](configuration.md#overrides).

Birman's own build has an English and a Russian layout. The Spoon reproduces both exactly, quirks
included, and uses the Russian differences whenever the active layout types Cyrillic (it asks the layout,
not its name). It adds nothing and corrects nothing: what you want different is an
[`overrides`](configuration.md#change-what-birman-did) entry.

## Data

`typography_table.lua` is Birman's layout, read from the two `.keylayout` files of his official
build — version 3.9 for Mac, `ilya-birman-typolayout-3.9-mac.zip` from
<https://ilyabirman.ru/typography-layout/>, SHA-256
`64b4f7b1421cc4275864c25941646ddf2d3075212a77e9ba1c2d27b726afe123` — and nothing else.
The previous build, 3.8, differs from 3.9 in one ⇧⌥ cell (`t`) and in the Russian cedilla compositions of `с` and `з`. Birman
publishes no Greek or other layout, and the Spoon invents none; add them with `overrides`.

`tests/official_cases.json` lists every press Birman's layouts define (about 3 700): each ⌥ and ⇧⌥ key
in both scripts, and every key pressed inside every dead state. `tests/test_birman_layer.lua` replays all
of them through the Spoon (`hs -c 'return dofile("<path>/tests/test_birman_layer.lua")' </dev/null`)
and expects the layout's own output.

Nothing is added, changed or fixed on top of that; the Spoon types what his layouts type.

## Versions

The version is Birman's Mac layout version the data was read from, plus a patch number of ours: `3.9.0`,
`3.9.1`, … Birman's next release is `4.0.0` here after the data is regenerated from it.

## Speed, and why not Karabiner

The Spoon's own work per keystroke, measured with `tests/bench.lua` (Apple M3 Pro, macOS 26.6, Hammerspoon 1.1.1):

| | Time |
| --- | --- |
| decide what to do with right ⌥ + `c` | about 1 µs |
| pass an ordinary key through | about 0.6 µs |
| build the two Unicode key events that type `—` | about 3 µs |

What reaches the application is a real Unicode key event posted from inside Hammerspoon (`setUnicodeString`): no
child process and no clipboard.

Karabiner-Elements cannot do that. Its documented outputs are `key_code`, `consumer_key_code`, `pointing_button`,
`shell_command`, `select_input_source`, `set_variable`, `mouse_key`, `sticky_modifier`, `software_function` and
`send_user_command`; there is no Unicode output. To type `—` from Karabiner you go through `shell_command`, usually
`pbcopy` plus a synthetic ⌘V, or an AppleScript `keystroke`. Measured on the same Mac, before the paste even starts:

| | Time |
| --- | --- |
| start a shell (`/bin/sh -c :`) | about 4 ms |
| shell plus a pasteboard tool (`sh -c pbpaste`, standing in for `pbcopy`) | about 13 ms |
| `osascript -e 1` | about 32 ms |

That is three orders of magnitude, but a single 13 ms delay is below what a person notices, so the honest costs of the
Karabiner route are elsewhere: a shell command runs asynchronously and out of step with the key stream, so a fast typist
can get the next letters before the character; the clipboard is overwritten, or has to be saved and restored, which adds delay
and races; ⌘V does nothing where paste is unavailable; and dead keys need state, which Karabiner keeps in variables while the
output still goes through a shell. Not measured: an end-to-end Karabiner run, which would overwrite the clipboard.

Karabiner and this Spoon coexist well: Karabiner is the right tool for turning one key into another, and Hammerspoon for typing text.

## Limitations

- Hammerspoon needs the **Accessibility** permission.
- Nothing is typed while macOS **secure input** is on (password fields, some terminals
  with "Secure Keyboard Entry").
- Apps that read **key codes** instead of text (games, VMs, remote desktops) see the typed
  character as an unknown key; list them in `excludedBundles`.
- Positions are Birman's: he drew the ⌥ layer for a QWERTY keyboard. On Dvorak or Colemak the
  characters sit on the keys' QWERTY positions, and override key names are QWERTY positions too.
- The layer key is taken over completely (the right ⌥, or both with `rightOptionOnly = false`); apps that use
  it for something else (Emacs Meta) get nothing.
