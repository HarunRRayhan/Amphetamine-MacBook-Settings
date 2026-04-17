#!/usr/bin/env bash
# export.sh — Export your current Amphetamine settings to a plist file.
# Useful for sharing with a second Mac or contributing a new preset.
#
# Usage:
#   ./scripts/export.sh                              # writes to ./my-amphetamine-settings.plist
#   ./scripts/export.sh ~/Desktop/my-settings.plist  # custom path

set -euo pipefail

BUNDLE_ID="com.if.Amphetamine"
OUT="${1:-./my-amphetamine-settings.plist}"

if ! defaults domains 2>/dev/null | tr ',' '\n' | grep -q "^ *$BUNDLE_ID$"; then
  echo "No Amphetamine preferences found. Has Amphetamine been launched at least once?" >&2
  exit 1
fi

defaults export "$BUNDLE_ID" "$OUT"
echo "Exported settings to: $OUT"
ls -la "$OUT"
