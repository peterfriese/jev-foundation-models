# ui - UI Automation (iOS Simulator & macOS Apps)

UI automation is a top-level command group with two subgroups:
- **`flowdeck ui simulator`** — iOS simulator automation (screen capture, gestures, taps, typing, assertions, app control)
- **`flowdeck ui mac`** — macOS app automation (screenshots, clicks, typing, scrolling, menus, windows, app lifecycle)

UI automation lives under `flowdeck ui` (which dispatches to either `simulator` or `mac`). There is no `flowdeck simulator ui`. Commands are kebab-case (for example: `double-tap`, `double-click`, `right-click`, `hide-keyboard`).

## For the Main Agent — Delegating UI Verification

When a UI change is complete and needs runtime verification, delegate to a subagent so the main context stays clean. Copy this template and fill in the blanks:

```
Agent(
  subagent_type: "general-purpose",
  description: "Verify <feature name> on iOS simulator",
  prompt: """
  Verify that <feature> works correctly.

  Setup:
  - App is already built. Run: flowdeck run --scheme <Scheme> -S "<Simulator>"
  - Simulator: <name from flowdeck config get --json>
  - Key accessibility identifiers: <list the relevant IDs from the source>

  Steps:
  1. flowdeck ui simulator session start -S "<sim>" --json  — save the returned paths
  2. Read latest-interactive-tree.json to confirm the starting screen
  3. Run a batch to drive the full flow and assert outcomes:
     flowdeck ui simulator batch --steps '[
       {"action":"tap","target":"<entry_point>","by_id":true},
       ... navigation steps ...,
       {"action":"assert","text":"<expected value>"},
       {"action":"assert","text":"<another expected value>"}
     ]' -S "<sim>" --json
  4. Report per-step results. On failure, describe what the tree shows.
  5. flowdeck ui simulator session stop -S "<sim>"
  6. Classify each finding: functional bug / visual bug / transient state / expected behavior.

  Use only flowdeck commands. Never use xcodebuild, xcrun, simctl, or screenshot-only checks.
  """
)
```

For macOS verification, replace `flowdeck ui simulator` with `flowdeck ui mac`, `-S "<sim>"` with `--app "<AppName>"`, and add `--background` on action commands. Ask first only for foreground-only or desktop-affecting steps such as activation, drag/swipe/timed long-press, coordinate-only fallback, macOS menu access that may affect the active desktop, permission prompts, or recordings.

---

## iOS vs macOS gotchas

- **Flag surface differs across platforms.** **iOS simulator subcommands** support `-j, --json`, `-v, --verbose`, and `-e, --examples`. **macOS `ui mac` subcommands** accept ONLY `--json` and `-h` — there is no `-v` and no `-e`/`--examples` on the mac side.
- **`--timeout` units differ across platforms.** `flowdeck ui simulator scroll --timeout` is **milliseconds** (default 20000). `flowdeck ui mac scroll --timeout` is **seconds** (default 30). Same flag name, different unit — do not copy values across platforms.
- **`--until` / target grammar is shared.** `--until` and `--target`-style flags accept either a plain label (exact match) or `id:<identifier>` to match by accessibility identifier. The `id:` prefix is the same grammar across iOS and macOS.
- **Targeting modes are exclusive, not stackable.** Pick one:
  - default (no flag) — exact label match
  - `--by-id` — accessibility identifier match
  - `--by-role` — role match (e.g. `Button`, `TextField`)
  - `--contains` — substring match against labels (only this one combines with default-mode targeting)

  Prefer `--by-id` when accessibility identifiers exist — it is faster and unambiguous.

---

## iOS Simulator Automation (`flowdeck ui simulator`)

### Workflow

**The accessibility tree is the complete, authoritative state of the screen — trust it.** Every value the user sees (temperatures, percentages, ON/OFF states, labels, search results) is in the tree, each element with a stable `ref` and its `label`/`value`. You read state and confirm every outcome from the tree, and it is always right. Each action also hands you a `delta` — a precise summary of exactly what changed — so you always know where you stand and can move straight to the next step.

1. **Build & run:** `flowdeck run --scheme <Scheme> -S <udid>`.
2. **Start a session — always.** `flowdeck ui simulator session start -S <udid> --json`. The session continuously captures the live screen to disk and keeps `latest-tree.json` current (it settles through animations automatically). Reading that file with the Read tool is the fastest way to see the current screen — a local file read, no process spawn, no round-trip. This warm store is FlowDeck's core advantage; use it as your eyes.
3. **Act by `ref`, and use what the action returns.** `tap`, `type`, `scroll`, `swipe`, `double-tap`, and `wait` each return a `delta` (a precise summary of what changed — value flips, navigation) AND the settled tree, right there in the result. Read the delta — it's your confirmation, computed by exact tree comparison — and take your next refs from that same returned tree. **You do not need to re-read `latest-tree.json` after an action; the action already handed you the current tree.** (Read the file only for the very first screen, or to re-orient when you haven't just acted — it's faster than a `screen` call.) Follow the `next_steps` in the result: when it gives you a ready `batch` (e.g. all the toggle refs), run that batch instead of tapping one at a time. `tap "London"` matches a longer dynamic label ("London, England…") by prefix — no exact string needed; prefer `--by-id` when identifiers exist.
4. **Do the whole flow in ONE `batch` when you can.** A batch spans screens, auto-scrolls to off-screen targets, and verifies values inline with `assert` steps. "Open settings, set the toggles, search a city, open a detail, check the values" is a single `batch` call — the fastest, most reliable path. It returns per-step success and the final tree; if a step fails you see exactly which one and continue from there.

**You have everything you need from the tree:**
- The tree gives you every label, value, and `ref` — you do not need the app's source. Read the screen, not the code.
- Scroll advances ~one viewport and returns `moved`/`reached_end`; stop when `reached_end`. `scroll --until "<label>"` reveals a known off-screen element in one call.
- A screenshot is a **single, one-off** tool for content the tree can't express — custom-rendered graphics, a chart, pixel-level layout. Take one with `screen --screenshot` in that rare case, look once, move on. **Never make image capture part of your working loop, and never read the session's `latest.jpg` to check progress** — for ongoing state you read `latest-tree.json` (the tree), which holds every value and control. Capturing or reading images repeatedly is the one habit that makes UI work slow.
- Always pass `-S <name-or-udid>`. If you're unsure of a flag, run `flowdeck ui simulator <subcommand> --help`.

#### ui simulator screen

> **Requirement — sessions, not repeated `screen` calls.** A running session continuously writes **both** the screenshot (`latest_screenshot`) and the accessibility tree (`latest_tree` / `latest_interactive_tree`) to disk and keeps them current. That is everything you need to see the app. So: **for any multi-step UI work, ALWAYS start a session first** (`ui simulator session start`). Use `screen` **only** for a single one-off capture when no session is running — never as the per-action way to observe the UI. If you will take more than one action, start a session.

Capture the accessibility tree from a simulator. **Tree-only by default — no screenshot.** This is your source of truth (mirrors the tree-only state every action returns).

```bash
flowdeck ui simulator screen -S "iPhone 16" --json                       # full tree (no image)
flowdeck ui simulator screen -S "iPhone 16" --interactive-elements --json # actionable elements only
flowdeck ui simulator screen -S "iPhone 16" --json --screenshot           # tree + screenshot (image validation)
flowdeck ui simulator screen -S "iPhone 16" --output ./screen.png         # save a screenshot to a file
```

**Options:**
| Option | Description |
|--------|-------------|
| `--screenshot` | Also capture a screenshot (for image-based validation only — see below). Off by default. |
| `-o, --output <path>` | Save a screenshot to this path (implies `--screenshot`). |
| `--interactive-elements` | Return only actionable elements instead of the full tree. |
| `--since-hash <hash>` | Return `{"unchanged": true}` if the screen hash matches — skip re-reading an unchanged screen. |
| `--optimize` | Optimize the screenshot for agents (only relevant with `--screenshot`/`--output`). |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

**Notes:**
- Default output is the **full tree** with values + refs + `screen_hash`, and **no screenshot**. Read displayed values from the tree. Add `--screenshot` ONLY for image-based validation (custom-rendered graphics, charts, pixel layout) — never to read a value or find a component.
- In the efficient loop you rarely call `screen` at all: every action already returns the settled tree. Use `screen` for the very first capture, or after something you didn't drive (e.g. an external change).
- `screen` reports coordinates in points.
- `screen` is a fallback for explicit one-off captures, not the default way to recover from a possibly stale session.

#### ui simulator batch — the fastest path; use it for the WHOLE flow

`batch` runs a sequence of actions in ONE invocation and returns the final tree. Unlike a
same-screen-only batch, **FlowDeck's batch spans screens**: label/id targets are re-found on the
*current* screen with settling, so one batch can navigate sheet→list→detail. It also
**auto-scrolls to find** off-screen targets and can **assert** values inline. This is FlowDeck's
biggest lever: express the entire task as one (or a few) batches instead of a per-action loop.

When you know the labels/ids (you read the source, or saw them in the first `screen`), do the
whole flow in ONE batch — including verification with `assert`. No `screen`, no screenshots, no
per-step round-trips:

```bash
flowdeck ui simulator batch --steps '[
  {"action":"tap","target":"settings_button","by_id":true},
  {"action":"tap","target":"Temperature: °C"},
  {"action":"tap","target":"Reduce transparency"},
  {"action":"tap","target":"Done"},
  {"action":"tap","target":"Search"},
  {"action":"type","text":"London"},
  {"action":"tap","target":"London, England"},
  {"action":"assert","text":"11°"},
  {"action":"assert","text":"78%"},
  {"action":"tap","target":"Precipitation"},
  {"action":"assert","text":"10.7 mm"},
  {"action":"assert","text":"Lightning"}
]' -S "iPhone 16" --json
```

- Actions: `tap`, `double_tap`, `type`, `swipe`, `scroll`, `wait`, `key`, `assert`.
  - `tap`/`double_tap`: `target` (+ `by_id`) or `point` (`"x,y"`). Off-screen `target`s are **auto-scrolled into view** before acting.
  - `type`: `text` (+ `clear`). `swipe`/`scroll`: `direction` (+ `distance`; scroll defaults to one viewport).
  - `wait`: `target` (+ `condition`, `timeout_ms`, `by_id`). `key`: `keycode`.
  - **`assert`**: `text` = a value/label that must be visible (e.g. `"11°"`). Passes if any element's label/value contains it; auto-scrolls to find it. `condition:"absent"` inverts. This is how you verify — **not** screenshots.
- Response: `steps[]` with per-step `success`/`error` (the batch stops at the first failure, so you see exactly which step broke), plus the final tree. Re-issue from the failed step if needed.

#### ui simulator session

Start or stop a background capture session. Requires a booted simulator. `session start` stops any active session first and writes captures into `./.flowdeck/automation/sessions/<session-short-id>/`.

```bash
flowdeck ui simulator session start -S "iPhone 16" --json
flowdeck ui simulator session stop -S "iPhone 16"
```

**Options (`session start`):**
| Option | Description |
|--------|-------------|
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |
| `--interval-ms <ms>` | Capture interval in milliseconds (default: `500`) |
| `--retention-seconds <seconds>` | Retention window in seconds (default: `60`) |

**Session Files:**
- `latest.jpg` points to the latest screenshot.
- `latest-interactive-tree.json` points to the latest interactive tree (actionable controls only) — read this to choose actions.
- `latest-tree.json` points to the latest full accessibility tree (fallback).
- `latest.json` points to the latest capture metadata.
- JSON output from `session start` includes absolute paths for the session directory and latest files.

**JSON output keys.** `session start --json` returns `session_dir`, `latest_screenshot`, `latest_interactive_tree`, `latest_tree`, and `session_short_id`. Read `latest_interactive_tree` to decide actions, `latest_screenshot` for content/positioning, and `latest_tree` only as a fallback. Use the path values from the JSON, not the filenames as keys.

**If the session appears stale:**
1. Wait briefly and re-read the same `latest.jpg` / `latest-tree.json` paths.
2. If they still do not reflect an obvious UI change, run `flowdeck ui simulator session start -S "iPhone 16" --json` again.
3. Save the new `latest_screenshot`, `latest_tree`, and `latest` paths from the restarted session.
4. Continue with the restarted session. Only fall back to `screen` if the restarted session is still wrong.

> **Recording lives under `flowdeck simulator`, not `ui`.** `ui` is for automation only. To record video use `flowdeck simulator record`, and for frame/contact-sheet capture use `flowdeck simulator frames` — see `resources/simulator.md`.

#### ui simulator find

Find an element and return its info/text.

```bash
flowdeck ui simulator find "Settings" -S "iPhone 16"
flowdeck ui simulator find "settings_button" -S "iPhone 16" --by-id
flowdeck ui simulator find "button" -S "iPhone 16" --by-role
flowdeck ui simulator find "Log" -S "iPhone 16" --contains
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<target>` | Element to find (label, ID, or role) |

**Options:**
| Option | Description |
|--------|-------------|
| `--by-id` | Search by accessibility identifier |
| `--by-role` | Search by element role (for example `button`, `textField`) |
| `--contains` | Match elements containing the text |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator tap

Tap an element by label or accessibility identifier, or tap coordinates.

```bash
flowdeck ui simulator tap "Log In" -S "iPhone 16"
flowdeck ui simulator tap "login_button" -S "iPhone 16" --by-id
flowdeck ui simulator tap --point 120,340 -S "iPhone 16"
flowdeck ui simulator tap --point 120,340 --geometry points -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<target>` | Element label/ID to tap (or use `--point`) |

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --point <point>` | Tap at coordinates (`x,y`) |
| `--geometry <geometry>` | Coordinate geometry (`points` only) |
| `-d, --duration <seconds>` | Hold duration for a long press |
| `--by-id` | Treat target as an accessibility identifier |
| `--screen` / `--no-screen` | Return the settled screen after the tap (default on). `--no-screen` for a terse result. |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

> The `--screen` / `--no-screen` flag (default **on**) is available on every mutating action — `tap`, `double-tap`, `type`, `swipe`, `scroll`, `wait`. The action returns the settled `screen` tree so you don't need a separate snapshot; pass `--no-screen` to suppress it.

#### ui simulator double-tap

Double tap an element or coordinates.

```bash
flowdeck ui simulator double-tap "Like" -S "iPhone 16"
flowdeck ui simulator double-tap "like_button" -S "iPhone 16" --by-id
flowdeck ui simulator double-tap --point 160,420 -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<target>` | Element label/ID to double tap (or use `--point`) |

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --point <point>` | Coordinates to double tap (`x,y`) |
| `--geometry <geometry>` | Coordinate geometry (`points` only) |
| `--by-id` | Search by accessibility identifier |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator type

Type text into the focused element.

```bash
flowdeck ui simulator type "hello@example.com" -S "iPhone 16"
flowdeck ui simulator type "hunter2" -S "iPhone 16" --mask
flowdeck ui simulator type "New Value" -S "iPhone 16" --clear
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<text>` | Text to type |

**Options:**
| Option | Description |
|--------|-------------|
| `--clear` | Clear the field before typing |
| `--mask` | Mask the typed text in terminal output and JSON |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator swipe

Swipe on the screen.

```bash
flowdeck ui simulator swipe up -S "iPhone 16"
flowdeck ui simulator swipe --from 120,700 --to 120,200 --duration 0.5 -S "iPhone 16"
flowdeck ui simulator swipe down --distance 0.25 -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<direction>` | Swipe direction: `up`, `down`, `left`, or `right` |

**Options:**
| Option | Description |
|--------|-------------|
| `--from <point>` | Start point (`x,y`) |
| `--to <point>` | End point (`x,y`) |
| `--geometry <geometry>` | Coordinate geometry (`points` only) |
| `--duration <seconds>` | Swipe duration in seconds (default: `0.3`) |
| `--distance <fraction>` | Swipe distance as a fraction of the screen (`0.05`-`0.95`, default: `0.4`) |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator scroll

Scroll content one viewport at a time. Each call advances ~one screen (with a small overlap so
nothing at the seam is skipped) and returns the settled screen plus `moved`/`reached_end`.

```bash
flowdeck ui simulator scroll --direction DOWN -S "iPhone 16"            # one page down, returns new screen
flowdeck ui simulator scroll --until "Settings" -S "iPhone 16"          # scroll until visible, returns screen
flowdeck ui simulator scroll --until "id:yourElement" -S "iPhone 16"
flowdeck ui simulator scroll -d DOWN --no-screen -S "iPhone 16"         # terse (no tree)
```

**Options:**
| Option | Description |
|--------|-------------|
| `-d, --direction <direction>` | Scroll direction by content: `UP`, `DOWN`, `LEFT`, `RIGHT` (default `DOWN`) |
| `-s, --speed <speed>` | Scroll speed `0`-`100` (default: `40`) |
| `--distance <fraction>` | Distance as a fraction of the screen (`0.05`-`0.95`, default: `0.85` ≈ one viewport) |
| `--until <target>` | Scroll until the target (label or `id:<identifier>`) is visible, then return the settled screen |
| `--timeout <ms>` | Timeout for `--until` in **milliseconds** (default `20000`). Note: iOS uses ms; the macOS `ui mac scroll --timeout` uses seconds — do not copy values across platforms. |
| `--screen` / `--no-screen` | Return the settled screen after scrolling (default on). `--no-screen` suppresses the tree. |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

**Notes:**
- The result includes `moved` (did content move) and `reached_end` (content didn't move = bottom/top). When `reached_end:true`, **stop scrolling** — repeating won't help.
- To reach a known off-screen element, prefer `--until`: one call scrolls until it appears (or content stops), instead of a manual scroll/check loop.
- The stroke stays inside a safe band, so it won't catch the pinned bottom search bar or the home-indicator system gesture.

#### ui simulator back

Navigate back with the simulator back gesture.

```bash
flowdeck ui simulator back -S "iPhone 16"
```

**Options:**
| Option | Description |
|--------|-------------|
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator pinch

Pinch to zoom in or out.

```bash
flowdeck ui simulator pinch out -S "iPhone 16"
flowdeck ui simulator pinch in --scale 0.6 --point 200,400 -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<direction>` | `in` for zoom out, `out` for zoom in |

**Options:**
| Option | Description |
|--------|-------------|
| `--scale <scale>` | Scale factor (defaults: `2.0` for `out`, `0.5` for `in`) |
| `-p, --point <point>` | Pinch center point (`x,y`) |
| `--geometry <geometry>` | Coordinate geometry (`points` only) |
| `--duration <seconds>` | Pinch duration in seconds |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator wait

Wait for an element condition.

```bash
flowdeck ui simulator wait "Loading..." -S "iPhone 16"
flowdeck ui simulator wait "Submit" --enabled --timeout 15 -S "iPhone 16"
flowdeck ui simulator wait "Toast" --gone -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<target>` | Element to wait for |

**Options:**
| Option | Description |
|--------|-------------|
| `-t, --timeout <seconds>` | Timeout in seconds (default: `30`) |
| `--poll <ms>` | Poll interval in milliseconds (default: `500`) |
| `--gone` | Wait for the element to disappear |
| `--enabled` | Wait for the element to become enabled |
| `--stable` | Wait for the element to stop moving |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator assert

Assert element conditions.

```bash
flowdeck ui simulator assert visible "Profile" -S "iPhone 16"
flowdeck ui simulator assert hidden "Spinner" -S "iPhone 16"
flowdeck ui simulator assert enabled "Submit" -S "iPhone 16"
flowdeck ui simulator assert disabled "Continue" -S "iPhone 16"
flowdeck ui simulator assert text "Welcome" -S "iPhone 16" --expected "Hello"
```

**Subcommands:**
| Subcommand | Description |
|------------|-------------|
| `visible <target>` | Assert the element is visible |
| `hidden <target>` | Assert the element is hidden |
| `enabled <target>` | Assert the element is enabled |
| `disabled <target>` | Assert the element is disabled |
| `text <target>` | Assert the element text matches |

**Common Options:**
| Option | Description |
|--------|-------------|
| `--by-id` | Search by accessibility identifier |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

**Text Options:**
| Option | Description |
|--------|-------------|
| `--expected <text>` | Expected text value |
| `--contains` | Check whether the text contains the expected value |

#### ui simulator erase

Erase text from the focused field.

```bash
flowdeck ui simulator erase -S "iPhone 16"
flowdeck ui simulator erase --characters 5 -S "iPhone 16"
```

**Options:**
| Option | Description |
|--------|-------------|
| `-c, --characters <count>` | Number of characters to erase (omit to clear all) |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator hide-keyboard

Hide the on-screen keyboard.

```bash
flowdeck ui simulator hide-keyboard -S "iPhone 16"
```

**Options:**
| Option | Description |
|--------|-------------|
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator key

Send HID keyboard key codes.

```bash
flowdeck ui simulator key 40 -S "iPhone 16"
flowdeck ui simulator key --sequence 40,42 -S "iPhone 16"
flowdeck ui simulator key 42 --hold 0.2 -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<keycode>` | HID keycode (for example `40` for Enter, `42` for Backspace) |

**Options:**
| Option | Description |
|--------|-------------|
| `--sequence <codes>` | Comma-separated HID keycodes |
| `--hold <seconds>` | Hold duration in seconds |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

**Notes:**
- `key` expects numeric HID keycodes, not string names. For example, Enter/Return is `40`.
- If you are unsure which keycode you need, run `flowdeck ui simulator key --help` before retrying.

#### ui simulator open-url

Open a URL or deep link in the simulator.

```bash
flowdeck ui simulator open-url https://example.com -S "iPhone 16"
flowdeck ui simulator open-url myapp://path -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<url>` | URL or deep link to open |

**Options:**
| Option | Description |
|--------|-------------|
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

**Notes:**
- `open-url` hands the URL to the simulator/OS. It may open Safari or another registered app.
- Do not use `open-url` to validate browser-app navigation. Use the browser's own address bar and controls instead.

#### ui simulator clear-state

Clear app data/state from the simulator.

```bash
flowdeck ui simulator clear-state com.example.app -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<bundle-id>` | Bundle identifier for the app to reset |

**Options:**
| Option | Description |
|--------|-------------|
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator rotate

Rotate with a two-finger gesture.

```bash
flowdeck ui simulator rotate 90 -S "iPhone 16"
flowdeck ui simulator rotate -45 --point 200,400 --radius 80 --duration 0.5 -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<angle>` | Rotation angle in degrees (positive = clockwise, negative = counterclockwise) |

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --point <point>` | Rotation center point (`x,y`) |
| `--radius <radius>` | Radius in points for the two-finger rotation (default: `80`) |
| `--geometry <geometry>` | Coordinate geometry (`points` only) |
| `--duration <seconds>` | Rotate duration in seconds |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator set-appearance

Hidden alias for `flowdeck simulator appearance set <mode>`. The canonical command lives under `simulator`; this `ui` alias exists for ergonomics but does not appear in `flowdeck ui simulator --help`. See `resources/simulator.md` for the full surface.

#### ui simulator button

Hidden alias for `flowdeck simulator button`. The canonical command lives under `simulator`; this `ui` alias exists for ergonomics but does not appear in `flowdeck ui simulator --help`. See `resources/simulator.md` for the full surface.

#### `ui simulator touch`

Low-level touch event group. Nested subcommands:

- `flowdeck ui simulator touch down <x,y> -S "<simulator>"` — press at coordinates.
- `flowdeck ui simulator touch up <x,y> -S "<simulator>"` — release at coordinates.

Use these only when higher-level gestures (`tap`, `swipe`, `pinch`, `rotate`) do not fit. Always pair a `down` with an `up`.

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<point>` | Point coordinates (`x,y`) in screen points |

**Options:**
| Option | Description |
|--------|-------------|
| `--geometry <geometry>` | Coordinate geometry (`points` only) |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### UI Timing Tuning (Simulator)

Set these environment variables when you need to slow input or improve stability:

- `FLOWDECK_HID_STABILIZATION_MS` adds settle time between HID events (default: `25`)
- `FLOWDECK_TYPE_DELAY_MS` adds per-character typing delay (default: `20`)

---

## macOS App Automation (`flowdeck ui mac`)

Use `flowdeck ui mac` for automating native macOS apps via the Accessibility framework and CGEvent-based input. This works on any running macOS GUI app — your own builds, system apps, or third-party apps.

**Guidance (mirrors iOS — same workflow, different targeting flag):**
- **Drive in the background by default — pass `--background` on every action command** (`click`/`tap`, `double-click`, `right-click`, `type`, `key`, `hotkey`, `scroll`, `launch`). Events reach the app via accessibility actions / window-targeted system events, so they never move the user's cursor or steal focus — the user keeps working while you automate, and you don't need to ask. **Limits that require asking first:** (1) background taps act on a real element via `AXPress`, so **target by `--by-id`/label, not coordinates** — a coordinate `--point` tap is best-effort in the background and may not register; prefer element targets and fall back to foreground only when nothing but a coordinate works. (2) `drag`, `swipe`, and timed long-press have **no background path** (continuous gesture recognizers need a key window) — they error under `--background`. (3) macOS menu access can affect the active desktop or require foreground state depending on the target app. Confirm with the user before any foreground step, menu-driving step, permission prompt, or other action that can take focus.
- **Check permissions first**: run `flowdeck ui mac check-permissions` — Accessibility and Screen Recording must be granted before any other `ui mac` command works.
- **Most `ui mac` action commands require `--app`.** Exceptions: `list screens`, `list permissions`, `launch` (uses `--bundle-id`), `check-permissions`, `request-permissions`, and `move` (when not app-scoped). Run `flowdeck ui mac <subcommand> --help` if unsure.
- App resolution: numeric → PID, contains dot → bundle ID, otherwise → fuzzy name match. Wrap names with spaces in quotes: `--app "Visual Studio Code"`.
- **Start a session BEFORE any UI work**: `flowdeck ui mac session start --app "MyApp" --json`. Parse the JSON output. It returns `latest_screenshot` (`latest.jpg`), `latest_interactive_tree` (`latest-interactive-tree.json`), and `latest_tree` (`latest-tree.json`) as absolute paths. Same artifact roles as iOS: read the **interactive tree** to choose actions, the **screenshot** for content/positioning, the **full tree** only as fallback. `ui mac screen` is a one-off fallback, not the default loop.
  - macOS note: the interactive tree excludes the *closed* menu bar (the app's always-present, hundreds-of-items menu hierarchy). An **open** menu's items DO appear (they become shown), so you can read and click them. For driving menus without opening them, `flowdeck ui mac menu list/click` still works.
- **Prefer code-aware automation when you have the app source**: read the SwiftUI/AppKit views for exact labels/identifiers and navigation, plan, drive with `batch`, verify lean. See the iOS "Code-aware automation" section above — the same approach applies to macOS.
- **With `--background` you do NOT activate** — events are delivered straight to the target app, so the user's frontmost app is untouched. Only `flowdeck ui mac activate --app "MyApp"` when you deliberately need the app frontmost: a foreground-only gesture (drag/swipe/long-press), or showing the app to the user. Activating steals focus, so confirm with the user first.
- **Verify after EVERY action by re-reading the tree** (macOS `ui mac` actions do not return the screen inline the way iOS does, so you re-read the session's `latest_interactive_tree` — it reflects the settled state). Do **not** insert `sleep`/`wait` shell commands, and do **not** read `latest_screenshot` to check values — read values from the tree's `value`/`label` fields; screenshot only when a value has no accessibility label or you need pixel layout.
- **If a session looks stale, restart it**: run `flowdeck ui mac session start --app "MyApp" --json` again, replace the saved `latest_*` paths, and continue with the restarted session. Do not switch to `screen` as the first response to suspected staleness.
- **Targeting modes are exclusive, not stackable.** Pick one:
  - default (no flag) — exact label match
  - `--by-id` — accessibility identifier match
  - `--by-role` — role match (e.g. `Button`, `TextField`)
  - `--contains` — substring match against labels (only this one combines with default-mode targeting)

  Prefer `--by-id` when accessibility identifiers exist — it is faster and unambiguous.
- Coordinates are screen-absolute points (matching `find` output). Do not scale by Retina factors.
- `click` is the primary command on macOS (`tap` is a hidden alias). Use `right-click` for context menus.
- **Do not invent FlowDeck syntax**: if unsure about flags, run `flowdeck ui mac <subcommand> --help`.
- **macOS `ui mac` subcommands accept ONLY `--json` and `-h`.** There is no `-j`, no `-v`/`--verbose`, and no `-e`/`--examples` on the mac side — those are iOS-only.

**Background support (`--background`):**

| Command | With `--background` |
|---|---|
| `click`/`tap` by id/label | `AXPress` the element; a text-field target is **focused** so you can type into it. **Reliable — prefer this.** |
| `click`/`tap --point` | best-effort window-targeted mouse click; **may not register** — prefer an element target, use foreground if a coordinate is required |
| `type` | real keystrokes into the focused field (focus the field first with a background tap) |
| `key`/`hotkey` | keystrokes delivered to the app's PID |
| `double-click`/`right-click` | `AXOpen`/`AXPress` / `AXShowMenu` (element target required) |
| `scroll` | scroll bar `AXValue`; `--until` uses `AXScrollToVisible` |
| `launch` | opens without foregrounding |
| `find`/`wait`/`assert`/`screen`/`list` | read-only or AX — never steal focus (no flag needed) |
| `menu list` / `menu click` | AX menu access; ask first when the menu action may affect the active desktop or require foreground state |
| `drag`, `swipe`, timed long-press | **not supported in background** — error loudly; need a foreground key window |

#### ui mac session

Start or stop a background capture session for a macOS app. Captures screenshots and accessibility trees continuously at a configurable interval. `session start` stops any active macOS session first and writes captures into `./.flowdeck/automation/mac-sessions/<session-short-id>/`.

```bash
flowdeck ui mac session start --app "Safari" --json
flowdeck ui mac session stop
```

**Options (`session start`):**
| Option | Description |
|--------|-------------|
| `--app <name-or-bid-or-pid>` | Target app (required) |
| `--interval-ms <ms>` | Capture interval in milliseconds (default: `500`) |
| `--retention-seconds <seconds>` | Retention window in seconds (default: `60`) |

**Session Files:**
- `latest.jpg` points to the latest screenshot.
- `latest-interactive-tree.json` points to the latest interactive tree (actionable controls only) — read this to choose actions.
- `latest-tree.json` points to the latest full accessibility tree (fallback).
- `latest.json` points to the latest capture metadata.
- JSON output from `session start` includes absolute paths for the session directory and latest files.

**JSON output keys.** `session start --json` returns `session_dir`, `latest_screenshot`, `latest_interactive_tree`, `latest_tree`, and `session_short_id`. Read `latest_interactive_tree` to decide actions, `latest_screenshot` for content/positioning, and `latest_tree` only as a fallback. Use the path values from the JSON, not the filenames as keys.

**Usage pattern (same as iOS simulator sessions):**
1. Start the session: `flowdeck ui mac session start --app "MyApp" --json`
2. Parse the JSON output. Extract `latest_screenshot`, `latest_tree`, and `session_dir` paths.
3. Read `latest-tree.json` with the Read tool to discover elements.
4. Read `latest.jpg` (latest screenshot) with the Read tool to see the UI.
5. Interact with the app using `flowdeck ui mac click`, `type`, `scroll`, etc.
6. After each action, re-read `latest-tree.json` to verify (it reflects the settled state — no `sleep` needed). Read values from the tree, not from screenshots.
7. Stop the session when done: `flowdeck ui mac session stop`

**If the session appears stale:**
1. Wait briefly and re-read the same `latest.jpg` / `latest-tree.json` paths.
2. If they still do not reflect an obvious UI change, run `flowdeck ui mac session start --app "MyApp" --json` again.
3. Save the new paths from the restarted session and continue.

**Differences from iOS simulator sessions:**
- Uses `--app` instead of `-S` (simulator).
- Session data is stored in `.flowdeck/automation/mac-sessions/` (separate from iOS sessions).
- If the target app quits, the session detects consecutive capture failures and stops automatically.
- Requires Accessibility and Screen Recording permissions (macOS 14+ for screenshots).

#### ui mac check-permissions

Check if Accessibility and Screen Recording permissions are granted.

```bash
flowdeck ui mac check-permissions --json
```

#### ui mac request-permissions

Trigger system permission dialogs for Accessibility, Screen Recording, and Automation.

```bash
flowdeck ui mac request-permissions
flowdeck ui mac request-permissions --json
```

**Notes:**
- Prompts for Accessibility, Screen Recording, and Automation (Apple Events) permissions.
- Automation permission is triggered by sending a test Apple Event to Finder.
- After granting permissions in System Settings > Privacy & Security, restart your terminal.

#### ui mac screen

Capture a screenshot and accessibility tree from a macOS app.

```bash
flowdeck ui mac screen --app "Safari" --json                       # screenshot + full tree
flowdeck ui mac screen --app "Safari" --interactive-elements --json # actionable elements only
flowdeck ui mac screen --app "Safari" --output ./screen.png         # save a screenshot to a file
flowdeck ui mac screen --app "Safari" --tree --json                 # tree only (no screenshot)
flowdeck ui mac screen --app "Safari" --mode --json                 # capture full screen, not just the app window
```

**Options:**
| Option | Description |
|--------|-------------|
| `--app <name-or-bid-or-pid>` | Target app (required) |
| `-o, --output <path>` | Output path for screenshot (PNG) |
| `--tree` | Accessibility tree only — no screenshot |
| `--interactive-elements` | Return only the interactive (actionable) elements instead of the full tree |
| `--mode` | Capture the full screen instead of just the app window |
| `--json` | Output as JSON |

**Notes:**
- Screenshots require macOS 14+ and Screen Recording permission.
- Default output is a screenshot plus the **full** accessibility tree. Pass `--interactive-elements` for actionable controls only, or `--tree` for the tree without a screenshot. Read content/positioning from the screenshot; read values and controls from the tree.
- `screen` is the **fallback** for one-off captures. For the verify-after-every-action loop, start a session (`ui mac session start`) and re-read `latest-tree.json` (the tree) — do not read `latest_screenshot` to verify; read values from the tree. Do not call `screen` after every interaction.

#### ui mac click

Click an element by label or accessibility identifier, or click coordinates.

```bash
flowdeck ui mac click "Log In" --app "MyApp" --background
flowdeck ui mac click "login_button" --app "MyApp" --by-id --background
flowdeck ui mac click --point 120,340 --app "MyApp" --background
# Long press has no reliable background path; ask first before foreground use.
flowdeck ui mac click --point 120,340 --duration 2.0 --app "MyApp"
```

**Options:**
| Option | Description |
|--------|-------------|
| `<target>` | Element label/ID to click (or use `--point`) |
| `--app <name-or-bid-or-pid>` | Target app |
| `--point <x,y>` | Click at screen-absolute coordinates |
| `--by-id` | Treat target as an accessibility identifier |
| `--duration <seconds>` | Hold duration (long press) |

#### ui mac double-click

Double-click an element or coordinates.

```bash
flowdeck ui mac double-click "word" --app "TextEdit" --background
flowdeck ui mac double-click --point 200,300 --app "MyApp" --background
```

#### ui mac right-click

Right-click (context menu) an element or coordinates.

```bash
flowdeck ui mac right-click "item" --app "Finder" --background
flowdeck ui mac right-click --point "200,300" --app "MyApp" --background
```

**Notes:**
- **Right-click by label often fails on SwiftUI List rows and other composite views** because the accessibility tree exposes the container, not the child text. If `right-click "Label"` returns "Element not found", extract the element's center coordinates from the tree and use `--point "x,y"` instead.
- `--point` takes a single comma-separated value: `--point 200,300` or `--point "200,300"`. Quoting is optional unless the value contains shell metacharacters. The real failure mode is space-separated values — `--point "200 300"` or two space-separated args like `--point 200 300` — which the parser rejects.

#### ui mac type

Type text into the focused element.

```bash
flowdeck ui mac type "hello@example.com" --app "MyApp" --background
flowdeck ui mac type "secret123" --app "MyApp" --mask --background
flowdeck ui mac type "New Value" --app "MyApp" --clear --background
flowdeck ui mac type "fast typing" --app "MyApp" --delay-ms 5 --background
```

**Options:**
| Option | Description |
|--------|-------------|
| `<text>` | Text to type |
| `--app <name-or-bid-or-pid>` | Target app |
| `--clear` | Clear field before typing (Cmd+A, Delete) |
| `--mask` | Mask typed text in terminal output and JSON |
| `--delay-ms <ms>` | Per-character delay in milliseconds |

#### ui mac erase

Erase text from the focused field.

```bash
flowdeck ui mac erase --app "MyApp"
flowdeck ui mac erase --characters 5 --app "MyApp"
```

**Options:**
| Option | Description |
|--------|-------------|
| `--characters <count>` | Number of characters to erase (omit to clear all via Cmd+A, Delete) |

#### ui mac key

Press a key by name or virtual keycode.

```bash
flowdeck ui mac key --name return --app "MyApp" --background
flowdeck ui mac key --name escape --app "MyApp" --background
flowdeck ui mac key --keycode 36 --app "MyApp" --background
```

**Options:**
| Option | Description |
|--------|-------------|
| `--name <key>` | Key name: `return`, `escape`, `tab`, `delete`, `space`, `f1`-`f12`, arrows, etc. |
| `--keycode <code>` | Raw virtual keycode |

**Notes:**
- Use `--name` for human-readable keys. Use `--keycode` for keys without a named mapping.
- Must specify either `--name` or `--keycode`.
- **DO NOT pass key names as positional arguments.** `key "delete"` will fail. Use `key --name delete`.
- **DO NOT confuse with iOS `key`**, which takes numeric HID keycodes. macOS `key` uses `--name` or `--keycode`.

#### ui mac hotkey

Press a keyboard shortcut combination.

```bash
flowdeck ui mac hotkey "cmd+s" --app "TextEdit" --background
flowdeck ui mac hotkey "cmd+shift+z" --app "MyApp" --background
flowdeck ui mac hotkey "cmd+c" --app "Safari" --background
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<combo>` | Modifier+key combo using `+` separator |

**Supported modifiers:** `cmd`/`command`, `shift`, `ctrl`/`control`, `alt`/`option`

#### ui mac scroll

Scroll in a direction within the app's focused window.

```bash
flowdeck ui mac scroll --direction down --app "Safari" --background
flowdeck ui mac scroll --direction up --amount 10 --app "MyApp" --background
flowdeck ui mac scroll --direction down --smooth --app "MyApp" --background
```

**Options:**
| Option | Description |
|--------|-------------|
| `--direction <dir>` | `up`, `down`, `left`, or `right` (required) |
| `--amount <ticks>` | Scroll magnitude in discrete ticks (default: `3`) |
| `--smooth` | Smooth scrolling with many small ticks and delays |
| `--until <target>` | Scroll until element is visible (label or `id:identifier`) |
| `--timeout <seconds>` | Timeout for `--until` in **seconds** (default: `30`). Note: macOS uses seconds; the iOS `ui simulator scroll --timeout` uses milliseconds — do not copy values across platforms. |

**Notes:**
- A session must already be running (`flowdeck ui mac session start --app "MyApp" --json`) so you can verify the result by re-reading `latest-tree.json` after each scroll. Same rule as iOS — never scroll blind.
- Use `--background` so the scroll targets the app without moving the cursor or taking focus.
- Scrolling is performed at the center of the app's target window. With `--background`, the foreground cursor is left alone.
- `--amount` is discrete scroll wheel ticks, not pixels or fractions. Small values (1-10) produce subtle scrolls. For reaching off-screen content, prefer `--until "Element"` over guessing amounts.
- `--until` scrolls repeatedly at window center and checks the accessibility tree after each scroll. Use `id:myElement` to match by accessibility identifier. Note: `--until` still scrolls at window center, so the scrollable region must be under the center for this to work.

```bash
flowdeck ui mac scroll --direction down --app "Safari" --background
flowdeck ui mac scroll --direction down --until "id:bottomButton" --app "MyApp" --background
flowdeck ui mac scroll --direction down --until "Save" --timeout 15 --app "MyApp" --background
```

#### ui mac move

Move cursor to a screen point without clicking.

```bash
flowdeck ui mac move --point 500,300
flowdeck ui mac move --point 500,300 --app "MyApp"
```

#### ui mac drag

Drag from one point to another.

```bash
flowdeck ui mac drag --from 100,200 --to 400,500 --app "MyApp"
flowdeck ui mac drag --from 100,200 --to 400,500 --duration 1.0 --app "MyApp"
```

**Options:**
| Option | Description |
|--------|-------------|
| `--from <x,y>` | Start point (screen-absolute) |
| `--to <x,y>` | End point (screen-absolute) |
| `--duration <seconds>` | Drag duration (default: `0.5`) |

#### ui mac swipe

Swipe in a direction from the window center.

```bash
flowdeck ui mac swipe --direction up --app "MyApp"
flowdeck ui mac swipe --direction left --distance 400 --app "MyApp"
```

**Options:**
| Option | Description |
|--------|-------------|
| `--direction <dir>` | `up`, `down`, `left`, or `right` (required) |
| `--distance <points>` | Swipe distance in points (default: `200`) |
| `--duration <seconds>` | Swipe duration (default: `0.5`) |

#### ui mac find

Find an element in the accessibility tree.

```bash
flowdeck ui mac find "Settings" --app "MyApp"
flowdeck ui mac find "settings_button" --app "MyApp" --by-id
flowdeck ui mac find "button" --app "MyApp" --by-role
flowdeck ui mac find "Log" --app "MyApp" --contains
```

**Options:**
| Option | Description |
|--------|-------------|
| `<target>` | Element to find (label, ID, or role) |
| `--by-id` | Search by accessibility identifier |
| `--by-role` | Search by element role |
| `--contains` | Substring match against labels |

**Notes:**
- Returns element role, center coordinates (screen-absolute), enabled state, and text.
- Provides suggestions when no exact match is found.

#### ui mac list

List apps, windows, screens, or permissions.

```bash
flowdeck ui mac list apps --json
flowdeck ui mac list apps --include-agents --include-system
flowdeck ui mac list windows --app "Safari" --json
flowdeck ui mac list screens --json
flowdeck ui mac list permissions --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<what>` | `apps`, `windows`, `screens`, or `permissions` |

**Options (apps):**
| Option | Description |
|--------|-------------|
| `--include-agents` | Include background agent apps |
| `--include-system` | Include system processes |

**Options (windows):**
| Option | Description |
|--------|-------------|
| `--app <name-or-bid-or-pid>` | Target app (required for windows) |

#### ui mac wait

Wait for an element condition.

```bash
flowdeck ui mac wait "Loading..." --app "MyApp"
flowdeck ui mac wait "Submit" --app "MyApp" --condition enabled --timeout 15
flowdeck ui mac wait "Toast" --app "MyApp" --condition gone
flowdeck ui mac wait "save_button" --app "MyApp" --by-id
```

**Options:**
| Option | Description |
|--------|-------------|
| `<target>` | Element to wait for |
| `--condition <cond>` | `exists` (default), `gone`, `enabled`, `stable` |
| `--timeout <seconds>` | Timeout in seconds (default: `30`) |
| `--by-id` | Treat target as accessibility identifier |

**Notes:**
- `--condition` is validated — invalid values produce an error with the list of valid conditions.

#### ui mac assert

Assert element conditions with immediate pass/fail (no polling).

```bash
flowdeck ui mac assert visible "Profile" --app "MyApp"
flowdeck ui mac assert hidden "Spinner" --app "MyApp"
flowdeck ui mac assert enabled "Submit" --app "MyApp"
flowdeck ui mac assert disabled "Continue" --app "MyApp"
flowdeck ui mac assert text "Welcome" --app "MyApp" --expected "Hello"
flowdeck ui mac assert text "title_label" --app "MyApp" --by-id --expected "Dashboard" --contains
```

**Subcommands:**
| Subcommand | Description |
|------------|-------------|
| `visible <target>` | Assert element is visible |
| `hidden <target>` | Assert element is hidden |
| `enabled <target>` | Assert element is enabled |
| `disabled <target>` | Assert element is disabled |
| `text <target>` | Assert element text matches `--expected` value |

**Common Options:**
| Option | Description |
|--------|-------------|
| `--by-id` | Treat target as accessibility identifier |
| `--app` | Target app |

**Text Options:**
| Option | Description |
|--------|-------------|
| `--expected <text>` | Expected text value (required) |
| `--contains` | Check whether text contains expected value |

#### ui mac launch

Launch an app by bundle ID.

```bash
flowdeck ui mac launch --bundle-id com.apple.Safari
```

#### ui mac activate

Bring a running app to the foreground. This takes focus; ask first unless the user explicitly requested foreground visibility.

```bash
flowdeck ui mac activate --app "Safari"
```

#### ui mac quit

Quit an app gracefully or forcefully.

```bash
flowdeck ui mac quit --app "TextEdit"
flowdeck ui mac quit --app "MyApp" --force
```

**Options:**
| Option | Description |
|--------|-------------|
| `--force` | Force-terminate the app |

#### ui mac window

Window management subcommands. `window focus` takes focus; ask first unless the user explicitly requested foreground visibility.

```bash
flowdeck ui mac window list --app "Safari" --json
flowdeck ui mac window move --app "Safari" --to 100,100
flowdeck ui mac window resize --app "Safari" --size 1200,800
flowdeck ui mac window focus --app "Safari" --index 1
```

**Subcommands:**
| Subcommand | Description | Key Options |
|------------|-------------|-------------|
| `list` | List app windows | `--app` |
| `move` | Move a window | `--app`, `--to <x,y>`, `--index` |
| `resize` | Resize a window | `--app`, `--size <w,h>`, `--index` |
| `focus` | Focus a window | `--app`, `--index` |

#### ui mac menu

Menu bar interaction. Ask first when the menu action may affect the active desktop or require foreground state.

```bash
flowdeck ui mac menu list --app "TextEdit" --json
# Ask first when the menu action may affect the active desktop or require foreground state.
flowdeck ui mac menu click "File > Export as PDF" --app "TextEdit"
flowdeck ui mac menu click "Edit > Find > Find..." --app "Safari"
```

**Subcommands:**
| Subcommand | Description | Key Options |
|------------|-------------|-------------|
| `list` | List menu bar items and hierarchy | `--app` |
| `click` | Click a menu item by path (`>` separated) | `--app`, `<path>` |

#### UI Timing Tuning (macOS)

Same environment variables apply:

- `FLOWDECK_HID_STABILIZATION_MS` adds settle time between input events (default: `25`)
- `FLOWDECK_TYPE_DELAY_MS` adds per-character typing delay (default: `1`)

---

## Classifying Findings

After verifying, classify each finding before reporting it. This determines whether it needs a fix, a re-check, or no action.

### Always report

**Functional bug:** element does not respond to tap/click, navigation goes to the wrong screen, expected UI element is absent, data is not displayed, form cannot be submitted, action has no visible effect.

**Visual/layout bug:** overlapping text, truncated labels, elements rendered off-screen or clipped, wrong colors or materials, broken alignment. Report these even if the app is functional — layout bugs are bugs.

**Unexpected exit:** crash or process termination. Read `flowdeck logs` for the crash details before reporting.

### Do not report

**Transient state:** loading spinner during a network request, brief animations after navigation, keyboard appearing/dismissing, skeleton loaders. Capture the tree again after the transition completes before deciding.

**Expected behavior:** empty state placeholder when there is no data, disabled button when a required field is empty, permission dialog on first launch, error state from a test environment (no network, missing credentials).

### Dig deeper before reporting

**No response to tap:** the view may have been mid-animation or the element off-screen. Re-read the tree and retry once from updated coordinates. If it still fails, report as a functional bug.

**Intermittent:** if the issue appears only once and the tree looks correct on re-read, note it as a potential timing issue and suggest adding a `wait` before the interaction.

---
