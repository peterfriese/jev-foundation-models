# run - Build and Run the App

Builds and launches an app on iOS Simulator, physical device, or macOS.

> **Lifecycle + focus.** `flowdeck run` can leave registered app processes behind if you re-run without stopping the previous launch. Agent-origin macOS runs stay in the background by default and do not require asking the user first. Simulator runs may foreground Simulator.app unless `--headless` is passed, and user-triggered macOS runs activate normally. Before re-running:
>
> 1. `flowdeck apps` — find the previous launch's app-id.
> 2. `flowdeck stop <app-id>` — terminate it.
> 3. Then re-run `flowdeck run`.

```bash
# Run on iOS Simulator
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16"

# Run on macOS
flowdeck run -w App.xcworkspace -s MyApp -D "My Mac"

# Run on macOS using -S none (equivalent to -D "My Mac")
flowdeck run -w App.xcworkspace -s MyApp -S none

# Run on Mac Catalyst (if supported by the scheme)
flowdeck run -w App.xcworkspace -s MyApp -D "My Mac Catalyst"

# Run on physical iOS device
flowdeck run -w App.xcworkspace -s MyApp -D "iPhone"

# Run with log streaming (see print() and OSLog output)
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --log

# Run on a simulator without opening Simulator.app (headless simulator)
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --headless

# Run without rebuilding
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --no-build

# Wait for debugger attachment
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --wait-for-debugger

# Pass app launch arguments
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --launch-options='-AppleLanguages (en)'

# Pass app launch environment variables
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --launch-env='DEBUG=1 API_ENV=staging'

# Pass xcodebuild arguments
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-options='-quiet'

# Pass xcodebuild environment variables
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-env='CI=true'

# JSON output with warnings
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --json --show-warnings
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory |
| `-w, --workspace <path>` | Path to .xcworkspace or .xcodeproj (REQUIRED unless flowdeck config set was run) |
| `-s, --scheme <name>` | Scheme name (auto-detected if only one) |
| `-S, --simulator <name>` | Simulator name or UDID (required for iOS/tvOS/watchOS). Accepts `none` as a macOS form (`-S none`). |
| `-D, --device <name>` | Device name/UDID, or "My Mac"/"My Mac Catalyst" for macOS |
| `-C, --configuration <name>` | Build configuration (Debug/Release) |
| `-d, --derived-data-path <path>` | Custom derived data path (defaults to a worktree-specific path under `~/Library/Developer/FlowDeck/DerivedData`) |
| `-l, --log` | Stream logs after launch (print statements + OSLog). Combine with the Bash tool's `run_in_background: true` parameter so the stream does not block subsequent commands. |
| `--wait-for-debugger` | Wait for debugger to attach before app starts |
| `--no-build` | Skip build step and launch existing app |
| `--headless` | Run on the simulator without opening Simulator.app. The app still installs and launches on the (headless) simulator; only the Simulator.app window is suppressed. Simulator targets only — ignored for macOS, Mac Catalyst, and physical devices. |
| `--launch-options <args>` | App launch arguments (use = for values starting with -) |
| `--launch-env <vars>` | App launch environment variables |
| `--xcodebuild-options <args>` | Extra xcodebuild arguments |
| `--xcodebuild-env <vars>` | Xcodebuild environment variables |
| `-c, --config <path>` | Path to JSON config file |
| `-j, --json` | Output JSON events |
| `--show-warnings` | Show compiler warnings (console output in text mode, `diagnostic` events in JSON mode) |
| `-v, --verbose` | Show app console output |
| `-e, --examples` | Show usage examples |

**Note:** Either `--simulator` or `--device` is required unless you've run `flowdeck config set`. Use `--device "My Mac"` for native macOS, or `--device "My Mac Catalyst"` for Catalyst if the scheme supports it.

**Note:** `flowdeck run` opens Simulator.app by default for simulator targets. Pass `--headless` to boot and run the simulator without opening Simulator.app (e.g. when another surface renders it, like FlowDeck's simulator preview). `--headless` only affects simulator targets; it is ignored for macOS, Mac Catalyst, and physical devices.

**Note:** `--no-build` skips the build step and launches the existing build. If no built app is found, the build runs automatically. There is no `--skip-build` flag — the flag is `--no-build`.

**After Launching:**
When the app launches, you'll get an App ID. Use it to:
- Stream logs: `flowdeck logs <app-id>`
- Stop the app: `flowdeck stop <app-id>`
- List all apps: `flowdeck apps`

---
