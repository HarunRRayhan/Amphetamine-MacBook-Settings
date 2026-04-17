#!/usr/bin/env bash
# shell-helpers.sh — Shell functions for controlling Amphetamine from the CLI.
#
# Works under both bash and zsh. Source it from your ~/.bashrc or ~/.zshrc:
#
#     source ~/Projects/Amphetamine-MacBook-Settings/scripts/shell-helpers.sh
#
# Or run the self-installer once:
#
#     ~/Projects/Amphetamine-MacBook-Settings/scripts/shell-helpers.sh install
#
# That appends the source line to whichever rc file matches your current
# shell (both if you use both).
#
# After installing, open a new terminal tab and you get these commands:
#
#     amph-on         start an indefinite session
#     amph-off        end the current session
#     amph-status     show whether a session is active
#     amph-toggle     flip between on and off
#     amph-config     show the current plist values
#
# The functions shell out to `osascript` and `defaults`, so nothing here
# is shell-specific — but we guard against zsh's stricter word-splitting
# so the same file works in both shells.

# ---- Self-installer ----
# If this file was *executed* (not sourced), run the installer and exit.
# Detecting sourced-vs-executed portably between bash and zsh:
#   - bash: ${BASH_SOURCE[0]} != $0 when sourced
#   - zsh:  $ZSH_EVAL_CONTEXT contains ":file" when sourced
_amph_is_sourced() {
  if [ -n "${BASH_VERSION:-}" ]; then
    [ "${BASH_SOURCE[0]}" != "$0" ]
  elif [ -n "${ZSH_VERSION:-}" ]; then
    case "${ZSH_EVAL_CONTEXT:-}" in *:file*) return 0 ;; *) return 1 ;; esac
  else
    # Unknown shell — assume sourced so functions get defined.
    return 0
  fi
}

_amph_install_into_rc() {
  local script_path rc added=0
  script_path="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/$(basename "${BASH_SOURCE[0]:-$0}")"
  local line="source \"$script_path\"  # amphetamine-helpers"

  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ] || [ "$(basename "$rc")" = ".zshrc" ] || [ "$(basename "$rc")" = ".bashrc" ]; then
      if [ -f "$rc" ] && grep -qF "amphetamine-helpers" "$rc"; then
        printf '  already installed in %s\n' "$rc"
      else
        printf '%s\n' "$line" >> "$rc"
        printf '  added to %s\n' "$rc"
        added=$((added + 1))
      fi
    fi
  done

  if [ "$added" -gt 0 ]; then
    printf '\nOpen a new terminal tab (or run: source ~/.zshrc  /  source ~/.bashrc)\n'
    printf 'Then try:  amph-status\n'
  fi
}

if ! _amph_is_sourced; then
  case "${1:-help}" in
    install) _amph_install_into_rc ;;
    help|-h|--help)
      sed -n '2,22p' "$0"
      ;;
    *)
      printf 'Usage: %s install\n' "$0" >&2
      exit 2
      ;;
  esac
  return 0 2>/dev/null || exit 0
fi

# ---- Sourced path: define the helper functions ----

_amph_running() { pgrep -x Amphetamine >/dev/null 2>&1; }

_amph_start_app_if_needed() {
  if ! _amph_running; then
    open -a Amphetamine 2>/dev/null
    # Wait up to 3s for it to come up
    local i=0
    while ! _amph_running; do
      i=$((i + 1))
      [ "$i" -ge 6 ] && return 1
      sleep 0.5
    done
  fi
}

amph-status() {
  if ! _amph_running; then
    printf 'Amphetamine: not running\n'
    return 1
  fi
  if pmset -g assertions 2>/dev/null | grep -qi 'Amphetamine'; then
    printf 'Amphetamine: session ACTIVE\n'
    pmset -g assertions | awk '/Amphetamine/ {print "  " $0}'
    return 0
  else
    printf 'Amphetamine: running, no active session\n'
    return 1
  fi
}

amph-on() {
  _amph_start_app_if_needed || { printf 'Failed to launch Amphetamine\n' >&2; return 1; }
  osascript <<'APPLESCRIPT' >/dev/null 2>&1
tell application "Amphetamine"
  start new session with options {duration:0, displaySleepAllowed:true}
end tell
APPLESCRIPT
  # Fallback: use the menu bar if AppleScript dictionary isn't accepted
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    osascript -e 'tell application "System Events" to tell process "Amphetamine" to click menu bar item 1 of menu bar 2' >/dev/null 2>&1 || true
  fi
  sleep 0.5
  amph-status
}

amph-off() {
  if ! _amph_running; then
    printf 'Amphetamine: not running\n'
    return 0
  fi
  osascript <<'APPLESCRIPT' >/dev/null 2>&1
tell application "Amphetamine" to end all sessions
APPLESCRIPT
  sleep 0.3
  amph-status || true
}

amph-toggle() {
  if amph-status >/dev/null 2>&1; then
    amph-off
  else
    amph-on
  fi
}

amph-config() {
  local bid="com.if.Amphetamine"
  local keys=(
    'Allow Closed-Display Sleep'
    'Allow Display Sleep'
    'Battery Threshold'
    'End Sessions If Battery Is Below Percentage'
    'Ignore Battery on AC'
    'Launch At Login'
    'Start Session On Launch'
    'Hide Dock Icon'
  )
  printf 'Current Amphetamine prefs (%s):\n' "$bid"
  local k v
  for k in "${keys[@]}"; do
    v="$(defaults read "$bid" "$k" 2>/dev/null || echo '(unset)')"
    printf '  %-45s = %s\n' "$k" "$v"
  done
}
