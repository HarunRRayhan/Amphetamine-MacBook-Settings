# AGENTS.md

Instructions for AI coding agents working in this repository. This file is read by OpenAI Codex CLI, OpenCode, Cursor, Windsurf, Aider, and most other modern AI coding tools that follow the [AGENTS.md convention](https://agents.md).

Claude Code reads `CLAUDE.md` separately — the two files intentionally overlap so each tool has a self-contained reference.

---

## What this repo does

It packages opinionated [Amphetamine](https://apps.apple.com/us/app/amphetamine/id937984704) preferences so a MacBook stays awake with the lid closed while the display sleeps. It provides:

- `settings/default.plist` — the maintainer's default preferences
- `scripts/install.sh` — interactive installer (default preset or custom)
- `scripts/export.sh` — export current prefs to a plist
- `scripts/reset.sh` — reset Amphetamine to stock defaults

## User intents → what to run

| User says…                                      | Run                                      |
| ----------------------------------------------- | ---------------------------------------- |
| "Install these settings" / "Set up Amphetamine" | `./scripts/install.sh --default`         |
| "Let me pick my own values"                     | `./scripts/install.sh --custom`          |
| "Revert / reset Amphetamine"                    | `./scripts/reset.sh`                     |
| "Back up my current settings"                   | `./scripts/export.sh ~/Desktop/amphetamine-backup.plist` |

When in doubt, ask the user before making changes. Always prefer running the provided scripts over writing `defaults` values yourself — the scripts handle quitting Amphetamine, backing up, and verifying.

## Pre-flight

Before any install:

```bash
[ -d /Applications/Amphetamine.app ] || {
  echo "Amphetamine is not installed. Ask the user to install it from the Mac App Store."
  exit 1
}
```

## Post-install verification

```bash
defaults read com.if.Amphetamine 'Allow Closed-Display Sleep'   # expect 0
defaults read com.if.Amphetamine 'Allow Display Sleep'          # expect 1
defaults read com.if.Amphetamine 'Ignore Battery on AC'         # expect 1
defaults read com.if.Amphetamine 'Launch At Login'              # expect 1

pmset -g assertions | grep -i amphetamine                        # should show an active assertion after launch
```

## Hard rules

1. Never run any script with `sudo`. These are per-user preferences.
2. Never modify `~/Library/Containers/com.if.Amphetamine/Data/Library/Preferences/com.if.Amphetamine.plist` while Amphetamine is running — it will be overwritten on quit.
3. Never install Amphetamine yourself. Direct the user to the Mac App Store.
4. Never recommend a configuration that keeps both the system and the display awake indefinitely on a closed lid without a battery / temperature cutoff — that is a thermal safety issue.

## Reference

- [`README.md`](./README.md) — user-facing overview
- [`CLAUDE.md`](./CLAUDE.md) — Claude-specific guidance (near-identical to this file)
- [`docs/MANUAL-SETUP.md`](./docs/MANUAL-SETUP.md) — manual click-through for the Amphetamine UI
- [`docs/SETTINGS-REFERENCE.md`](./docs/SETTINGS-REFERENCE.md) — plist key reference
