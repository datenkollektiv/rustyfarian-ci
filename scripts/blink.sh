#!/usr/bin/env bash
set -euo pipefail
# blink.sh — build and link one blink fixture: esp-hal, ESP-IDF or AVR
# Usage: scripts/blink.sh <hal|idf|avr> <chip>   (chip: esp32 | s3 | c3 | c6; atmega328p for avr)
# The single source of the chip → target mapping; the smoke-targets matrix mirrors it.

usage="usage: scripts/blink.sh <hal|idf|avr> <chip>"
runtime="${1:?$usage}"
chip="${2:?$usage}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Puts the espup Xtensa GCC and libclang on PATH when ~/export-esp.sh was not sourced; CI exports both.
esp_env() {
    if ! command -v xtensa-esp32-elf-gcc >/dev/null 2>&1 && [ -f "$HOME/export-esp.sh" ]; then
        # shellcheck source=/dev/null
        . "$HOME/export-esp.sh"
    fi
}

if [ "$runtime" = avr ]; then
    if [ "$chip" != atmega328p ]; then
        echo "blink: avr supports atmega328p only (got '$chip')" >&2
        exit 2
    fi
    # The pinned nightly comes from fixtures/blink-avr/rust-toolchain.toml.
    cd "$root/fixtures/blink-avr"
    exec cargo build --release --locked -Zbuild-std=core
fi

case "$chip" in
    esp32) mcu=esp32;   hal_target=xtensa-esp32-none-elf;        idf_target=xtensa-esp32-espidf ;;
    s3)    mcu=esp32s3; hal_target=xtensa-esp32s3-none-elf;      idf_target=xtensa-esp32s3-espidf ;;
    c3)    mcu=esp32c3; hal_target=riscv32imc-unknown-none-elf;  idf_target=riscv32imc-esp-espidf ;;
    c6)    mcu=esp32c6; hal_target=riscv32imac-unknown-none-elf; idf_target=riscv32imac-esp-espidf ;;
    *) echo "blink: unknown chip '$chip' (esp32 | s3 | c3 | c6)" >&2; exit 2 ;;
esac

case "$runtime" in
    hal)
        cd "$root/fixtures/blink-esp-hal"
        if [[ "$hal_target" == xtensa-* ]]; then
            # Xtensa has no prebuilt core: the esp toolchain builds it.
            esp_env
            exec cargo +esp build --release --locked --target "$hal_target" --features "$mcu" -Zbuild-std=core
        fi
        # RISC-V uses stable with the prebuilt rustup target.
        rustup target add "$hal_target"
        exec cargo build --release --locked --target "$hal_target" --features "$mcu"
        ;;
    idf)
        cd "$root/fixtures/blink-esp-idf"
        esp_env
        MCU="$mcu" exec cargo +esp build --release --locked --target "$idf_target" -Zbuild-std=std,panic_abort
        ;;
    *) echo "blink: unknown runtime '$runtime' (hal, idf, avr)" >&2; exit 2 ;;
esac
