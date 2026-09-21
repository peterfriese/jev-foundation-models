# FlowDeck Skill Pack Changelog

## 1.20.2 - 2026-07-03
- Bumped FlowDeck skill pack version to 1.20.2.


## 1.19.0 - 2026-06-25
- Synced the FlowDeck skill pack with CLI 1.19.0.
- Added Xcode 27 beta compatibility for simulator automation that depends on Apple's SimulatorKit shared framework location.

## 1.18.0 - 2026-06-24
- Mac validation now defaults to background-safe automation: agent-origin app runs, UI sessions, read-only UI commands, and `ui mac` actions with `--background` no longer require asking first.
- Foreground or desktop-affecting steps remain gated: app activation, drag/swipe/timed long-press, coordinate-only foreground fallbacks, macOS menu access that may affect the active desktop, permission prompts, and recordings.
- Updated macOS UI examples to show `--background` as the normal path for click/type/key/hotkey/scroll actions.

## 1.16.0 - 2026-05-21
- Re-audited the entire skill against the live CLI command surface (every `--help`/`--examples`, including subcommands hidden from parent help). Reconciled flags, defaults, and examples across all resource files.
- Recording is now documented under `flowdeck simulator` only: `flowdeck simulator record` (video) and `flowdeck simulator frames` (contact sheet / individual images). `flowdeck ui simulator record` was removed from the CLI — `ui` is automation only. Updated SKILL.md, `resources/ui.md`, `resources/simulator.md`, and the Apple-CLI translation table accordingly.
- Added `resources/status.md` (`flowdeck status` project snapshot) and `resources/activity.md` (`flowdeck activity` command history), and wired both into the SKILL.md resource router.
- Added a destructive-op consent note to `resources/uninstall.md`.
- Audited the skill pack against the live CLI (v1.15.1) and refreshed accuracy across every resource file.
- Added an **OUTPUT FORMAT** section to SKILL.md: plain text is the default, `--json` is for parsing / IDs / paths / structured decisions. Lists the commands where `--json` is mandatory (`session start`, `find`, anything feeding a downstream call).
- Added a **Parsing FlowDeck JSON in shell** rule: prefer `jq`, do not regex JSON, structured-parser fallback when `jq` is absent.
- Restructured macOS UI guidance in `resources/ui.md` to mirror iOS: session-first, activate before interact, verify by re-reading session files, restart-if-stale — same workflow as iOS, only the targeting flag (`--app` vs `-S`) differs.
- Documented `flowdeck simulator button`, `simulator appearance`, and `simulator orientation` subcommand groups in `resources/simulator.md`.
- Added `flowdeck license validate`, `license trial`, and `license purchase` to `resources/license.md`.
- Added `gemini` to the supported AI agent list in `resources/ai.md`.
- Added `project packages unlink` and `project packages targets` to `resources/project.md`.
- Documented JSON output shapes for `flowdeck device list`, `flowdeck apps`, and UI session start (with `session_dir` / `latest_screenshot` / `latest_tree` keys).
- Removed `resources/init.md`; `flowdeck init` no longer exists in the CLI.
- Corrected `resources/logs.md`: physical iOS device log streaming IS supported (tails the captured console log).
- Added focus-stealing + "stop before re-run" warning to `resources/run.md`.
- Replaced every `.font(.system(size:))` text example in `resources/pixel-perfect-design.md` with named text styles per the swift-standards skill typography guidance.
- Clarified iOS/macOS `--timeout` unit divergence (ms vs seconds), targeting-mode precedence, and `--point` quoting in `resources/ui.md`.
- Marked `ui simulator set-appearance` and `ui simulator button` as hidden aliases for the canonical `simulator` subcommands.
- Reordered this changelog into strict descending version order.

## 1.15.0 - 2026-04-11
- Added AUTOMATION BOUNDARIES section: agents now default to build-only (`flowdeck build`) for validation instead of build-and-run (`flowdeck run`).
- `flowdeck run` and all UI automation (sessions, taps, clicks, screenshots) now require explicit user request. Running the app steals OS focus and UI automation hijacks mouse/keyboard input.
- `flowdeck build` and `flowdeck test` remain safe to run automatically.
- Updated all workflow examples, decision guides, debugging loop, critical rules, and REMEMBER section to reflect build-only defaults.

## 1.14.2 - 2026-05-12
- Bumped FlowDeck skill pack version to 1.14.2.

## 1.13.5 - 2026-04-16
- Rename `simulator runtime create` to `simulator runtime install` in skill docs and examples.

## 1.12.0 - 2026-03-31
- Bumped FlowDeck skill pack version to 1.12.0.


## 1.11.0 - 2026-03-19
- Bumped FlowDeck skill pack version to 1.11.0.


## 1.10.3 - 2026-03-11
- Added UI automation guardrails to stop agents from inventing unsupported FlowDeck flags, aliases, and key names.
- Added browser-specific guidance: use the browser app's own address bar and controls, not `ui simulator open-url`, when validating web navigation.
- Changed stale-session recovery guidance to restart the session and continue with the new `latest_*` paths instead of falling back to one-off `screen` captures.

## 1.10.2 - 2026-03-11
- Audited the FlowDeck skill pack against the current CLI command surface and refreshed outdated command guidance.
- Added dedicated references for top-level `uninstall` and `ai` commands.
- Moved package resolution guidance to the standalone `package-resolution.md` reference and kept `SKILL.md` as a pointer only.
- Reworked UI automation guidance to match current `ui simulator` commands, removed duplicated simulator docs from `ui.md`, and synced simulator coverage across both skill packs.
- Normalized smaller command references (`apps`, `logs`, `stop`, `context`, `device`, `test`, and `project`) to current flags/examples.

## 1.10.1 - 2026-03-05
- Bumped FlowDeck skill pack version to 1.10.1.

## 1.10.0 - 2026-03-04
- Bumped FlowDeck skill pack version to 1.10.0.

## 1.9.3 - 2026-03-02
- Bumped FlowDeck skill pack version to 1.9.3.

## 1.9.2 - 2026-03-02
- Bumped FlowDeck skill pack version to 1.9.2.

## 1.9.1 - 2026-02-27
- Bumped FlowDeck skill pack version to 1.9.1.

## 1.9.0 - 2026-02-26
- Synced FlowDeck skill pack with CLI 1.9.0.
- Bumped FlowDeck skill pack version to 1.9.0.

## 1.8.0 - 2026-02-07
- Reorganized and expanded doc-bot documentation.
- Split doc-bot docs by product surface: Extension, CLI, and macOS app.
- Reviewed doc-bot coverage against code and filled missing implementation details.
- Bumped FlowDeck skill pack version to 1.8.0.

## 1.7.3 - 2026-02-04
- CLI releases now publish the matching skill pack automatically.
- Release flow removes skill pack backups and respects `--force` preflight.
