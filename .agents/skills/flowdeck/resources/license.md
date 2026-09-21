# license - Manage License

Activate, check, or deactivate your FlowDeck license.

`license` subcommands accept only `--json` (no `-j` short form, no `--examples`).

#### license status

Displays your current license status, including plan type, expiration, and number of activations used.

```bash
flowdeck license status
```

Add `--json` only if you need to parse the plan / expiration / activation count for a follow-up decision.

Need a key? Purchase at https://flowdeck.studio/cli/purchase/
Or run `flowdeck license purchase` to open the page automatically.

#### license activate

Activates your FlowDeck license key on this machine.

```bash
flowdeck license activate ABCD1234-EFGH5678-IJKL9012-MNOP3456
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<key>` | License key (REQUIRED) |

**CI/CD:** For CI/CD, set `FLOWDECK_LICENSE_KEY` environment variable instead.

#### license deactivate

Deactivates your license on this machine, freeing up an activation slot.

```bash
flowdeck license deactivate
```

Use this before moving your license to a different machine.

#### license validate

Force an immediate server license validation. Useful when the cached state seems stale or after activating a license elsewhere. Run `flowdeck license validate --help` for flags. Supports `--json`.

#### license trial

Start or verify a FlowDeck CLI trial. Use for new-user onboarding before purchase. Supports `--json`.

#### license purchase

Open the FlowDeck pricing page in the default browser. Prefer this over hard-coding the URL.

---
