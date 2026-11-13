#!/usr/bin/env bash
# No -e: doctor reports every problem instead of stopping at the first one.
set -uo pipefail
# doctor.sh — report the tools the host checks and the blink fixtures need, with the fix for each
# Usage: scripts/doctor.sh (no arguments)

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok=true
pass() { echo "  OK    $*"; }
warn() { echo "  WARN  $*"; }
fail() { echo "  FAIL  $*"; ok=false; }

# probe <label> <fix> <command...>: OK with the command's first output line, FAIL with the fix.
probe() {
    local label="$1" fix="$2"
    shift 2
    local out
    if out="$("$@" 2>/dev/null | head -1)" && [ -n "$out" ]; then
        pass "$label: $out"
    else
        fail "$label missing — $fix"
    fi
}

echo "=== host checks (just ci) ==="
probe just "install just" just --version
probe "stable rustc" "rustup toolchain install stable" rustc +stable --version
probe rustfmt "just setup" cargo +stable fmt --version
probe clippy "just setup" cargo +stable clippy --version
probe cargo-deny "cargo binstall cargo-deny" cargo deny --version
probe cargo-audit "cargo binstall cargo-audit" cargo audit --version

echo "=== esp-hal and ESP-IDF fixtures ==="
# Family pin (CONVENTIONS.md); CI installs exactly this version.
xtensa_pin="1.97.0.0"
if esp="$(rustc +esp --version 2>/dev/null)"; then
    case "$esp" in
        *"($xtensa_pin)"*) pass "esp toolchain: $esp" ;;
        *) warn "esp toolchain: $esp — CI uses $xtensa_pin (espup install --toolchain-version $xtensa_pin)" ;;
    esac
else
    fail "esp toolchain missing — espup install --toolchain-version $xtensa_pin"
fi
if command -v xtensa-esp32-elf-gcc >/dev/null 2>&1; then
    pass "xtensa-esp32-elf-gcc on PATH"
elif [ -f "$HOME/export-esp.sh" ]; then
    pass "xtensa-esp32-elf-gcc via ~/export-esp.sh (scripts/blink.sh sources it)"
else
    fail "xtensa-esp32-elf-gcc missing — espup install, then . ~/export-esp.sh"
fi
for target in riscv32imc-unknown-none-elf riscv32imac-unknown-none-elf; do
    if rustup +stable target list --installed 2>/dev/null | grep -qx "$target"; then
        pass "stable target $target"
    else
        warn "stable target $target missing — just setup (scripts/blink.sh also adds it)"
    fi
done
probe ldproxy "cargo binstall ldproxy" bash -c 'command -v ldproxy'
idf_version="$(sed -n 's/^ESP_IDF_VERSION = "\(.*\)"/\1/p' "$root/fixtures/blink-esp-idf/.cargo/config.toml")"
if [ -d "$HOME/.espressif/esp-idf/$idf_version" ]; then
    pass "ESP-IDF $idf_version in ~/.espressif"
else
    warn "ESP-IDF $idf_version not in ~/.espressif yet — the first just blink-idf downloads it"
fi

echo "=== AVR fixture ==="
avr_nightly="$(sed -n 's/^channel = "\(.*\)"/\1/p' "$root/fixtures/blink-avr/rust-toolchain.toml")"
if rustup component list --installed --toolchain "$avr_nightly" 2>/dev/null | grep -q '^rust-src'; then
    pass "AVR nightly $avr_nightly with rust-src"
else
    fail "AVR nightly $avr_nightly with rust-src missing — just setup"
fi
probe avr-gcc "brew install avr-gcc (apt: gcc-avr binutils-avr avr-libc)" avr-gcc --version

echo "=== act (optional) ==="
if command -v act >/dev/null 2>&1; then
    pass "act: $(act --version)"
    docker info >/dev/null 2>&1 && pass "docker daemon reachable" || warn "docker daemon not reachable — act needs it"
else
    warn "act missing — brew install act (only for just act-list)"
fi

echo ""
if [ "$ok" = true ]; then
    echo "doctor: all required tools present"
else
    echo "doctor: required tools missing — see FAIL lines above"
    exit 1
fi
