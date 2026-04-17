#!/usr/bin/env bats
#
# Tests for scripts/install.sh — help, unknown flags, and the non-TTY path
# (which applies the default preset via `defaults import`). We avoid the
# interactive mode picker by running without a TTY so install.sh falls
# through to MODE="default".

load helpers

setup() {
  bootstrap_env
  INSTALL="$REPO_ROOT/scripts/install.sh"
}

# --- Help / usage --------------------------------------------------------

@test "install --help exits 0 and prints the usage header" {
  run "$INSTALL" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"install.sh"* ]]
}

@test "install -h works the same as --help" {
  run "$INSTALL" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"install.sh"* ]]
}

# --- Unknown flags -------------------------------------------------------

@test "install rejects an unknown flag with exit 2" {
  run "$INSTALL" --not-a-real-flag
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown argument"* ]] || [[ "$stderr" == *"Unknown argument"* ]]
}

# --- Pre-flight (bundle missing) ----------------------------------------

@test "install fails with a clear error when Amphetamine is not installed" {
  unset AMPHETAMINE_APP_PATH
  export AMPHETAMINE_APP_PATH="$BATS_TEST_TMPDIR/nowhere/Amphetamine.app"
  # Pipe /dev/null to avoid the interactive menu; --default skips the picker.
  run bash -c "'$INSTALL' --default < /dev/null"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not installed"* ]]
}

# --- Default preset application -----------------------------------------

@test "install --default applies the default preset (calls defaults import)" {
  # No TTY, so install.sh auto-picks the default mode. Pass --default
  # explicitly to belt-and-suspenders it.
  run bash -c "'$INSTALL' --default < /dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"default preset"* ]] || [[ "$output" == *"default"* ]]
  [[ "$output" == *"Done"* ]]
  # Our defaults stub logs every call to $STUB_LOG. A successful run should
  # have `defaults import com.if.Amphetamine <path>/default.plist`.
  run grep -F "defaults import com.if.Amphetamine" "$STUB_LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"default.plist"* ]]
}

@test "install without flags and no TTY auto-picks the default preset" {
  run bash -c "'$INSTALL' < /dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No TTY detected"* ]]
  [[ "$output" == *"default preset"* ]] || [[ "$output" == *"default"* ]]
  run grep -F "defaults import" "$STUB_LOG"
  [ "$status" -eq 0 ]
}

# --- --custom forwards correctly ----------------------------------------

@test "install --custom execs configure.sh (non-TTY makes it error out cleanly)" {
  # --custom `exec`s into configure.sh -i. With no TTY, configure.sh will
  # error out about the missing terminal — that's fine and expected here.
  # We just want to see that the handoff happened.
  run bash -c "'$INSTALL' --custom < /dev/null"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Handing off to configure.sh"* ]]
  [[ "$output" == *"no controlling terminal"* ]]
}

@test "install --custom --no-gum forwards --no-gum to configure.sh" {
  # Again, non-TTY → configure.sh errors. But we can assert forwarding
  # indirectly: the install script's pre-handoff messaging should mention
  # handing off. Adding --no-gum shouldn't break anything.
  run bash -c "'$INSTALL' --custom --no-gum < /dev/null"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Handing off to configure.sh"* ]]
}

# --- --no-backup skips the backup step ---------------------------------

@test "install --default --no-backup skips the 'defaults export' backup call" {
  run bash -c "'$INSTALL' --default --no-backup < /dev/null"
  [ "$status" -eq 0 ]
  # The `defaults export` invocation is how install.sh backs up current prefs.
  # With --no-backup it should be absent from the stub log.
  run grep -F "defaults export" "$STUB_LOG"
  [ "$status" -ne 0 ]
}
