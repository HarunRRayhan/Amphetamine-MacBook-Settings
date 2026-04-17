#!/usr/bin/env bash
# install.sh — Interactive installer for Amphetamine settings.
# Lets the user pick Harun's default preset, or hand off to configure.sh
# for per-setting customization.
#
# Safe by design:
#   - Quits Amphetamine before writing prefs (so they don't get overwritten on quit).
#   - Backs up current settings to scripts/backups/ before applying new ones.
#   - Never requires sudo.
#
# Usage:
#   ./scripts/install.sh
#   ./scripts/install.sh --default       # skip menu, apply default preset
#   ./scripts/install.sh --custom        # skip menu, run configure.sh (interactive)
#   ./scripts/install.sh --no-backup     # skip the backup step (default preset only)
#   ./scripts/install.sh --no-gum        # force plain prompts even if `gum` is installed
#
# Interactive prompts auto-detect `gum` (https://github.com/charmbracelet/gum)
# and use it when present for a nicer TUI. If `gum` is missing but Homebrew
# is available, we'll offer to install it. Otherwise we fall back to plain
# `read` prompts — no dependency required.
#
# For fully scripted runs (flags, no prompts) use configure.sh directly:
#   ./scripts/configure.sh --non-interactive --battery-threshold=25 ...

set -euo pipefail

BUNDLE_ID="com.if.Amphetamine"
APP_NAME="Amphetamine"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_PLIST="$REPO_DIR/settings/default.plist"
CONFIGURE_SCRIPT="$REPO_DIR/scripts/configure.sh"
BACKUP_DIR="$REPO_DIR/scripts/backups"

MODE=""
BACKUP=true
USE_GUM=auto   # auto = use gum if available; "no" disables it even if installed

for arg in "$@"; do
  case "$arg" in
    --default) MODE="default" ;;
    --custom)  MODE="custom" ;;
    --no-backup) BACKUP=false ;;
    --no-gum)    USE_GUM=no ;;
    -h|--help)
      sed -n '2,24p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '  %s\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$*"; }
err()   { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

# ---- UI layer (gum if available, plain `read` fallback) ----
# Zero-dep by default: if gum is missing and we're interactive with Homebrew
# available, we offer to install it; otherwise fall back to plain prompts.
have_gum() {
  [ "$USE_GUM" != "no" ] && command -v gum >/dev/null 2>&1
}

# Matches configure.sh: /dev/tty must be readable, writable, *and* actually
# openable. `-r /dev/tty` alone lies in some environments (cron).
shell_is_interactive() {
  [ -r /dev/tty ] && [ -w /dev/tty ] && { : > /dev/tty; } 2>/dev/null
}

# Offer to install gum via Homebrew. Silent no-op if not interactive, if the
# user passed --no-gum, if gum is already installed, or if brew isn't available.
# If the user declines, we flip USE_GUM=no so that (a) have_gum() stays false
# for the rest of this process and (b) run_custom_configurator forwards
# --no-gum to configure.sh, preventing a second identical prompt.
maybe_offer_gum_install() {
  [ "$USE_GUM" = "no" ] && return 0
  command -v gum >/dev/null 2>&1 && return 0
  command -v brew >/dev/null 2>&1 || return 0
  shell_is_interactive || return 0
  echo
  info "Tip: 'gum' gives this installer a nicer TUI (arrow-key menus, spinners)."
  info "     https://github.com/charmbracelet/gum"
  local reply
  if ! read -r -p "  Install it now via Homebrew? [y/N]: " reply < /dev/tty; then
    USE_GUM=no
    return 0
  fi
  case "${reply:-N}" in
    [Yy]|[Yy][Ee][Ss])
      info "Running: brew install gum"
      if brew install gum; then
        ok "Installed gum."
      else
        warn "brew install gum failed — continuing with plain prompts."
        USE_GUM=no
      fi
      ;;
    *)
      USE_GUM=no
      info "Skipping gum — using plain prompts. Pass --no-gum to skip this prompt next time."
      ;;
  esac
  echo
}

# ui_confirm <prompt> <default: yes|no>  → returns 0 for yes, 1 for no.
# Ctrl+C (exit >=128) aborts the whole installer instead of being swallowed
# as a plain "no" by the calling `if`.
ui_confirm() {
  local prompt="$1" default="${2:-yes}" reply default_hint rc
  if have_gum; then
    if [ "$default" = "yes" ]; then
      gum confirm --default=true  "$prompt"
    else
      gum confirm --default=false "$prompt"
    fi
    rc=$?
    if [ "$rc" -ge 128 ]; then
      echo
      exit "$rc"
    fi
    return "$rc"
  fi
  case "$default" in
    yes) default_hint="Y/n" ;;
    *)   default_hint="y/N" ;;
  esac
  if ! read -r -p "  $prompt [$default_hint]: " reply < /dev/tty; then
    [ "$default" = "yes" ] && return 0 || return 1
  fi
  reply="${reply:-$default}"
  case "$reply" in
    1|true|TRUE|True|yes|YES|Yes|y|Y) return 0 ;;
    *) return 1 ;;
  esac
}

# ui_choose <header> <label1> <label2> ... → echoes the chosen label.
# Non-gum path falls back to a numbered prompt matching the previous UX.
ui_choose() {
  local header="$1"; shift
  local rc
  if have_gum; then
    gum choose --header "$header" "$@"
    rc=$?
    if [ "$rc" -ge 128 ]; then
      echo
      exit "$rc"
    fi
    return "$rc"
  fi
  # Plain fallback: numbered menu. Caller handles "Quit" separately.
  echo
  bold "$header"
  local i=1 item
  for item in "$@"; do
    echo "  $i) $item"
    i=$((i+1))
  done
  echo "  q) Quit without changing anything"
  echo
  local choice
  read -r -p "Choice [1]: " choice < /dev/tty
  choice="${choice:-1}"
  case "$choice" in
    q|Q) return 2 ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= $# )); then
        eval "printf '%s' \"\${$choice}\""
        return 0
      fi
      err "Invalid choice: $choice"
      return 1
      ;;
  esac
}

ensure_app_installed() {
  if [ ! -d "/Applications/$APP_NAME.app" ]; then
    err "Amphetamine is not installed at /Applications/$APP_NAME.app"
    info "Install it from the Mac App Store first: https://apps.apple.com/us/app/amphetamine/id937984704"
    exit 1
  fi
  ok "Amphetamine is installed."
}

quit_app() {
  if pgrep -xq "$APP_NAME"; then
    info "Quitting $APP_NAME so settings aren't overwritten..."
    osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
    sleep 1
    if pgrep -xq "$APP_NAME"; then
      warn "Amphetamine didn't respond to quit; using killall."
      killall "$APP_NAME" >/dev/null 2>&1 || true
      sleep 1
    fi
  fi
  ok "Amphetamine is not running."
}

backup_current() {
  [ "$BACKUP" = false ] && return 0
  mkdir -p "$BACKUP_DIR"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local backup="$BACKUP_DIR/amphetamine-backup-$ts.plist"
  if defaults export "$BUNDLE_ID" "$backup" 2>/dev/null; then
    ok "Backed up current settings to: $backup"
  else
    warn "No existing Amphetamine preferences to back up (first-time install)."
  fi
}

apply_default_preset() {
  if [ ! -f "$DEFAULT_PLIST" ]; then
    err "Default preset not found: $DEFAULT_PLIST"
    exit 1
  fi
  defaults import "$BUNDLE_ID" "$DEFAULT_PLIST"
  ok "Imported Harun's default preset."
}

# Custom path: hand off to configure.sh, which is interactive by default and
# knows the correct plist keys. It does its own app check + quit + backup +
# relaunch, so we exec into it without duplicating that work here.
run_custom_configurator() {
  if [ ! -x "$CONFIGURE_SCRIPT" ]; then
    err "configure.sh not found or not executable: $CONFIGURE_SCRIPT"
    exit 1
  fi
  info "Handing off to configure.sh for per-setting customization..."
  echo
  # -i forces interactive mode even if something weird happens with the TTY
  # detection; configure.sh will still gracefully fall back if there's no TTY.
  # Forward --no-backup / --no-gum so the two entry points behave consistently.
  local -a forward=(-i)
  if [ "$BACKUP" = false ]; then
    forward+=(--no-backup)
  fi
  if [ "$USE_GUM" = "no" ]; then
    forward+=(--no-gum)
  fi
  exec "$CONFIGURE_SCRIPT" "${forward[@]}"
}

# Install-mode picker. Uses `gum choose` when available; otherwise a numbered
# menu. Sets the MODE global. Returns silently if MODE is already set from a
# CLI flag.
choose_mode() {
  if [ -n "$MODE" ]; then return 0; fi
  if ! shell_is_interactive; then
    info "No TTY detected — applying Harun's default preset."
    MODE="default"
    return 0
  fi

  local default_label="Use Harun's default settings (recommended)"
  local custom_label="Configure each setting interactively"

  if have_gum; then
    local picked
    picked="$(gum choose --header "How would you like to install?" \
      "$default_label" "$custom_label" "Quit without changing anything")"
    case "$picked" in
      "$default_label") MODE="default" ;;
      "$custom_label")  MODE="custom"  ;;
      ""|*Quit*)        info "Aborted. No changes made."; exit 0 ;;
    esac
    return 0
  fi

  echo
  bold "How would you like to install?"
  echo "  1) $default_label"
  echo "  2) $custom_label"
  echo "  q) Quit without changing anything"
  echo
  # Read from /dev/tty so the prompt still works when the script itself is
  # piped into bash (the piped stdin is the script, not the user).
  local choice
  read -r -p "Choice [1]: " choice < /dev/tty
  choice="${choice:-1}"
  case "$choice" in
    1) MODE="default" ;;
    2) MODE="custom" ;;
    q|Q) info "Aborted. No changes made."; exit 0 ;;
    *) err "Invalid choice: $choice"; exit 2 ;;
  esac
}

launch_app_prompt() {
  echo
  if ! shell_is_interactive; then
    info "No TTY — skipping relaunch prompt. Start Amphetamine manually when ready."
    return 0
  fi
  if ui_confirm "Launch Amphetamine now?" "yes"; then
    open -a "$APP_NAME"
    ok "Launched Amphetamine. If configured to auto-start, a session is now running."
  else
    info "Skipping launch. Start Amphetamine manually when you're ready."
  fi
}

verify() {
  echo
  bold "Verification"
  local closed display batt_on
  closed="$(defaults read "$BUNDLE_ID" 'Allow Closed-Display Sleep' 2>/dev/null || echo '?')"
  display="$(defaults read "$BUNDLE_ID" 'Allow Display Sleep' 2>/dev/null || echo '?')"
  batt_on="$(defaults read "$BUNDLE_ID" 'Ignore Battery on AC' 2>/dev/null || echo '?')"
  info "Allow Closed-Display Sleep : $closed   (0 = stay awake with lid closed)"
  info "Allow Display Sleep        : $display   (1 = display can sleep during session)"
  info "Ignore Battery on AC       : $batt_on   (1 = run indefinitely on AC)"
}

main() {
  bold "Amphetamine MacBook Settings — installer"
  ensure_app_installed
  maybe_offer_gum_install
  choose_mode

  # The custom path delegates entirely to configure.sh (which handles its own
  # quit / backup / write / relaunch). We exec into it so we don't double-quit
  # or double-back-up.
  if [ "$MODE" = "custom" ]; then
    run_custom_configurator
    # exec replaces this process; anything below here only runs for --default.
  fi

  # Default-preset path from here on.
  quit_app
  backup_current
  apply_default_preset
  verify
  launch_app_prompt
  echo
  ok "Done."
}

main "$@"
