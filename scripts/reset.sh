#!/usr/bin/env bash
# reset.sh — Reset Amphetamine to its own stock defaults.
# Quits Amphetamine, backs up your current prefs, deletes the preference
# domain, then relaunches so Amphetamine recreates its defaults.
#
# Usage:
#   ./scripts/reset.sh             # with confirmation prompt
#   ./scripts/reset.sh --yes       # skip confirmation
#   ./scripts/reset.sh --no-backup # don't create a backup

set -euo pipefail

BUNDLE_ID="com.if.Amphetamine"
APP_NAME="Amphetamine"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$REPO_DIR/scripts/backups"

CONFIRMED=false
BACKUP=true

for arg in "$@"; do
  case "$arg" in
    --yes|-y) CONFIRMED=true ;;
    --no-backup) BACKUP=false ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [ "$CONFIRMED" = false ]; then
  read -r -p "Reset Amphetamine to its stock defaults? This will delete your current settings. [y/N]: " ans
  case "${ans:-N}" in
    [Yy]*) ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

if pgrep -xq "$APP_NAME"; then
  osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  sleep 1
  if pgrep -xq "$APP_NAME"; then
    killall "$APP_NAME" >/dev/null 2>&1 || true
  fi
fi

if [ "$BACKUP" = true ]; then
  mkdir -p "$BACKUP_DIR"
  ts="$(date +%Y%m%d-%H%M%S)"
  backup="$BACKUP_DIR/amphetamine-backup-$ts.plist"
  if defaults export "$BUNDLE_ID" "$backup" 2>/dev/null; then
    echo "Backup saved to: $backup"
  fi
fi

defaults delete "$BUNDLE_ID" 2>/dev/null || true
echo "Reset complete. Launch Amphetamine to regenerate stock defaults."
