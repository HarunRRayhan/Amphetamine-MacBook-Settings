#!/usr/bin/env bash
# configure.sh — Amphetamine configurator, interactive by default.
#
# Two modes:
#
#   1. Interactive (the default). Just run it:
#        ./scripts/configure.sh
#      You'll be walked through each setting. Press Enter to keep the default,
#      or type a new value.
#
#   2. Non-interactive, flag-driven. Pass any setting flag (or
#      --non-interactive) and the script applies values without prompting:
#        ./scripts/configure.sh --non-interactive
#        ./scripts/configure.sh --battery-threshold=25 --no-hide-dock-icon
#        ./scripts/configure.sh --allow-display-sleep=no
#
# Flags (bools accept:  yes|no | y|n | true|false | 1|0 ; or use --no-<flag>):
#
#   --allow-closed-display-sleep[=BOOL]   --no-allow-closed-display-sleep
#   --allow-display-sleep[=BOOL]          --no-allow-display-sleep
#   --battery-threshold=<5..95>
#   --end-on-battery-below[=BOOL]         --no-end-on-battery-below
#   --ignore-battery-on-ac[=BOOL]         --no-ignore-battery-on-ac
#   --start-on-launch[=BOOL]              --no-start-on-launch
#   --hide-dock-icon[=BOOL]               --no-hide-dock-icon
#   --allow-screen-saver[=BOOL]           --no-allow-screen-saver
#   --end-on-forced-sleep[=BOOL]          --no-end-on-forced-sleep
#   --enable-start-end-notifs[=BOOL]      --no-enable-start-end-notifs
#   --enable-auto-end-notifs[=BOOL]       --no-enable-auto-end-notifs
#
# Control flags:
#
#   -i, --interactive       force interactive mode (default when no flags given)
#   -N, --non-interactive   force non-interactive mode (use current defaults)
#   -n, --dry-run           print the plan, write nothing
#       --no-backup         skip backing up current prefs
#       --no-relaunch       don't relaunch Amphetamine after writing
#       --no-gum            force plain prompts even if `gum` is installed
#   -h, --help              this message
#
# Interactive mode auto-detects `gum` (https://github.com/charmbracelet/gum)
# and uses it for a nicer TUI when present. `brew install gum` to enable.
# Falls back to plain `read` prompts otherwise — no dependency required.
#
# Defaults match settings/default.plist.

set -euo pipefail

BUNDLE_ID="com.if.Amphetamine"
APP_NAME="Amphetamine"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$REPO_DIR/scripts/backups"

# ---- Defaults (match settings/default.plist) ----
# Note: "Launch At Login" isn't a plist key — macOS manages that flag via
# SMLoginItem when you toggle it in Amphetamine's UI. Not configurable here.
ALLOW_CLOSED_DISPLAY_SLEEP=0   # 0 = stay awake with lid closed (the point of this repo)
ALLOW_DISPLAY_SLEEP=1          # 1 = let the internal display sleep during a session
BATTERY_THRESHOLD=30           # end session when battery drops below this %
END_ON_BATTERY_BELOW=1         # 1 = enforce BATTERY_THRESHOLD, 0 = never auto-end on battery
IGNORE_BATTERY_ON_AC=1         # 1 = ignore threshold when plugged in
START_ON_LAUNCH=1              # 1 = start a session when Amphetamine launches
HIDE_DOCK_ICON=1               # 1 = menu-bar only, no Dock icon
ALLOW_SCREEN_SAVER=0           # 0 = suppress the screen saver during sessions
END_ON_FORCED_SLEEP=0          # 0 = manual sleep does NOT auto-end the session
ENABLE_START_END_NOTIFS=0      # 0 = quiet start/end notifications
ENABLE_AUTO_END_NOTIFS=1       # 1 = notify when a session auto-ends (e.g. battery)

BACKUP=true
DRY_RUN=false
RELAUNCH=true
USE_GUM=auto   # auto = use gum if available; "no" disables it even if installed
# MODE is "" until we know. Any setting flag flips it to "non-interactive".
# -i/-N override. Unset (and no setting flags) → interactive.
MODE=""

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

# ---- Bool parsing / normalization ----
# Accept yes/no, y/n, true/false, 0/1. Returns "0" or "1" on stdout.
# Returns non-zero if the value is not a recognized bool.
to_bool() {
  case "${1:-}" in
    1|true|TRUE|True|yes|YES|Yes|y|Y)   echo 1; return 0 ;;
    0|false|FALSE|False|no|NO|No|n|N)   echo 0; return 0 ;;
    *) return 1 ;;
  esac
}

# Assign a bool flag value. If the flag came as `--foo` (no value), use 1.
# If it came as `--no-foo`, use 0. If it came as `--foo=bar`, parse bar.
# `--foo=` (empty value after `=`) is rejected — be explicit, don't silently
# fall through to "bare" behavior.
# Usage: set_bool <varname> <raw_value_or_empty> <default_when_bare> <had_equals> <flag_name>
set_bool() {
  local var="$1" raw="$2" bare_default="$3" had_equals="$4" flag="$5" parsed
  if [ "$had_equals" = "0" ]; then
    # Bare flag, no value supplied — apply the "on" default.
    printf -v "$var" '%s' "$bare_default"
    return 0
  fi
  if [ -z "$raw" ]; then
    err "$flag= was given an empty value (expected yes|no, y|n, true|false, 1|0)"
    exit 2
  fi
  if parsed="$(to_bool "$raw")"; then
    printf -v "$var" '%s' "$parsed"
    return 0
  fi
  err "Invalid value for $flag: $raw (expected yes|no, y|n, true|false, 1|0)"
  exit 2
}

# ---- Parse args ----
for arg in "$@"; do
  # Split flag name from optional value at the first '='.
  name="${arg%%=*}"
  if [[ "$arg" == *=* ]]; then
    val="${arg#*=}"
    had_eq=1
  else
    val=""
    had_eq=0
  fi

  case "$name" in
    -h|--help)
      sed -n '2,45p' "$0"
      exit 0
      ;;
    -i|--interactive)     MODE="interactive" ;;
    -N|--non-interactive) MODE="non-interactive" ;;
    -n|--dry-run)         DRY_RUN=true ;;
    --no-backup)          BACKUP=false ;;
    --no-relaunch)        RELAUNCH=false ;;
    --no-gum)             USE_GUM=no ;;

    # Bool setting flags. The --no-* twin sets the opposite.
    --allow-closed-display-sleep)      set_bool ALLOW_CLOSED_DISPLAY_SLEEP "$val" 1 "$had_eq" "$name" ;;
    --no-allow-closed-display-sleep)   ALLOW_CLOSED_DISPLAY_SLEEP=0 ;;
    --allow-display-sleep)             set_bool ALLOW_DISPLAY_SLEEP "$val" 1 "$had_eq" "$name" ;;
    --no-allow-display-sleep)          ALLOW_DISPLAY_SLEEP=0 ;;
    --end-on-battery-below)            set_bool END_ON_BATTERY_BELOW "$val" 1 "$had_eq" "$name" ;;
    --no-end-on-battery-below)         END_ON_BATTERY_BELOW=0 ;;
    --ignore-battery-on-ac)            set_bool IGNORE_BATTERY_ON_AC "$val" 1 "$had_eq" "$name" ;;
    --no-ignore-battery-on-ac)         IGNORE_BATTERY_ON_AC=0 ;;
    --start-on-launch)                 set_bool START_ON_LAUNCH "$val" 1 "$had_eq" "$name" ;;
    --no-start-on-launch)              START_ON_LAUNCH=0 ;;
    --hide-dock-icon)                  set_bool HIDE_DOCK_ICON "$val" 1 "$had_eq" "$name" ;;
    --no-hide-dock-icon)               HIDE_DOCK_ICON=0 ;;
    --allow-screen-saver)              set_bool ALLOW_SCREEN_SAVER "$val" 1 "$had_eq" "$name" ;;
    --no-allow-screen-saver)           ALLOW_SCREEN_SAVER=0 ;;
    --end-on-forced-sleep)             set_bool END_ON_FORCED_SLEEP "$val" 1 "$had_eq" "$name" ;;
    --no-end-on-forced-sleep)          END_ON_FORCED_SLEEP=0 ;;
    --enable-start-end-notifs)         set_bool ENABLE_START_END_NOTIFS "$val" 1 "$had_eq" "$name" ;;
    --no-enable-start-end-notifs)      ENABLE_START_END_NOTIFS=0 ;;
    --enable-auto-end-notifs)          set_bool ENABLE_AUTO_END_NOTIFS "$val" 1 "$had_eq" "$name" ;;
    --no-enable-auto-end-notifs)       ENABLE_AUTO_END_NOTIFS=0 ;;

    # Integer setting flag.
    --battery-threshold)
      if [ -z "$val" ]; then
        err "--battery-threshold needs a value (e.g. --battery-threshold=25)"
        exit 2
      fi
      if ! [[ "$val" =~ ^[0-9]+$ ]] || (( val < 5 || val > 95 )); then
        err "--battery-threshold must be an integer between 5 and 95 (got: $val)"
        exit 2
      fi
      BATTERY_THRESHOLD="$val"
      ;;

    *)
      err "Unknown argument: $arg"
      info "Run: $0 --help"
      exit 2
      ;;
  esac

  # Any setting flag implies non-interactive (unless --interactive was explicit).
  case "$name" in
    --allow-closed-display-sleep|--no-allow-closed-display-sleep|\
    --allow-display-sleep|--no-allow-display-sleep|\
    --end-on-battery-below|--no-end-on-battery-below|\
    --ignore-battery-on-ac|--no-ignore-battery-on-ac|\
    --start-on-launch|--no-start-on-launch|\
    --hide-dock-icon|--no-hide-dock-icon|\
    --allow-screen-saver|--no-allow-screen-saver|\
    --end-on-forced-sleep|--no-end-on-forced-sleep|\
    --enable-start-end-notifs|--no-enable-start-end-notifs|\
    --enable-auto-end-notifs|--no-enable-auto-end-notifs|\
    --battery-threshold)
      [ -z "$MODE" ] && MODE="non-interactive"
      ;;
  esac
done

# Default mode: interactive. But if the shell has no controlling terminal
# (CI, piped `bash < script`, crontab, remote shell without TTY allocation,
# etc.) then prompting is impossible — fall back to non-interactive silently.
# If the user explicitly asked for interactive mode in a non-TTY context,
# that's an error — tell them.
shell_is_interactive() {
  # A controlling TTY exists if /dev/tty is readable AND we can open it.
  # Using `-r /dev/tty` alone is not enough: it's readable in cron but opening
  # it will fail. Try an actual open to be sure.
  [ -r /dev/tty ] && [ -w /dev/tty ] && { : > /dev/tty; } 2>/dev/null
}

if [ -z "$MODE" ]; then
  if shell_is_interactive; then
    MODE="interactive"
  else
    MODE="non-interactive"
    info "No TTY detected — running non-interactively with defaults."
  fi
elif [ "$MODE" = "interactive" ] && ! shell_is_interactive; then
  err "--interactive was requested but this shell has no controlling terminal."
  info "Use --non-interactive (with flags) for scripted / piped runs."
  exit 2
fi

# ---- Pre-flight ----
if [ ! -d "/Applications/$APP_NAME.app" ]; then
  err "$APP_NAME is not installed. Get it from the Mac App Store:"
  info "https://apps.apple.com/us/app/amphetamine/id937984704"
  exit 1
fi

# ---- UI layer (gum if available, plain `read` fallback) ----
# gum is Charm.sh's TUI toolkit: https://github.com/charmbracelet/gum
# Zero-dep by default: if gum is missing and we're interactive with Homebrew
# available, we offer to install it; otherwise we fall back to plain prompts.
have_gum() {
  [ "$USE_GUM" != "no" ] && command -v gum >/dev/null 2>&1
}

# Offer to install gum via Homebrew. Silent no-op if:
#   - user passed --no-gum
#   - gum is already installed
#   - brew isn't available (we don't pull in Homebrew on the user's behalf)
#   - we're not on a TTY (can't ask)
# Called once before interactive UI runs.
maybe_offer_gum_install() {
  [ "$USE_GUM" = "no" ] && return 0
  command -v gum >/dev/null 2>&1 && return 0
  command -v brew >/dev/null 2>&1 || return 0
  shell_is_interactive || return 0
  echo
  info "Tip: 'gum' gives this walkthrough a nicer TUI (checkboxes, spinners, etc.)."
  info "     https://github.com/charmbracelet/gum"
  local reply
  if ! read -r -p "  Install it now via Homebrew? [y/N]: " reply < /dev/tty; then
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
      info "Skipping gum — using plain prompts. Set --no-gum to silence this next time."
      ;;
  esac
  echo
}

# Framed banner at the top of the walkthrough. Fallback: bold line + info.
ui_banner() {
  local title="$1" subtitle="${2:-}"
  if have_gum; then
    if [ -n "$subtitle" ]; then
      gum style --border normal --margin "0 0" --padding "0 2" \
        --border-foreground 212 "$title" "$subtitle"
    else
      gum style --border normal --margin "0 0" --padding "0 2" \
        --border-foreground 212 "$title"
    fi
    echo
  else
    bold "$title"
    [ -n "$subtitle" ] && info "$subtitle"
    echo
  fi
}

# ui_confirm <prompt> <default: yes|no>  → returns 0 for yes, 1 for no.
# Wraps `gum confirm` (which also returns 0/1) and falls back to plain read.
ui_confirm() {
  local prompt="$1" default="${2:-yes}" reply default_hint
  if have_gum; then
    if [ "$default" = "yes" ]; then
      gum confirm --default=true  "$prompt"
    else
      gum confirm --default=false "$prompt"
    fi
    return $?
  fi
  case "$default" in
    yes) default_hint="Y/n" ;;
    *)   default_hint="y/N" ;;
  esac
  while :; do
    if ! read -r -p "  $prompt [$default_hint]: " reply < /dev/tty; then
      echo
      return 1
    fi
    reply="${reply:-$default}"
    case "$reply" in
      1|true|TRUE|True|yes|YES|Yes|y|Y) return 0 ;;
      0|false|FALSE|False|no|NO|No|n|N) return 1 ;;
      *) warn "Please answer y or n (or press Enter to keep the default)." ;;
    esac
  done
}

# ui_input <prompt> <default>  → echoes the chosen value on stdout.
ui_input() {
  local prompt="$1" default="$2" reply
  if have_gum; then
    reply="$(gum input --prompt "$prompt " --placeholder "$default" --value "$default")"
    # gum returns empty if the user deletes the prefilled value; fall back.
    printf '%s' "${reply:-$default}"
    return 0
  fi
  if ! read -r -p "  $prompt [$default]: " reply < /dev/tty; then
    printf '%s' "$default"
    return 0
  fi
  printf '%s' "${reply:-$default}"
}

# ---- Interactive prompts ----
ask_bool() {
  # $1 = prompt, $2 = var name
  local prompt="$1" var="$2" current="${!2}" default_kw
  case "$current" in
    1) default_kw="yes" ;;
    *) default_kw="no"  ;;
  esac
  if ui_confirm "$prompt" "$default_kw"; then
    printf -v "$var" '%s' 1
  else
    printf -v "$var" '%s' 0
  fi
}

ask_int() {
  # $1 = prompt, $2 = var name, $3 = min, $4 = max
  local prompt="$1" var="$2" min="$3" max="$4" current="${!2}" reply
  while :; do
    reply="$(ui_input "$prompt" "$current")"
    reply="${reply:-$current}"
    if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= min && reply <= max )); then
      printf -v "$var" '%s' "$reply"
      return 0
    fi
    warn "Please enter an integer between $min and $max."
  done
}

run_interactive() {
  ui_banner "Amphetamine configuration — interactive walkthrough" \
            "Press Enter to keep the default shown in brackets."

  # Asking the user about "Allow Closed-Display Sleep" directly would read
  # weird — people think in terms of "stay awake with lid closed". Translate
  # once: ask the friendly question into STAY_AWAKE_LID_CLOSED, then flip.
  local STAY_AWAKE_LID_CLOSED
  case "$ALLOW_CLOSED_DISPLAY_SLEEP" in
    0) STAY_AWAKE_LID_CLOSED=1 ;;
    *) STAY_AWAKE_LID_CLOSED=0 ;;
  esac
  ask_bool 'Stay awake with the lid closed? (the core use case)'    STAY_AWAKE_LID_CLOSED
  case "$STAY_AWAKE_LID_CLOSED" in
    1) ALLOW_CLOSED_DISPLAY_SLEEP=0 ;;
    *) ALLOW_CLOSED_DISPLAY_SLEEP=1 ;;
  esac

  ask_bool 'Let the display sleep during a session? (saves battery and heat)' ALLOW_DISPLAY_SLEEP
  ask_bool 'Auto-end the session when battery gets low?'            END_ON_BATTERY_BELOW
  if [ "$END_ON_BATTERY_BELOW" = "1" ]; then
    ask_int  'Battery percent to end the session at (5–95)?'        BATTERY_THRESHOLD 5 95
  fi
  ask_bool 'Ignore the battery threshold when plugged into AC?'     IGNORE_BATTERY_ON_AC
  ask_bool 'Start a session automatically when Amphetamine launches?' START_ON_LAUNCH
  ask_bool 'Hide the Dock icon (menu-bar only)?'                    HIDE_DOCK_ICON

  # Advanced settings — skip by default.
  local SHOW_ADVANCED=0
  ask_bool 'Configure advanced settings (notifications, screen saver, forced sleep)?' SHOW_ADVANCED

  if [ "$SHOW_ADVANCED" = "1" ]; then
    ask_bool 'Allow the screen saver during a session?'             ALLOW_SCREEN_SAVER
    ask_bool 'End the session if the Mac is forced to sleep?'       END_ON_FORCED_SLEEP
    ask_bool 'Show session start/end notifications?'                ENABLE_START_END_NOTIFS
    ask_bool 'Show a notification when a session auto-ends?'        ENABLE_AUTO_END_NOTIFS
  fi
  echo
}

if [ "$MODE" = "interactive" ]; then
  maybe_offer_gum_install
  run_interactive
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

# Interactive mode confirms before writing.
if [ "$MODE" = "interactive" ] && [ -r /dev/tty ]; then
  if ! ui_confirm "Apply these settings?" "yes"; then
    info "Aborted. Nothing was written."
    exit 0
  fi
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
write_bool() { defaults write "$BUNDLE_ID" "$1" -bool "$2"; }
write_int()  { defaults write "$BUNDLE_ID" "$1" -int  "$2"; }

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
