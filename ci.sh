#!/bin/bash
set -euo pipefail

# Determine configuration
export RUST_TEST_NOCAPTURE=1
export RUST_BACKTRACE=1
export RUSTFLAGS="-D warnings"
export CARGO_INCREMENTAL=0
export CARGO_EXTRA_FLAGS="--all-features"

# Prepare
echo "Build and install miri"
./miri build --all-targets --locked
./miri install # implicitly locked
echo

# Test
function run_tests {
  if [ -n "${MIRI_TEST_TARGET+exists}" ]; then
    echo "Testing foreign architecture $MIRI_TEST_TARGET"
  else
    echo "Testing host architecture"
  fi

  ./miri test --locked
  if [ -z "${MIRI_TEST_TARGET+exists}" ]; then
    # Only for host architecture: tests with MIR optimizations
    #FIXME: Only testing opt level 1 due to <https://github.com/rust-lang/rust/issues/77564>.
    MIRIFLAGS="-Z mir-opt-level=1" ./miri test --locked
  fi

  if command -v python3; then
    PYTHON=python3
  else
    PYTHON=python
  fi

  # "miri test" has built the sysroot for us, now this should pass without
  # any interactive questions.
  ${PYTHON} test-cargo-miri/run-test.py
  echo
}

# host
run_tests

case $RUST_OS_NAME in
  Linux)
    MIRI_TEST_TARGET=i686-unknown-linux-gnu run_tests
    MIRI_TEST_TARGET=x86_64-apple-darwin run_tests
    MIRI_TEST_TARGET=i686-pc-windows-msvc run_tests
    ;;
  macOS )
    MIRI_TEST_TARGET=mips64-unknown-linux-gnuabi64 run_tests # big-endian architecture
    MIRI_TEST_TARGET=x86_64-pc-windows-msvc run_tests
    ;;
  Windows)
    MIRI_TEST_TARGET=x86_64-unknown-linux-gnu run_tests
    MIRI_TEST_TARGET=x86_64-apple-darwin run_tests
    ;;
  * )
    echo "FATAL: unknown OS"
    exit 1
    ;;
esac
