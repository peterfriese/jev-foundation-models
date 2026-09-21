# build - Build the Project

Builds an Xcode project or workspace for the specified target platform.

```bash
# Build for iOS Simulator
flowdeck build -w App.xcworkspace -s MyApp -S "iPhone 16"

# Build for macOS
flowdeck build -w App.xcworkspace -s MyApp -D "My Mac"

# Build for macOS using -S none (equivalent to -D "My Mac")
flowdeck build -w App.xcworkspace -s MyApp -S none

# Build for Mac Catalyst (if supported by the scheme)
flowdeck build -w App.xcworkspace -s MyApp -D "My Mac Catalyst"

# Build for physical iOS device (by name - partial match)
flowdeck build -w App.xcworkspace -s MyApp -D "iPhone"

# Build for physical iOS device (by UDID)
flowdeck build -w App.xcworkspace -s MyApp -D "00008130-001245110C08001C"

# Build Release configuration
flowdeck build -w App.xcworkspace -s MyApp -D "My Mac" -C Release

# Build with JSON output (for automation)
flowdeck build -w App.xcworkspace -s MyApp -S "iPhone 16" -j
flowdeck build -w App.xcworkspace -s MyApp -S "iPhone 16" --json --show-warnings

# Custom derived data path
flowdeck build -w App.xcworkspace -s MyApp -S "iPhone 16" -d /tmp/DerivedData

# Pass extra xcodebuild arguments
flowdeck build -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-options='-quiet'
flowdeck build -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-options='-enableCodeCoverage YES'

# Pass xcodebuild environment variables
flowdeck build -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-env='CI=true'

# Load config from file
flowdeck build --config /path/to/config.json
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
| `--xcodebuild-options <args>` | Extra xcodebuild arguments (use = for values starting with -) |
| `--xcodebuild-env <vars>` | Xcodebuild environment variables (e.g., 'CI=true') |
| `-c, --config <path>` | Path to JSON config file |
| `-j, --json` | Output JSON events |
| `--show-warnings` | Show compiler warnings (console output in text mode, `diagnostic` events in JSON mode) |
| `-v, --verbose` | Show build output in console |
| `-e, --examples` | Show usage examples |

On failure, the CLI prints the extracted reason and a `Full log: <path>` line. Read that file with your file tools instead of rerunning with `--verbose`.

**Note:** Either `--simulator` or `--device` is required unless you've run `flowdeck config set`. Use `--device "My Mac"` for native macOS, or `--device "My Mac Catalyst"` for Catalyst if the scheme supports it.

---
