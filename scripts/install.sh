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

for arg in "$@"; do
  case "$arg" in
    --default) MODE="default" ;;
    --custom)  MODE="custom" ;;
    --no-backup) BACKUP=false ;;
    -h|--help)
      sed -n '2,17p' "$0"
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
  exec "$CONFIGURE_SCRIPT" -i
}

choose_mode() {
  if [ -n "$MODE" ]; then return 0; fi
  echo
  bold "How would you like to install?"
  echo "  1) Use Harun's default settings (recommended)"
  echo "  2) Configure each setting interactively"
  echo "  q) Quit without changing anything"
  echo
  read -r -p "Choice [1]: " choice
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
  read -r -p "Launch Amphetamine now? [Y/n]: " launch
  launch="${launch:-Y}"
  case "$launch" in
    [Yy]*)
      open -a "$APP_NAME"
      ok "Launched Amphetamine. If configured to auto-start, a session is now running."
      ;;
    *)
      info "Skipping launch. Start Amphetamine manually when you're ready."
      ;;
  esac
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
