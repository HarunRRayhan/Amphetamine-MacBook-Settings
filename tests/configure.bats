#!/usr/bin/env bats
#
# Tests for scripts/configure.sh — mostly arg parsing, validation, and the
# dry-run plan output. We avoid the "write real prefs" path entirely by
# running with --dry-run (plus the AMPHETAMINE_APP_PATH test seam so
# pre-flight doesn't fail on Linux CI runners).

load helpers

setup() {
  bootstrap_env
  CONFIGURE="$REPO_ROOT/scripts/configure.sh"
}

# --- Help / usage ---------------------------------------------------------

@test "configure --help exits 0 and prints the usage header" {
  run "$CONFIGURE" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"configure.sh"* ]]
  # Help text opens with "Interactive (the default)" — assert that directly
  # rather than a made-up "Usage" header.
  [[ "$output" == *"Interactive"* ]]
  [[ "$output" == *"--battery-threshold"* ]]
}

@test "configure -h works the same as --help" {
  run "$CONFIGURE" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"configure.sh"* ]]
}

# --- Unknown flags --------------------------------------------------------

@test "configure rejects an unknown flag with exit 2" {
  run "$CONFIGURE" --not-a-real-flag
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown argument"* ]]
}

# --- Pre-flight (bundle missing) -----------------------------------------

@test "configure fails with a clear error when Amphetamine is not installed" {
  unset AMPHETAMINE_APP_PATH
  export AMPHETAMINE_APP_PATH="$BATS_TEST_TMPDIR/nowhere/Amphetamine.app"
  run "$CONFIGURE" --non-interactive --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"Amphetamine is not installed"* ]]
}

# --- Dry-run plan + defaults ---------------------------------------------

@test "configure --non-interactive --dry-run prints the plan and exits 0 without writing" {
  run "$CONFIGURE" --non-interactive --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Amphetamine configuration plan"* ]]
  [[ "$output" == *"Allow Closed-Display Sleep    = 0"* ]]
  [[ "$output" == *"Allow Display Sleep           = 1"* ]]
  [[ "$output" == *"Low Battery Percent           = 30%"* ]]
  [[ "$output" == *"Ignore Battery on AC          = 1"* ]]
  [[ "$output" == *"Dry run"* ]]
  # No writes should have happened — stub log should not contain `defaults write`.
  run grep -F "defaults write" "$STUB_LOG"
  [ "$status" -ne 0 ]
}

# --- Integer validation: --battery-threshold ----------------------------

@test "configure accepts a valid --battery-threshold" {
  run "$CONFIGURE" --battery-threshold=25 --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Low Battery Percent           = 25%"* ]]
}

@test "configure rejects --battery-threshold below the minimum" {
  run "$CONFIGURE" --battery-threshold=2 --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"between 5 and 95"* ]]
}

@test "configure rejects --battery-threshold above the maximum" {
  run "$CONFIGURE" --battery-threshold=99 --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"between 5 and 95"* ]]
}

@test "configure rejects non-numeric --battery-threshold" {
  run "$CONFIGURE" --battery-threshold=abc --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"between 5 and 95"* ]]
}

@test "configure rejects empty --battery-threshold" {
  run "$CONFIGURE" --battery-threshold= --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"--battery-threshold"* ]]
}

# --- Bool flag forms -----------------------------------------------------
# Each of these uses --hide-dock-icon because its default is 1 — easy to see
# the flip to 0 in plan output.

@test "bool flag: --no-hide-dock-icon flips the default to 0" {
  run "$CONFIGURE" --no-hide-dock-icon --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hide Dock Icon                = 0"* ]]
}

@test "bool flag: --hide-dock-icon=no" {
  run "$CONFIGURE" --hide-dock-icon=no --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hide Dock Icon                = 0"* ]]
}

@test "bool flag: --hide-dock-icon=false" {
  run "$CONFIGURE" --hide-dock-icon=false --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hide Dock Icon                = 0"* ]]
}

@test "bool flag: --hide-dock-icon=0" {
  run "$CONFIGURE" --hide-dock-icon=0 --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hide Dock Icon                = 0"* ]]
}

@test "bool flag: --hide-dock-icon=n" {
  run "$CONFIGURE" --hide-dock-icon=n --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hide Dock Icon                = 0"* ]]
}

@test "bool flag: --hide-dock-icon=yes stays at 1" {
  run "$CONFIGURE" --hide-dock-icon=yes --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hide Dock Icon                = 1"* ]]
}

@test "bool flag: --allow-closed-display-sleep (bare) flips to 1 — opposite of the preset" {
  # The whole point of this repo is to keep the Mac awake lid-closed (= 0).
  # Bare --allow-closed-display-sleep means "set to on", which is 1. Verify
  # that bare-flag semantics really do override the preset.
  run "$CONFIGURE" --allow-closed-display-sleep --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Allow Closed-Display Sleep    = 1"* ]]
}

@test "bool flag: empty value after = is rejected" {
  run "$CONFIGURE" --hide-dock-icon= --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"empty value"* ]]
}

@test "bool flag: unrecognized value is rejected" {
  run "$CONFIGURE" --hide-dock-icon=maybe --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"Invalid value"* ]]
}

# --- Implied --non-interactive -------------------------------------------

@test "any setting flag implies non-interactive (no TTY needed)" {
  # We pipe /dev/null to stdin so there's definitely no TTY. If --non-interactive
  # weren't implied, configure.sh would error out about the missing terminal.
  run bash -c "'$CONFIGURE' --hide-dock-icon=no --dry-run < /dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hide Dock Icon                = 0"* ]]
}

# --- Coverage for every setting flag ------------------------------------
# One meaningful test per flag family. The test direction is chosen so it
# actually verifies parser wiring: flip a default=0 value up with the bare
# flag, flip a default=1 value down with the --no- twin.
#   default = 0  →  test bare flag moves plan line to 1
#   default = 1  →  test --no- flag moves plan line to 0
# (Defaults are defined at the top of configure.sh.)

@test "bool flag: --no-start-on-launch flips Start Session At Launch to 0" {
  # Default is 1.
  run "$CONFIGURE" --no-start-on-launch --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Start Session At Launch       = 0"* ]]
}

@test "bool flag: --allow-screen-saver flips Allow Screen Saver to 1" {
  # Default is 0.
  run "$CONFIGURE" --allow-screen-saver --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Allow Screen Saver            = 1"* ]]
}

@test "bool flag: --end-on-forced-sleep flips End On Forced Sleep to 1" {
  # Default is 0.
  run "$CONFIGURE" --end-on-forced-sleep --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"End On Forced Sleep           = 1"* ]]
}

@test "bool flag: --enable-start-end-notifs flips Session Start/End Notifs to 1" {
  # Default is 0.
  run "$CONFIGURE" --enable-start-end-notifs --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Session Start/End Notifs      = 1"* ]]
}

@test "bool flag: --no-enable-auto-end-notifs flips Auto-End Notifs to 0" {
  # Default is 1.
  run "$CONFIGURE" --no-enable-auto-end-notifs --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Auto-End Notifs               = 0"* ]]
}

@test "bool flag: --no-end-on-battery-below flips End Session On Low Battery to 0" {
  # Default is 1.
  run "$CONFIGURE" --no-end-on-battery-below --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"End Session On Low Battery    = 0"* ]]
}

@test "bool flag: --no-ignore-battery-on-ac flips Ignore Battery on AC to 0" {
  # Default is 1.
  run "$CONFIGURE" --no-ignore-battery-on-ac --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ignore Battery on AC          = 0"* ]]
}

# --- Control flags (no plan line to check — verify they're accepted) -----

@test "control flag: --no-backup is accepted and doesn't error" {
  # The plan doesn't advertise backup state; we just confirm the parser
  # recognizes the flag (and implies --non-interactive).
  run "$CONFIGURE" --no-backup --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Amphetamine configuration plan"* ]]
}

@test "control flag: --no-relaunch is accepted and doesn't error" {
  run "$CONFIGURE" --no-relaunch --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Amphetamine configuration plan"* ]]
}

# --- Combining flags -----------------------------------------------------

@test "multiple flags compose correctly in the plan" {
  run "$CONFIGURE" \
    --battery-threshold=20 \
    --no-allow-display-sleep \
    --no-hide-dock-icon \
    --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Low Battery Percent           = 20%"* ]]
  [[ "$output" == *"Allow Display Sleep           = 0"* ]]
  [[ "$output" == *"Hide Dock Icon                = 0"* ]]
}

# --- --no-gum flag -------------------------------------------------------

@test "configure accepts --no-gum without complaint" {
  run "$CONFIGURE" --no-gum --non-interactive --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Amphetamine configuration plan"* ]]
}

# --- Explicit --interactive without a TTY errors -------------------------

@test "--interactive in a non-TTY context errors out with a helpful message" {
  run bash -c "'$CONFIGURE' --interactive < /dev/null"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no controlling terminal"* ]]
}
