# package-resolution - Recover Swift Package Resolution Failures

Use this playbook when builds/tests fail with package errors such as:
- `No such module ...`
- `Package product ... not found`
- Package resolution/download failures

Run the steps in order and stop as soon as the failure is gone.

## Escalation Order (Do Not Skip Ahead)

1. `update`
2. `resolve`
3. `clear`
4. `clean` (last resort)

Always rerun the same failing `flowdeck build` or `flowdeck test` command between steps so you can confirm exactly what fixed the issue.

## Commands

### If Config Exists

```bash
# Step 1: refresh package dependencies
flowdeck project packages update

# Retry the failing command
# flowdeck build
# or: flowdeck test

# Step 2: if still failing
flowdeck project packages resolve

# Retry the same build/test command again
# flowdeck build
# or: flowdeck test

# Step 3: if still failing
flowdeck project packages clear

# Retry the same build/test command again
# flowdeck build
# or: flowdeck test

# Step 4 (last resort): if still failing
flowdeck clean

# Retry the same build/test command again
# flowdeck build
# or: flowdeck test
```

### If No Config (or Explicit Workspace)

```bash
# Step 1: refresh package dependencies
flowdeck project packages update -w <ws>

# Retry the failing command
# flowdeck build -w <ws> -s <scheme> -S "<sim>"
# or: flowdeck test -w <ws> -s <scheme> -S "<sim>"

# Step 2: if still failing
flowdeck project packages resolve -w <ws>

# Retry the same build/test command again
# flowdeck build -w <ws> -s <scheme> -S "<sim>"
# or: flowdeck test -w <ws> -s <scheme> -S "<sim>"

# Step 3: if still failing
flowdeck project packages clear -w <ws>

# Retry the same build/test command again
# flowdeck build -w <ws> -s <scheme> -S "<sim>"
# or: flowdeck test -w <ws> -s <scheme> -S "<sim>"

# Step 4 (last resort): if still failing
flowdeck clean -w <ws> -s <scheme>

# Retry the same build/test command again
# flowdeck build -w <ws> -s <scheme> -S "<sim>"
# or: flowdeck test -w <ws> -s <scheme> -S "<sim>"
```

## Notes

- Add `-s <scheme>` to `packages update/resolve` when the workspace has multiple schemes whose package graphs differ (e.g. app + extension), or when xcodebuild reports `Scheme ... is not currently configured for the resolve-package-dependencies action`. `packages clear` has no `-s` flag, so do not add one there.
- `update`, `resolve`, and `clear` all accept `--derived-data-path`; it defaults to a worktree-specific path under `~/Library/Developer/FlowDeck/DerivedData`. Pass it only when the failing build/test used a custom derived-data path.
- Use `flowdeck clean -w <ws> -s <scheme>` here instead of `flowdeck clean --all`; package failures usually need a project/scheme clean, while `--all` is a broader cache reset (scheme artifacts + FlowDeck/Xcode derived data + Xcode cache) for deeper Xcode or DerivedData problems. See `resources/clean.md`.
- Use `--json` for machine-readable diagnostics (valid on all four steps).
- Example: `flowdeck project packages resolve -w <ws> --json`
- Canonical command reference: https://docs.flowdeck.studio/cli/commands/project/packages
- Local fallback: `flowdeck project packages --help`
