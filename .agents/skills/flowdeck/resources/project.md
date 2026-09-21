# project - Inspect Project Structure

Inspect schemes, build configurations, scaffold new projects, sync provisioning
profiles, and manage Swift packages.

```
flowdeck project <subcommand>
```

| Subcommand | Description |
|------------|-------------|
| `create` | Create a new Xcode project from template |
| `schemes` | List all schemes in a workspace or project |
| `configs` | List available build configurations |
| `packages` | Manage Swift Package Manager dependencies (own subcommand tree) |
| `sync-profiles` | Sync provisioning profiles (triggers a build with automatic signing) |

Workspace resolution: commands that take `-w/--workspace` fall back to the saved
`flowdeck config set` workspace when the flag is omitted. `-p/--project` points
at a project directory and defaults to the current directory.

Only `schemes` and `configs` accept `-e, --examples`. `create`, `packages`
(and its subcommands), and `sync-profiles` do not.

---

## project create

Create a new Xcode project from template. The template is SwiftUI; there is no
template flag.

```bash
# Create a new SwiftUI iOS project in the current directory
flowdeck project create MyApp

# Set bundle ID and multiple platforms
flowdeck project create MyApp --bundle-id com.example.myapp --platforms ios,macos,visionos

# Choose output directory and deployment targets
flowdeck project create MyApp --path ./apps --ios-target 17.0 --macos-target 14.0

# iOS app with a companion watchOS app
flowdeck project create MyApp --watch-companion
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<name>` | App name, e.g. `MyApp` (required) |

**Options:**
| Option | Description | Default |
|--------|-------------|---------|
| `-b, --bundle-id <bundle-id>` | Bundle identifier | `com.example.<name>` |
| `--platforms <platforms>` | Comma-separated: `ios`, `macos`, `tvos`, `visionos`, `watchos` | `ios` |
| `-o, --path <path>` | Output directory | current directory |
| `--ios-target <version>` | iOS deployment target | `26.0` |
| `--macos-target <version>` | macOS deployment target | `26.0` |
| `--tvos-target <version>` | tvOS deployment target | `26.0` |
| `--watchos-target <version>` | watchOS deployment target | `26.0` |
| `--visionos-target <version>` | visionOS deployment target | `26.0` |
| `--watch-companion` | Create an iOS app with a companion watchOS app (flag) | off |
| `-j, --json` | Output as JSON | |

**Notes:**
- Multi-platform targets are only available when those SDKs are installed in Xcode.
- `create` has no `-e/--examples` flag.

---

## project schemes

List all schemes available in a workspace or project.

```bash
# List all schemes (uses saved workspace)
flowdeck project schemes

# JSON output
flowdeck project schemes --json

# Point at a specific project directory
flowdeck project schemes -p /path/to/project

# Get scheme names for CI
flowdeck project schemes --json | jq -r '.[].name'
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <project>` | Project directory (defaults to current directory) |
| `-w, --workspace <workspace>` | Path to `.xcworkspace` or `.xcodeproj` |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

---

## project configs

List all build configurations (e.g. Debug, Release) available in a workspace or
project.

```bash
# List configurations (uses saved workspace)
flowdeck project configs

# JSON output
flowdeck project configs --json

# With an explicit workspace
flowdeck project configs -w MyApp.xcworkspace
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <project>` | Project directory (defaults to current directory) |
| `-w, --workspace <workspace>` | Path to `.xcworkspace` or `.xcodeproj` |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

---

## project sync-profiles

Sync provisioning profiles. This triggers a build with automatic signing so
Xcode downloads/refreshes the matching profiles.

```bash
flowdeck project sync-profiles -w App.xcworkspace -s MyApp
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <project>` | Project directory (defaults to current directory) |
| `-w, --workspace <workspace>` | Path to `.xcworkspace` or `.xcodeproj` |
| `-s, --scheme <scheme>` | Scheme name |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed xcodebuild output |

No `-e/--examples` flag.

---

## project packages - Manage Swift Packages

Manage Swift Package Manager dependencies.

```
flowdeck project packages <subcommand>
```

| Subcommand | Positional arg | Description |
|------------|----------------|-------------|
| `list` | — | List installed Swift packages (direct + transitive) |
| `add` | `<url>` | Add a Swift package dependency |
| `remove` | `<package-identifier>` | Remove a Swift package dependency |
| `resolve` | — | Resolve package dependencies |
| `update` | — | Delete cache and re-resolve packages |
| `clear` | — | Clear the package cache (`SourcePackages` directory) |
| `link` | `<package-url>` | Link package products to a target |
| `unlink` | `<package-url>` | Unlink package products from a target |
| `targets` | — | List project targets with their product types |

**Common options (every subcommand):**
| Option | Description |
|--------|-------------|
| `-p, --project <project>` | Project directory (defaults to current directory) |
| `-w, --workspace <workspace>` | Path to `.xcworkspace` or `.xcodeproj` |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

The `packages` group and its subcommands have no `-e/--examples` flag.

### packages list

List installed Swift packages.

```bash
flowdeck project packages list -w App.xcworkspace
flowdeck project packages list --json
```

Only the common options above.

### packages add

Add a Swift package dependency. `--kind` and `--value` are **required for remote
packages** (HTTPS/SSH URLs) and may be omitted for a local-path dependency.

```bash
# Pin to a version range
flowdeck project packages add https://github.com/owner/repo --kind upToNextMajor --value 1.2.3

# Track a branch
flowdeck project packages add https://github.com/owner/repo --kind branch --value main

# Local path package (no kind/value needed)
flowdeck project packages add ../MyLocalPackage
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<url>` | Package repository URL (HTTPS or SSH) or local path |

**Options (plus common):**
| Option | Description |
|--------|-------------|
| `-k, --kind <kind>` | Version rule type: `upToNextMajor`, `upToNextMinor`, `exact`, `branch`, `revision` (required for remote packages) |
| `-V, --value <value>` | Version, branch name, or revision (required for remote packages) |

### packages remove

Remove a Swift package dependency by its URL or identity.

```bash
flowdeck project packages remove https://github.com/owner/repo
flowdeck project packages remove repo
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<package-identifier>` | Package URL or identity to remove |

Only the common options.

### packages resolve

Resolve package dependencies.

```bash
flowdeck project packages resolve -w App.xcworkspace
flowdeck project packages resolve -w App.xcworkspace -s MyApp --json
```

**Options (plus common):**
| Option | Description |
|--------|-------------|
| `-s, --scheme <scheme>` | Scheme name |
| `--derived-data-path <path>` | Custom derived data path (defaults to a worktree-specific path under `~/Library/Developer/FlowDeck/DerivedData`) |

### packages update

Delete the cache and re-resolve packages. Same options as `resolve`.

```bash
flowdeck project packages update -w App.xcworkspace
flowdeck project packages update -w App.xcworkspace -s MyApp
```

**Options (plus common):**
| Option | Description |
|--------|-------------|
| `-s, --scheme <scheme>` | Scheme name |
| `--derived-data-path <path>` | Custom derived data path (defaults to a worktree-specific path under `~/Library/Developer/FlowDeck/DerivedData`) |

### packages clear

Clear the Swift package cache (the `SourcePackages` directory). No `--scheme`.

```bash
flowdeck project packages clear -w App.xcworkspace
flowdeck project packages clear --derived-data-path ~/CustomDerivedData
```

**Options (plus common):**
| Option | Description |
|--------|-------------|
| `--derived-data-path <path>` | Custom derived data path (defaults to a worktree-specific path under `~/Library/Developer/FlowDeck/DerivedData`) |

### packages link

Link package products to a target. The positional arg is the **package URL**,
not a product or package name. `--target` and `--products` are **required**.

```bash
flowdeck project packages link https://github.com/owner/repo --target MyApp --products "RepoProduct"
flowdeck project packages link https://github.com/owner/repo -t MyApp --products "ProductA,ProductB"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<package-url>` | Package URL to link products from |

**Options (plus common):**
| Option | Description |
|--------|-------------|
| `-t, --target <target>` | Target name to link products to (required) |
| `--products <products>` | Comma-separated list of products to link (required) |

### packages unlink

Unlink package products from a target. Mirrors `link`: positional is the
**package URL**, and `--target` and `--products` are **required**.

```bash
flowdeck project packages unlink https://github.com/owner/repo --target MyApp --products "RepoProduct"
flowdeck project packages unlink https://github.com/owner/repo -t MyApp --products "ProductA,ProductB"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<package-url>` | Package URL to unlink products from |

**Options (plus common):**
| Option | Description |
|--------|-------------|
| `-t, --target <target>` | Target name to unlink products from (required) |
| `--products <products>` | Comma-separated list of products to unlink (required) |

### packages targets

List project targets with their product types (useful before `link`/`unlink` to
find the right target name). Takes no positional args.

```bash
flowdeck project packages targets -w App.xcworkspace
flowdeck project packages targets --json
```

Only the common options.

---

### When to Use

| Problem | Solution |
|---------|----------|
| Need to inspect current packages | `flowdeck project packages list` |
| Need a target name for `link`/`unlink` | `flowdeck project packages targets` |
| "Package not found" / "No such module" errors | `flowdeck project packages resolve` |
| Outdated dependencies | `flowdeck project packages update` |
| Corrupted package cache | `flowdeck project packages clear` |

For repeated package failures, use the escalation playbook in
`resources/package-resolution.md`: `update -> resolve -> clear -> clean`
(`clean` is the last resort).
