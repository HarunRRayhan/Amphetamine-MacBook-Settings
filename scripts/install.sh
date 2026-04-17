#!/usr/bin/env bash
# install.sh — Interactive installer for Amphetamine settings.
# Lets the user pick Harun's default preset, or configure their own.
#
# Safe by design:
#   - Quits Amphetamine before writing prefs (so they don't get overwritten on quit).
#   - Backs up current settings to scripts/backups/ before applying new ones.
#   - Never requires sudo.
#
# Usage:
#   ./scripts/install.sh
#   ./scripts/install.sh --default       # skip menu, apply default preset
#   ./scripts/install.sh --custom        # skip menu, run interactive config
#   ./scripts/install.sh --no-backup     # skip the backup step

set -euo pipefail

BUNDLE_ID="com.if.Amphetamine"
APP_NAME="Amphetamine"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_PLIST="$REPO_DIR/settings/default.plist"
BACKUP_DIR="$REPO_DIR/scripts/backups"

MODE=""
BACKUP=true

for arg in "$@"; do
  case "$arg" in
    --default) MODE="default" ;;
    --custom)  MODE="custom" ;;
    --no-backup) BACKUP=false ;;
    -h|--help)
      sed -n '2,12p' "$0"
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

write_key_bool() {
  local key="$1" value="$2"
  defaults write "$BUNDLE_ID" "$key" -bool "$value"
}

write_key_int() {
  local key="$1" value="$2"
  defaults write "$BUNDLE_ID" "$key" -int "$value"
}

# These keys are the ones this repo cares about. Full list is in docs/SETTINGS-REFERENCE.md.
apply_custom_preset() {
  bold ""
  bold "Custom configuration"
  info "Press Enter on any prompt to keep the default in [brackets]."
  echo

  read -r -p "Stay awake when lid is closed? [Y/n]: " stay_awake
  stay_awake="${stay_awake:-Y}"
  case "$stay_awake" in
    [Yy]*) write_key_bool "Allow Closed-Display Sleep" false ;;
    *)     write_key_bool "Allow Closed-Display Sleep" true ;;
  esac

  read -r -p "Let the display sleep during a session? [Y/n]: " display_sleep
  display_sleep="${display_sleep:-Y}"
  case "$display_sleep" in
    [Yy]*) write_key_bool "Allow Display Sleep" true ;;
    *)     write_key_bool "Allow Display Sleep" false ;;
  esac

  read -r -p "Battery %% below which the session should auto-end (1-99) [30]: " batt
  batt="${batt:-30}"
  if ! [[ "$batt" =~ ^[0-9]+$ ]] || [ "$batt" -lt 1 ] || [ "$batt" -gt 99 ]; then
    err "Invalid battery threshold: $batt"
    exit 2
  fi
  write_key_bool "End Sessions If Battery Is Below Percentage" true
  write_key_int  "Battery Threshold" "$batt"

  read -r -p "Ignore battery cutoff when plugged into AC? [Y/n]: " ignore_ac
  ignore_ac="${ignore_ac:-Y}"
  case "$ignore_ac" in
    [Yy]*) write_key_bool "Ignore Battery on AC" true ;;
    *)     write_key_bool "Ignore Battery on AC" false ;;
  esac

  read -r -p "Launch Amphetamine at login? [Y/n]: " launch_login
  launch_login="${launch_login:-Y}"
  case "$launch_login" in
    [Yy]*) write_key_bool "Launch At Login" true ;;
    *)     write_key_bool "Launch At Login" false ;;
  esac

  read -r -p "Auto-start a session when Amphetamine launches? [Y/n]: " start_on_launch
  start_on_launch="${start_on_launch:-Y}"
  case "$start_on_launch" in
    [Yy]*) write_key_bool "Start Session On Launch" true ;;
    *)     write_key_bool "Start Session On Launch" false ;;
  esac

  ok "Custom settings written."
}

choose_mode() {
  if [ -n "$MODE" ]; then return 0; fi
  echo
  bold "How would you like to install?"
  echo "  1) Use Harun's default settings (recommended)"
  echo "  2) Configure my own settings interactively"
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
  quit_app
  backup_current
  choose_mode
  case "$MODE" in
    default) apply_default_preset ;;
    custom)  apply_custom_preset ;;
  esac
  verify
  launch_app_prompt
  echo
  ok "Done."
}

main "$@"
