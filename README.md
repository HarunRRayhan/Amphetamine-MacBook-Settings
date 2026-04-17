# Amphetamine MacBook Settings

[Amphetamine](https://apps.apple.com/us/app/amphetamine/id937984704) settings that keep a MacBook awake with the lid closed while letting the display sleep. Good for overnight syncs, long builds, SSH sessions, and remote access without cooking the laptop or draining the battery.

These are the exact settings I run on my own machine. The repo ships them as a one-command install, but you don't have to take them as-is. There's an interactive installer, a flag-driven configurator for scripted runs, and a shell helper you can source from bash or zsh.

---

## What these settings do

| Behavior                                       | Value                                |
| ---------------------------------------------- | ------------------------------------ |
| System awake when lid closed                   | Yes                                  |
| Display sleeps during a session                | Yes (saves battery, reduces heat)    |
| Default session duration                       | Indefinitely                         |
| Auto-end session on battery when charge drops  | at 30%                               |
| Ignore battery % on AC power                   | Yes (runs indefinitely when plugged) |
| Launch Amphetamine at login                    | Yes                                  |
| Auto-start a session when Amphetamine launches | Yes                                  |

Close the lid, keep your Mac running, don't wake up to a dead battery.

---

## Quick install

```bash
git clone https://github.com/HarunRRayhan/Amphetamine-MacBook-Settings.git
cd Amphetamine-MacBook-Settings
./scripts/install.sh --default
```

That's it. The installer quits Amphetamine, backs up your current prefs, applies the defaults, and relaunches.

---

## Configure it your way

`scripts/configure.sh` runs interactively by default — just launch it and it'll walk you through every setting, one question at a time. Press Enter to accept the default shown in brackets.

```bash
./scripts/configure.sh
```

You'll see prompts like:

```
Stay awake with the lid closed? (the core use case) [Y/n]:
Let the display sleep during a session? (saves battery and heat) [Y/n]:
Auto-end the session when battery gets low? [Y/n]:
Battery percent to end the session at (5–95)? [30]:
...
```

At the end you'll see the plan and a final "Apply these settings?" confirmation.

The installer has the same entry point if you'd rather start there and pick "Configure each setting interactively":

```bash
./scripts/install.sh
# pick 2) Configure each setting interactively
```

### Non-interactive / scripted runs

Pass any setting flag (or `--non-interactive`) and the script writes without prompting — useful for provisioning, dotfiles, or remote runs over SSH without a TTY. If you pipe the script through `bash` (no TTY), it falls back to non-interactive automatically.

```bash
# Apply defaults without prompting
./scripts/configure.sh --non-interactive

# Tweak just the battery cutoff and keep everything else at defaults
./scripts/configure.sh --battery-threshold=25

# Show the Dock icon instead of hiding it
./scripts/configure.sh --no-hide-dock-icon

# Combine flags — any setting flag implies non-interactive
./scripts/configure.sh --battery-threshold=20 --no-allow-display-sleep --no-hide-dock-icon

# Preview what would change, don't touch anything
./scripts/configure.sh --non-interactive --dry-run
```

Bool flags accept `yes|no`, `y|n`, `true|false`, or `1|0`. Bare `--flag` means "set to yes"; `--no-flag` means "set to no"; `--flag=<value>` is the explicit form. "Preset" below is what the shipped default preset sets — **not** what a bare `--flag` would do.

| Flag                              | Preset | What the setting means                              |
| --------------------------------- | ------ | --------------------------------------------------- |
| `--allow-closed-display-sleep`    | `no`   | `yes` = let Mac sleep with lid closed. Default `no` keeps it awake. |
| `--allow-display-sleep`           | `yes`  | Let the display sleep during a session              |
| `--battery-threshold=<5..95>`     | `30`   | End the session below this battery %                |
| `--end-on-battery-below`          | `yes`  | Enforce the battery threshold                       |
| `--ignore-battery-on-ac`          | `yes`  | Ignore the threshold when plugged in                |
| `--start-on-launch`               | `yes`  | Start a session when Amphetamine launches           |
| `--hide-dock-icon`                | `yes`  | Menu-bar only, no Dock icon                         |

So `--allow-closed-display-sleep` (bare) would turn that setting **on** — which is the opposite of what the preset ships and the opposite of what this repo is for. Use `--no-allow-closed-display-sleep` or `--allow-closed-display-sleep=no` if you want to be explicit about keeping the Mac awake with the lid closed.

Run `./scripts/configure.sh --help` for the full list (including the advanced notifications / forced-sleep / screen-saver flags).

> **On `Launch At Login`:** macOS manages this via SMLoginItem, not the plist — so there's no flag for it here. Toggle it once in Amphetamine's UI; `amph-config` will show the state.

### Nicer TUI (optional)

The interactive walkthrough auto-detects [`gum`](https://github.com/charmbracelet/gum) (from Charm.sh) and uses it for arrow-key menus, styled prompts, and spinners. If `gum` is missing but Homebrew is available, the installer offers to `brew install` it for you. If you decline — or don't have Homebrew — everything falls back to plain `read` prompts. No dependency required.

```bash
brew install gum                  # opt in ahead of time
./scripts/install.sh --no-gum     # force plain prompts even if gum is installed
./scripts/configure.sh --no-gum
```

If you'd rather click through the Amphetamine UI instead, see [`docs/MANUAL-SETUP.md`](docs/MANUAL-SETUP.md).

---

## Shell helpers (bash + zsh)

`scripts/shell-helpers.sh` adds a few commands to your shell so you can drive Amphetamine without touching the menu bar:

```bash
amph-on          # start an indefinite session
amph-off         # end the current session
amph-status      # is a session active?
amph-toggle      # flip on <-> off
amph-config      # show the current plist values
```

Install once:

```bash
./scripts/shell-helpers.sh install
```

That appends a `source` line to your `~/.bashrc` and `~/.zshrc` (whichever ones you have). Open a new terminal tab and the commands are there. The script detects whether it's being sourced or executed, so the same file works both ways.

Prefer to source it manually? Add this to your rc file:

```bash
source ~/Projects/Amphetamine-MacBook-Settings/scripts/shell-helpers.sh
```

---

## Other scripts

```bash
./scripts/reset.sh                      # revert Amphetamine to stock defaults
./scripts/export.sh ~/Desktop/my.plist  # snapshot your current settings
```

`export.sh` is how you migrate to a new Mac: export on the old one, copy the plist over, then `defaults import com.if.Amphetamine <path>` on the new one (or just run `install.sh` again if you're using the defaults).

---

## Requirements

- macOS 11 Big Sur or later
- [Amphetamine](https://apps.apple.com/us/app/amphetamine/id937984704) from the Mac App Store (free)

Launch Amphetamine once after install so macOS creates the sandbox container, then quit it before running any of the scripts.

---

## Repo layout

```
.
├── README.md
├── LICENSE
├── CLAUDE.md                       # Context for Claude / Claude Code
├── AGENTS.md                       # Context for other AI coding agents
├── settings/
│   ├── default.plist               # My default settings (binary plist)
│   └── default.xml.plist           # Same settings in human-readable XML
├── scripts/
│   ├── install.sh                  # Installer (apply default preset, or hand off to configure.sh)
│   ├── configure.sh                # Configurator — interactive by default, flag-driven for scripted runs
│   ├── shell-helpers.sh            # amph-on / amph-off / amph-status for bash + zsh
│   ├── export.sh                   # Export your current settings to a plist
│   └── reset.sh                    # Reset Amphetamine to its own defaults
└── docs/
    ├── MANUAL-SETUP.md             # Click-through guide through the Amphetamine UI
    └── SETTINGS-REFERENCE.md       # What every key in the plist means
```

---

## Using this repo with AI assistants

Clone the repo, open it in whatever assistant you use, and ask it to install the settings. Both `CLAUDE.md` and `AGENTS.md` ship in the repo so agents have the context they need.

### Claude (Claude Desktop / claude.ai)

Share the repo URL or drop `settings/default.plist` + `docs/MANUAL-SETUP.md` into the chat:

> *"Install these Amphetamine settings on my Mac using the install script in this repo."*

### Claude Code

From the repo root:

```bash
claude
```

Claude Code picks up `CLAUDE.md` automatically. Try:

> *"Install these settings as the default."*
> *"Configure Amphetamine with a 25% battery cutoff."*
> *"Revert Amphetamine to stock defaults."*

It'll run the right script and verify with `defaults read com.if.Amphetamine`.

### OpenAI Codex CLI

```bash
codex
```

Codex reads [`AGENTS.md`](./AGENTS.md) automatically. Same prompts as Claude Code work.

### OpenClaw

[OpenClaw](https://docs.openclaw.ai) is a self-hosted AI gateway with a CLI and multi-channel delivery (Discord, Slack, iMessage, Telegram, WhatsApp). From the repo root:

```bash
openclaw
```

It also reads [`AGENTS.md`](./AGENTS.md). You can trigger an install in a direct session, or route the same prompt through any channel you've wired up. E.g. ask Claude via iMessage to SSH in and run `./scripts/install.sh --default`.

Docs: [docs.openclaw.ai](https://docs.openclaw.ai)

### Hermes Agent

[Hermes Agent](https://hermes-agent.nousresearch.com) (Nous Research) is a self-improving agent with a `hermes` CLI and an optional messaging gateway. From the repo root:

```bash
hermes
```

Hermes reads [`AGENTS.md`](./AGENTS.md) too. Run it on a remote Mac and route through Telegram or Signal if you manage several machines.

Docs: [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs)

### Cursor, Windsurf, Aider, continue.dev, etc.

Same pattern: clone, open, ask the assistant to install these settings. [`AGENTS.md`](./AGENTS.md) has everything they need.

---

## Safety notes

Your Mac relies on the keyboard deck to dissipate heat. With the lid closed, sustained heavy CPU or GPU work will run hotter than it would lid-open. The default preset includes a **30% battery cutoff** and **display sleep during sessions** to limit drain, but if you're rendering video or running a long ML job, keep the lid open.

The installer won't overwrite settings without asking, and it offers to back up your current prefs before writing. None of these scripts need `sudo`. They only touch your user preferences at `~/Library/Containers/com.if.Amphetamine/Data/Library/Preferences/com.if.Amphetamine.plist`.

---

## Contributing

PRs welcome. Especially:

- Fixes or clarifications to the AI-tool sections
- New presets in `settings/` (`light-laptop.plist`, `heavy-workstation.plist`, etc.)
- Improvements to the installer or the shell helpers

---

## License

[MIT](./LICENSE). Do whatever you want with it.
