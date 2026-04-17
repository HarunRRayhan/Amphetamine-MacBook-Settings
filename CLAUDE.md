# Instructions for Claude / Claude Code

This repo packages opinionated [Amphetamine](https://apps.apple.com/us/app/amphetamine/id937984704) preferences that keep a MacBook running with the lid closed while letting the display sleep. When a user clones this repo and asks you to help, follow the guidance below.

## What the user probably wants

1. **Install the default preset** — run `./scripts/install.sh --default` (or `./scripts/install.sh` and choose option 1).
2. **Install with custom values** — run `./scripts/install.sh --custom` for the interactive walkthrough, OR use `./scripts/configure.sh` with env vars if they already know the exact values they want (e.g. `BATTERY_THRESHOLD=25 ./scripts/configure.sh`).
3. **Add shell commands** (`amph-on`, `amph-off`, `amph-status`, `amph-toggle`, `amph-config`) — run `./scripts/shell-helpers.sh install`. Works under bash and zsh.
4. **Reset Amphetamine back to stock** — run `./scripts/reset.sh`.
5. **Export their current settings** — run `./scripts/export.sh [path]`.

If it's ambiguous which one they want, ask. Default to option 1 when they say "install the settings" without qualification. If they name a specific value ("battery cutoff 20%", "show the Dock icon"), prefer `configure.sh` with env vars over the interactive installer — it's a single reproducible command.

## Pre-flight checks

Before running any script, verify:

- Amphetamine is installed: `[ -d /Applications/Amphetamine.app ] && echo OK`
- If not installed, stop and tell the user to install it from the Mac App Store first. Do **not** try to install it yourself.

## Running the installer

```bash
./scripts/install.sh              # interactive
./scripts/install.sh --default    # skip the menu, apply default preset
./scripts/install.sh --custom     # skip the menu, run interactive config
```

The installer:
1. Quits Amphetamine (required — otherwise the running app overwrites the prefs on quit).
2. Backs up current settings to `scripts/backups/amphetamine-backup-YYYYMMDD-HHMMSS.plist`.
3. Applies the chosen preset via `defaults import` or individual `defaults write` calls.
4. Prints verification output and optionally relaunches Amphetamine.

## Verifying after install

```bash
defaults read com.if.Amphetamine 'Allow Closed-Display Sleep'   # expect: 0
defaults read com.if.Amphetamine 'Allow Display Sleep'          # expect: 1
defaults read com.if.Amphetamine 'Ignore Battery on AC'         # expect: 1
defaults read com.if.Amphetamine 'Launch At Login'              # expect: 1
```

You can also check macOS power assertions to confirm a session is running:

```bash
pmset -g assertions | grep -i amphetamine
```

You should see something like:

```
pid XXXXX(Amphetamine): PreventUserIdleSystemSleep named: "Amphetamine (Single-Use - System)"
```

## Things to avoid

- **Never** edit the preference plist directly while Amphetamine is running — it will overwrite your changes on quit.
- **Never** use `sudo` to run these scripts. Amphetamine's prefs are per-user.
- **Never** enable settings that force the Mac to stay awake AND prevent the display from sleeping together under heavy load — that's a thermal risk on a closed MacBook. The default preset explicitly avoids that by setting `Allow Display Sleep = true`.
- **Don't** install Amphetamine for the user — direct them to the Mac App Store.

## If the user is on a Mac without Amphetamine

Point them to: [https://apps.apple.com/us/app/amphetamine/id937984704](https://apps.apple.com/us/app/amphetamine/id937984704)

Once installed, they must launch Amphetamine at least once (so macOS creates the sandbox container) and then quit it before `defaults import` will work cleanly.

## Debugging

If a setting doesn't seem to apply:

1. Confirm Amphetamine was quit before writing: `pgrep -x Amphetamine` should return nothing.
2. Inspect the plist after writing: `defaults read com.if.Amphetamine`.
3. The full plist lives at: `~/Library/Containers/com.if.Amphetamine/Data/Library/Preferences/com.if.Amphetamine.plist`.
4. See [`docs/SETTINGS-REFERENCE.md`](./docs/SETTINGS-REFERENCE.md) for what each key means.

## Style

Keep messages to the user short and concrete. When you run a script, summarize what it did in 2-3 lines rather than dumping raw output.
