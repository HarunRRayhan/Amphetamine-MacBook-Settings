#!/usr/bin/env bash
# configure.sh — Non-interactive, env-var-driven Amphetamine configurator.
#
# Every setting has a sensible default. Override any of them by exporting the
# matching env var before running the script, or by passing KEY=VALUE pairs
# on the command line.
#
# The script uses `#!/usr/bin/env bash`, so it runs under bash regardless of
# whether you invoke it from bash, zsh, fish, nushell, or anything else.
#
# Examples:
#
#   # Use all defaults (same as ./scripts/install.sh --default)
#   ./scripts/configure.sh
#
#   # Lower the battery threshold from 30% to 20%
#   BATTERY_THRESHOLD=20 ./scripts/configure.sh
#
#   # Keep the display on during sessions (thermal risk — read the README first)
#   ALLOW_DISPLAY_SLEEP=0 ./scripts/configure.sh
#
#   # Pass values as arguments instead of env vars
#   ./scripts/configure.sh BATTERY_THRESHOLD=25 HIDE_DOCK_ICON=0
#
#   # Print what would be written, don't touch anything
#   ./scripts/configure.sh --dry-run
#
# Defaults match settings/default.plist.

set -euo pipefail

BUNDLE_ID="com.if.Amphetamine"
APP_NAME="Amphetamine"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$REPO_DIR/scripts/backups"

# ---- Defaults (override via env vars or KEY=VALUE args) ----
# Note: "Launch At Login" isn't a plist key — macOS manages that flag via
# SMLoginItem when you toggle it in Amphetamine's UI. Not configurable here.
: "${ALLOW_CLOSED_DISPLAY_SLEEP:=0}"   # 0 = stay awake with lid closed  (the point of this repo)
: "${ALLOW_DISPLAY_SLEEP:=1}"          # 1 = let the internal display sleep during a session
: "${BATTERY_THRESHOLD:=30}"           # end session when battery drops below this %
: "${END_ON_BATTERY_BELOW:=1}"         # 1 = enforce BATTERY_THRESHOLD, 0 = never auto-end on battery
: "${IGNORE_BATTERY_ON_AC:=1}"         # 1 = ignore threshold when plugged in
: "${START_ON_LAUNCH:=1}"              # 1 = start a session when Amphetamine launches
: "${HIDE_DOCK_ICON:=1}"               # 1 = menu-bar only, no Dock icon
: "${ALLOW_SCREEN_SAVER:=0}"           # 0 = suppress the screen saver during sessions
: "${END_ON_FORCED_SLEEP:=0}"          # 0 = manual sleep does NOT auto-end the session
: "${ENABLE_START_END_NOTIFS:=0}"      # 0 = quiet start/end notifications
: "${ENABLE_AUTO_END_NOTIFS:=1}"       # 1 = notify when a session auto-ends (e.g. battery)

# Whitelist of variable names accepted as KEY=VALUE args. Anything else
# is rejected before it can end up in the environment.
ALLOWED_KEYS=(
  ALLOW_CLOSED_DISPLAY_SLEEP
  ALLOW_DISPLAY_SLEEP
  BATTERY_THRESHOLD
  END_ON_BATTERY_BELOW
  IGNORE_BATTERY_ON_AC
  START_ON_LAUNCH
  HIDE_DOCK_ICON
  ALLOW_SCREEN_SAVER
  END_ON_FORCED_SLEEP
  ENABLE_START_END_NOTIFS
  ENABLE_AUTO_END_NOTIFS
)

_key_is_allowed() {
  local candidate="$1" k
  for k in "${ALLOWED_KEYS[@]}"; do
    [ "$candidate" = "$k" ] && return 0
  done
  return 1
}

BACKUP=true
DRY_RUN=false
RELAUNCH=true

# ---- Parse args ----
for arg in "$@"; do
  case "$arg" in
    --no-backup)    BACKUP=false ;;
    --dry-run|-n)   DRY_RUN=true ;;
    --no-relaunch)  RELAUNCH=false ;;
    -h|--help)
      sed -n '2,32p' "$0"
      exit 0
      ;;
    *=*)
      # KEY=VALUE pair. Split at the first '=' and whitelist-check the key
      # before exporting. `export "$arg"` assigns the literal value, so
      # something like FOO='bar; rm -rf /' gets stored, not executed.
      key="${arg%%=*}"
      if ! _key_is_allowed "$key"; then
        echo "Unknown configuration key: $key" >&2
        echo "Allowed keys: ${ALLOWED_KEYS[*]}" >&2
        exit 2
      fi
      export "$arg"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "See ./scripts/configure.sh --help" >&2
      exit 2
      ;;
  esac
done

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

# ---- Validation ----
validate_bool() {
  local name="$1" val="$2"
  case "$val" in
    0|1|true|false|yes|no) ;;
    *)
      err "$name must be 0 or 1 (got: $val)"
      exit 3
      ;;
  esac
}

# Normalize booleans to 0/1
normalize_bool() {
  case "$1" in
    1|true|yes)  echo 1 ;;
    0|false|no)  echo 0 ;;
    *) echo "$1" ;;
  esac
}

for v in ALLOW_CLOSED_DISPLAY_SLEEP ALLOW_DISPLAY_SLEEP END_ON_BATTERY_BELOW \
         IGNORE_BATTERY_ON_AC START_ON_LAUNCH HIDE_DOCK_ICON \
         ALLOW_SCREEN_SAVER END_ON_FORCED_SLEEP ENABLE_START_END_NOTIFS \
         ENABLE_AUTO_END_NOTIFS; do
  validate_bool "$v" "${!v}"
  printf -v "$v" '%s' "$(normalize_bool "${!v}")"
done

if ! [[ "$BATTERY_THRESHOLD" =~ ^[0-9]+$ ]] || \
   (( BATTERY_THRESHOLD < 5 || BATTERY_THRESHOLD > 95 )); then
  err "BATTERY_THRESHOLD must be an integer between 5 and 95 (got: $BATTERY_THRESHOLD)"
  exit 3
fi

# ---- Pre-flight ----
if [ ! -d "/Applications/$APP_NAME.app" ]; then
  err "$APP_NAME is not installed. Get it from the Mac App Store:"
  info "https://apps.apple.com/us/app/amphetamine/id937984704"
  exit 1
fi

# ---- Show plan ----
bold "Amphetamine configuration plan"
info "Allow Closed-Display Sleep    = $ALLOW_CLOSED_DISPLAY_SLEEP  (0 = stay awake with lid closed)"
info "Allow Display Sleep           = $ALLOW_DISPLAY_SLEEP"
info "Low Battery Percent           = ${BATTERY_THRESHOLD}%"
info "End Session On Low Battery    = $END_ON_BATTERY_BELOW"
info "Ignore Battery on AC          = $IGNORE_BATTERY_ON_AC"
info "Start Session At Launch       = $START_ON_LAUNCH"
info "Hide Dock Icon                = $HIDE_DOCK_ICON"
info "Allow Screen Saver            = $ALLOW_SCREEN_SAVER"
info "End On Forced Sleep           = $END_ON_FORCED_SLEEP"
info "Session Start/End Notifs      = $ENABLE_START_END_NOTIFS"
info "Auto-End Notifs               = $ENABLE_AUTO_END_NOTIFS"
echo

if [ "$DRY_RUN" = true ]; then
  warn "Dry run — no changes will be written."
  exit 0
fi

# ---- Quit Amphetamine (required before writing prefs) ----
if pgrep -x "$APP_NAME" >/dev/null; then
  info "Quitting $APP_NAME..."
  osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
  # Give it a moment
  for _ in 1 2 3 4 5; do
    pgrep -x "$APP_NAME" >/dev/null || break
    sleep 0.5
  done
  if pgrep -x "$APP_NAME" >/dev/null; then
    warn "Amphetamine didn't exit cleanly — forcing"
    pkill -x "$APP_NAME" || true
  fi
  ok "Quit $APP_NAME"
fi

# ---- Backup ----
if [ "$BACKUP" = true ]; then
  mkdir -p "$BACKUP_DIR"
  BACKUP_PATH="$BACKUP_DIR/amphetamine-backup-$(date +%Y%m%d-%H%M%S).plist"
  if defaults export "$BUNDLE_ID" "$BACKUP_PATH" 2>/dev/null; then
    ok "Backed up current settings to $BACKUP_PATH"
  else
    warn "No existing settings to back up (first run?)"
  fi
fi

# ---- Apply ----
write_bool() { defaults write "$BUNDLE_ID" "$1" -bool    "$2"; }
write_int()  { defaults write "$BUNDLE_ID" "$1" -int     "$2"; }

write_bool 'Allow Closed-Display Sleep'          "$ALLOW_CLOSED_DISPLAY_SLEEP"
write_bool 'Allow Display Sleep'                 "$ALLOW_DISPLAY_SLEEP"
write_int  'Low Battery Percent'                 "$BATTERY_THRESHOLD"
write_bool 'End Session On Low Battery'          "$END_ON_BATTERY_BELOW"
write_bool 'Ignore Battery on AC'                "$IGNORE_BATTERY_ON_AC"
write_bool 'Start Session At Launch'             "$START_ON_LAUNCH"
write_bool 'Hide Dock Icon'                      "$HIDE_DOCK_ICON"
write_bool 'Allow Screen Saver'                  "$ALLOW_SCREEN_SAVER"
write_bool 'End Sessions On Forced Sleep'        "$END_ON_FORCED_SLEEP"
write_bool 'Enable Session Notifications'        "$ENABLE_START_END_NOTIFS"
write_bool 'Enable Session Auto End Notifications' "$ENABLE_AUTO_END_NOTIFS"

ok "Wrote preferences to $BUNDLE_ID"

# ---- Relaunch ----
if [ "$RELAUNCH" = true ]; then
  open -a "$APP_NAME" 2>/dev/null && ok "Relaunched $APP_NAME"
fi

echo
bold "Done."
info "Verify with:  defaults read $BUNDLE_ID 'Allow Closed-Display Sleep'"
info "Power check:  pmset -g assertions | grep -i amphetamine"
