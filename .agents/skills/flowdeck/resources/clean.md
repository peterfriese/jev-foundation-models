# clean - Clean Build Artifacts

Removes build artifacts to ensure a fresh build.

```bash
# Clean project build artifacts (scheme-specific)
flowdeck clean -w App.xcworkspace -s MyApp

# Delete ALL FlowDeck DerivedData (~/Library/Developer/FlowDeck/DerivedData)
flowdeck clean --derived-data

# Delete ALL Xcode DerivedData (~/Library/Developer/Xcode/DerivedData)
flowdeck clean --xcode-derived-data

# Delete Xcode cache (~/Library/Caches/com.apple.dt.Xcode)
flowdeck clean --xcode-cache

# Clean everything: scheme artifacts + FlowDeck/Xcode derived data + Xcode cache
flowdeck clean --all

# Clean with verbose output
flowdeck clean --all --verbose
```

`--json` is supported on every option but is rarely needed — `clean` produces a single result line. See SKILL.md → OUTPUT FORMAT.

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory |
| `-w, --workspace <path>` | Path to .xcworkspace or .xcodeproj |
| `-s, --scheme <name>` | Scheme name |
| `-d, --derived-data-path <path>` | Custom derived data path for scheme clean |
| `--derived-data` | Delete the entire FlowDeck DerivedData root at `~/Library/Developer/FlowDeck/DerivedData` — this clears every worktree's cached build artifacts |
| `--xcode-derived-data` | Delete entire ~/Library/Developer/Xcode/DerivedData |
| `--xcode-cache` | Delete Xcode cache (~/Library/Caches/com.apple.dt.Xcode) |
| `--all` | Clean everything: scheme + FlowDeck/Xcode derived data + Xcode cache |
| `-c, --config <path>` | Path to JSON config file |
| `-j, --json` | Output JSON events |
| `-v, --verbose` | Show clean output in console (default: progress indicator only) |
| `-e, --examples` | Show usage examples |

**When to Use:**
| Problem | Solution |
|---------|----------|
| "Module not found" errors (FlowDeck) | `flowdeck clean --derived-data` |
| "Module not found" errors (Xcode) | `flowdeck clean --xcode-derived-data` |
| Autocomplete not working | `flowdeck clean --xcode-cache` |
| Build is using old code | `flowdeck clean --derived-data` |
| Xcode feels broken | `flowdeck clean --all` |
| After changing build settings | `flowdeck clean -w <ws> -s <scheme>` |

**There is no `flowdeck clean --simulator`.** To erase simulator state, use `flowdeck simulator erase <name-or-udid>`. To prune unused sims, use `flowdeck simulator prune`.

---
