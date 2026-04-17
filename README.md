# Amphetamine MacBook Settings

Opinionated [Amphetamine](https://apps.apple.com/us/app/amphetamine/id937984704) settings that let your MacBook **stay awake with the lid closed while the display sleeps** — perfect for long background jobs, syncs, SSH sessions, downloads, or remote access without frying your battery or cooking the laptop.

This repo ships the exact settings [@HarunRRayhan](https://github.com/HarunRRayhan) runs as the default, plus an interactive installer so anyone can either use those defaults or pick their own.

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

**Translation:** close your lid, keep your Mac running, don't wake up to a dead battery.

---

## Quick install (use the default settings)

```bash
git clone https://github.com/HarunRRayhan/Amphetamine-MacBook-Settings.git
cd Amphetamine-MacBook-Settings
./scripts/install.sh
```

Run the installer and pick **`1) Use Harun's default settings`**.

---

## Install with your own settings

Same installer, different choice:

```bash
./scripts/install.sh
# choose: 2) Configure my own settings interactively
```

The interactive mode asks you a few short questions (battery threshold, lid-closed behavior, auto-start at login, default duration) and writes the resulting preferences for you. You can re-run it any time.

Prefer to configure in the app? See [`docs/MANUAL-SETUP.md`](docs/MANUAL-SETUP.md) for a step-by-step click-through of Amphetamine Settings.

---

## Requirements

- macOS 11 Big Sur or later
- [Amphetamine](https://apps.apple.com/us/app/amphetamine/id937984704) installed from the Mac App Store (free)

---

## Repo layout

```
.
├── README.md
├── LICENSE
├── CLAUDE.md                       # Context for Claude / Claude Code
├── AGENTS.md                       # Context for other AI coding agents
├── settings/
│   ├── default.plist               # Harun's default settings (binary plist)
│   └── default.xml.plist           # Same settings in human-readable XML
├── scripts/
│   ├── install.sh                  # Interactive installer (default or custom)
│   ├── export.sh                   # Export your current settings to a plist
│   └── reset.sh                    # Reset Amphetamine to its own defaults
└── docs/
    ├── MANUAL-SETUP.md             # Click-through guide through the Amphetamine UI
    └── SETTINGS-REFERENCE.md       # What every key in the plist means
```

---

## Using this repo with AI assistants

This repo is set up so that if you use an AI assistant, you can clone it and ask the assistant to walk you through (or fully automate) the installation. The assistant reads `CLAUDE.md` or `AGENTS.md` for context about what the repo does and how to apply the settings safely.

### Claude (Claude Desktop / claude.ai)

Share this repo's URL, or drag `settings/default.plist` + `docs/MANUAL-SETUP.md` into the chat, and say:

> *"Install these Amphetamine settings on my Mac using the install script in this repo."*

Claude will walk you through running `./scripts/install.sh` and choosing the right option.

### Claude Code

From the repo root:

```bash
claude
```

Claude Code picks up `CLAUDE.md` automatically. Prompt it:

> *"Install these settings as the default."*
> *"Configure Amphetamine with a 25% battery cutoff instead of 30%."*
> *"Revert Amphetamine to stock defaults."*

It will run `./scripts/install.sh` / `./scripts/reset.sh` and verify the result with `defaults read com.if.Amphetamine`.

### OpenAI Codex CLI

```bash
codex
```

Codex CLI reads [`AGENTS.md`](./AGENTS.md) automatically. Same prompts as Claude Code work.

### OpenClaw

[OpenClaw](https://docs.openclaw.ai) is a self-hosted AI gateway with a CLI and multi-channel delivery (Discord, Slack, iMessage, Telegram, WhatsApp, and more). From the repo root:

```bash
openclaw
```

OpenClaw reads [`AGENTS.md`](./AGENTS.md) when running agent sessions against this repo, so it picks up the same guidance as Codex CLI. You can run the installer directly through an OpenClaw session ("Install these Amphetamine settings on this machine") or route the same prompt through any channel you've wired into your OpenClaw gateway (e.g. ask Claude via iMessage to SSH in and run `./scripts/install.sh --default`).

Docs: [docs.openclaw.ai](https://docs.openclaw.ai)

### Hermes Agent

[Hermes Agent](https://hermes-agent.nousresearch.com) (Nous Research) is a self-improving AI agent with a `hermes` CLI and optional messaging gateway. From the repo root:

```bash
hermes
```

Hermes reads [`AGENTS.md`](./AGENTS.md) too. Prompt it the same way as the others:

> *"Install these Amphetamine settings on my Mac."*
> *"Revert Amphetamine to its stock defaults."*

If you run Hermes on a remote box and route it through Telegram / Signal / Slack via the Hermes gateway, you can trigger the installer from your phone — handy if you're managing several Macs.

Docs: [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs)

### Any other AI coding CLI

Tools like Cursor, Windsurf, Aider, continue.dev, and most other modern AI coding CLIs follow the same pattern: clone the repo, open it in the tool, ask the assistant to install these Amphetamine settings. The [`AGENTS.md`](./AGENTS.md) file gives them everything they need.

---

## Safety notes

- Your Mac relies on the keyboard deck to dissipate heat. With the lid closed, sustained heavy CPU/GPU workloads will run hotter than lid-open. These settings include a **30% battery cutoff on battery** and **display sleep during sessions** to minimize drain, but if you're rendering video or running a long ML job, keep the lid open.
- The installer will **not** overwrite settings without confirmation. It offers to back up your current settings before writing.
- None of these settings require `sudo`. They're written to your user preferences at `~/Library/Containers/com.if.Amphetamine/Data/Library/Preferences/com.if.Amphetamine.plist`.

---

## Contributing

PRs welcome — especially:

- Fixes or clarifications to the AI tool sections above
- New presets in `settings/` (e.g. `light-laptop.plist`, `heavy-workstation.plist`)
- Improvements to the interactive installer

---

## License

[MIT](./LICENSE) — do whatever you want with this.
