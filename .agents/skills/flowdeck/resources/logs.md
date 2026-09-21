# logs - Stream Real-time Application Logs

`flowdeck logs` is the **ONLY** way to access application logs. It streams `print()` statements and `OSLog` output in real time from apps launched by FlowDeck. Alias: `log`.

**NEVER use `xcrun simctl spawn … log`, `xcrun simctl log`, `log show`, `log stream`, or any other Apple log CLI.** FlowDeck captures all application output — both `print()` and structured `OSLog` — in a single unified stream. There is no need to query the OS unified log for application output.

```bash
flowdeck logs <app-id>
flowdeck logs com.example.MyApp
flowdeck logs <app-id> --json
flowdeck logs --examples
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<identifier>` | App identifier (short ID, full ID, or bundle ID). Optional — running `flowdeck logs` with no identifier prints usage. Discover an identifier with `flowdeck apps` or read it from the output of `flowdeck run`. |

**Options:**
| Option | Description |
|--------|-------------|
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**Filtering:**
```bash
flowdeck logs <app-id> | rg 'Pattern|thepattern'
flowdeck logs <app-id> --json | rg 'Pattern|thepattern'
```

## How to Stream Logs Correctly

`flowdeck logs` is a **continuous stream** — it prints log lines as they happen and does not exit on its own. To capture logs from a running app:

### Option A: Run with `--log` (preferred for launch-time logs)

```bash
# Streams logs inline after the app launches — captures everything from startup
flowdeck run --log
```

This builds, launches, and immediately begins streaming logs. Invoke this from the Bash tool with the `run_in_background: true` parameter (not a shell flag) so the stream runs in the background while you trigger the action you want to observe.

### Option B: Stream logs separately (preferred for on-demand capture)

```bash
# 1. Find the app ID
flowdeck apps

# 2. Stream logs in the background
flowdeck logs <app-id>       # use run_in_background: true

# 3. Reproduce the action (navigate, tap, etc.) via flowdeck ui
# 4. Read the background task output to see captured logs
```

### Anti-patterns to avoid

| DON'T do this | WHY it fails |
|---------------|-------------|
| `flowdeck logs <id> \| head -N` | Kills the stream immediately — you get only buffered lines, missing the logs you need |
| `flowdeck logs <id>` with a short timeout | Stream may not have received any output yet — you get empty results |
| `xcrun simctl spawn <udid> log show …` | Bypasses FlowDeck — use `flowdeck logs` instead |
| `xcrun simctl log …` or `log stream …` | Bypasses FlowDeck — use `flowdeck logs` instead |

### Correct pattern for capturing specific log output

```bash
# 1. Start log streaming in background (run_in_background: true)
flowdeck logs <app-id>

# 2. Trigger the action that produces the logs you want
flowdeck ui simulator tap "Some Button" -S "iPhone 16" --json

# 3. Wait a few seconds for logs to arrive
sleep 3

# 4. Read the background task output file to see the captured logs
```

**Supported targets:**
- iOS / iPadOS / watchOS / tvOS / visionOS simulators
- macOS apps
- Physical iOS devices

**Notes:**
- `logs` is a live stream — it does not exit until you stop it (Ctrl+C) or the app terminates.
- All `print()` statements and `OSLog` output from the app are captured in a single unified stream.
- Default output is timestamped log lines; `--json` emits structured events for parsing.
- To get the app ID, use `flowdeck apps` or read the output of `flowdeck run`.

---
