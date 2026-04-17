# Tests

`bats` tests for `scripts/configure.sh` and `scripts/install.sh`. The suite
runs on every push / PR via `.github/workflows/ci.yml` on both `ubuntu-latest`
and `macos-latest`.

## Running locally

```bash
# macOS
brew install bats-core
bats tests/

# Ubuntu / Debian
sudo apt-get install -y bats
bats tests/
```

## How it works

- `AMPHETAMINE_APP_PATH` — the scripts support this env var as a test seam.
  Tests point it at a fake bundle inside `$BATS_TEST_TMPDIR` so pre-flight
  passes even on Linux CI runners where Amphetamine isn't installed.
- `tests/fixtures/bin/` — stub executables for `defaults`, `osascript`,
  `pgrep`, `open`, and `pkill`. `tests/helpers.bash` prepends that directory
  to `$PATH`, so the scripts call our fakes instead of real macOS binaries.
- Stubs append every invocation to `$STUB_LOG`, so tests can assert on what
  would have happened (e.g. "did install.sh call `defaults import`?").
- Most parsing / validation tests use `--dry-run` so they never reach the
  write path at all.
