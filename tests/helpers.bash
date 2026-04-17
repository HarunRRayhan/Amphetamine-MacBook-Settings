# Shared bats helpers for configure.sh / install.sh tests.
#
# Each test starts with an isolated $BATS_TEST_TMPDIR. We put fake Amphetamine
# bundles, stub executables for things like `defaults` / `pgrep` / `osascript`,
# and a throwaway HOME in there. That keeps tests hermetic: no real commands
# run, no real preferences get written, no real Amphetamine has to exist.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# Prepend a stubs dir to PATH so scripts call our fakes instead of real tools.
setup_stubs() {
  local stubs="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$stubs"
  cp -a "$REPO_ROOT/tests/fixtures/bin/." "$stubs/"
  chmod +x "$stubs"/*
  # Keep essentials (coreutils, bash, sed, awk, grep). We don't strip the
  # existing PATH — the stubs override by virtue of being first.
  export PATH="$stubs:$PATH"
  export STUBS_DIR="$stubs"
  # Log file the stubs append to so tests can inspect what was called.
  export STUB_LOG="$BATS_TEST_TMPDIR/stub.log"
  : > "$STUB_LOG"
}

# Create a fake Amphetamine.app bundle somewhere under $BATS_TEST_TMPDIR and
# point AMPHETAMINE_APP_PATH at it so the scripts' pre-flight check passes.
fake_amphetamine_app() {
  local app="$BATS_TEST_TMPDIR/Applications/Amphetamine.app"
  mkdir -p "$app/Contents"
  export AMPHETAMINE_APP_PATH="$app"
}

# Common setup: stubs + fake bundle. Individual tests can skip this and set
# things up manually (e.g. to assert the "not installed" error path).
bootstrap_env() {
  setup_stubs
  fake_amphetamine_app
}
