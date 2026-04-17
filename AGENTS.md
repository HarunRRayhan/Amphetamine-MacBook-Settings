# AGENTS.md

Instructions for AI coding agents working in this repository. This file is read by:

- [OpenAI Codex CLI](https://openai.com/codex)
- [OpenClaw](https://docs.openclaw.ai)
- [Hermes Agent](https://hermes-agent.nousresearch.com) (Nous Research)
- Cursor, Windsurf, Aider, continue.dev
- Any other agent that follows the [AGENTS.md convention](https://agents.md)

Claude Code reads `CLAUDE.md` separately — the two files intentionally overlap so each tool has a self-contained reference.

---

## What this repo does

It packages opinionated [Amphetamine](https://apps.apple.com/us/app/amphetamine/id937984704) preferences so a MacBook stays awake with the lid closed while the display sleeps. It provides:

- `settings/default.plist` — the maintainer's default preferences
- `scripts/install.sh` — installer: applies the default preset, or hands off to `configure.sh` for the custom path
- `scripts/configure.sh` — configurator. **Interactive by default.** Pass flags for scripted / non-interactive runs. Auto-detects TTY — if stdin has no controlling terminal (piped, cron, SSH without `-t`), it falls back to non-interactive using current defaults.
- `scripts/shell-helpers.sh` — sourceable helpers for bash and zsh (`amph-on`, `amph-off`, `amph-status`, `amph-toggle`, `amph-config`)
- `scripts/export.sh` — export current prefs to a plist
- `scripts/reset.sh` — reset Amphetamine to stock defaults

## User intents → what to run

| User says…                                               | Run                                                                   |
| -------------------------------------------------------- | --------------------------------------------------------------------- |
| "Install these settings" / "Set up Amphetamine"          | `./scripts/install.sh --default`                                      |
| "Let me pick my own values" / "Walk me through it"       | `./scripts/configure.sh` (or `./scripts/install.sh --custom`)         |
| "Configure with a 25% battery cutoff" (single value)     | `./scripts/configure.sh --battery-threshold=25`                       |
| "Show the Dock icon"                                     | `./scripts/configure.sh --no-hide-dock-icon`                          |
| "Apply defaults but don't prompt"                        | `./scripts/configure.sh --non-interactive`                            |
| "Preview the change without writing"                     | `./scripts/configure.sh --non-interactive --dry-run`                  |
| "Add shell shortcuts" / "I want `amph-on` / `amph-off`"  | `./scripts/shell-helpers.sh install`                                  |
| "Revert / reset Amphetamine"                             | `./scripts/reset.sh`                                                  |
| "Back up my current settings"                            | `./scripts/export.sh ~/Desktop/amphetamine-backup.plist`              |

Flag conventions in `configure.sh`:

- Kebab-case setting flags. Bools accept `--foo`, `--foo=yes|no|1|0|true|false`, or `--no-foo`.
- `-i` / `--interactive` forces prompting; `-N` / `--non-interactive` forces the flag-driven path.
- `-n` / `--dry-run` prints the plan without writing.
- Any setting flag implies `--non-interactive` (unless `-i` is also passed).
- `./scripts/configure.sh --help` lists every flag.

Note: `Launch At Login` is not a plist key. macOS stores it via SMLoginItem, so there's no flag for it. It's toggled in Amphetamine's UI; `amph-config` surfaces the state via `tell application "System Events" to get login item "Amphetamine" exists`.

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
defaults read com.if.Amphetamine 'Low Battery Percent'          # expect 30 (or whatever the user set)

# "Launch At Login" is not a plist key — it's stored via SMLoginItem.
# Query it through System Events:
osascript -e 'tell application "System Events" to get login item "Amphetamine" exists'

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
