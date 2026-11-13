# rustyfarian-ci — development tasks
#
# The root workspace is host-only (fixtures/blink) and backs the host-smoke workflow.
# The firmware fixtures are separate workspaces with their own toolchain and Cargo.lock;
# the smoke-targets workflow builds them one matrix job at a time via `just ci-blink`.

# list available recipes
_default:
    @just --list

# Firmware sources the host checks format without building them.
fixture_sources := "fixtures/blink-esp-hal/src/main.rs fixtures/blink-esp-idf/src/main.rs fixtures/blink-esp-idf/build.rs fixtures/blink-avr/src/main.rs"

# Puts the espup Xtensa GCC and libclang on PATH when ~/export-esp.sh was not sourced; CI exports both.
esp_env := 'if ! command -v xtensa-esp32-elf-gcc >/dev/null 2>&1 && [ -f "$HOME/export-esp.sh" ]; then . "$HOME/export-esp.sh"; fi'

# Chip names accepted by the ESP recipes.
esp_chips := "esp32 | s3 | c3 | c6"

# --- Fixtures ------------------------------------------------------------

# build and link the bare-metal esp-hal blink fixture for one chip: esp32 | s3 | c3 | c6
[group('fixtures')]
blink-hal chip:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ chip }}" in
        esp32) target=xtensa-esp32-none-elf;        feature=esp32 ;;
        s3)    target=xtensa-esp32s3-none-elf;      feature=esp32s3 ;;
        c3)    target=riscv32imc-unknown-none-elf;  feature=esp32c3 ;;
        c6)    target=riscv32imac-unknown-none-elf; feature=esp32c6 ;;
        *) echo "blink-hal: unknown chip '{{ chip }}' ({{ esp_chips }})" >&2; exit 2 ;;
    esac
    cd fixtures/blink-esp-hal
    if [[ "$target" == xtensa-* ]]; then
        {{ esp_env }}
        cargo +esp build --release --locked --target "$target" --features "$feature" -Zbuild-std=core
    else
        rustup target add "$target"
        cargo build --release --locked --target "$target" --features "$feature"
    fi

# build and link the ESP-IDF (std) blink fixture for one chip: esp32 | s3 | c3 | c6 (slow on first run)
[group('fixtures')]
blink-idf chip:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ chip }}" in
        esp32) target=xtensa-esp32-espidf;    mcu=esp32 ;;
        s3)    target=xtensa-esp32s3-espidf;  mcu=esp32s3 ;;
        c3)    target=riscv32imc-esp-espidf;  mcu=esp32c3 ;;
        c6)    target=riscv32imac-esp-espidf; mcu=esp32c6 ;;
        *) echo "blink-idf: unknown chip '{{ chip }}' ({{ esp_chips }})" >&2; exit 2 ;;
    esac
    cd fixtures/blink-esp-idf
    {{ esp_env }}
    MCU="$mcu" cargo +esp build --release --locked --target "$target" -Zbuild-std=std,panic_abort

# build and link the AVR blink fixture for the ATmega328P (pinned nightly from its rust-toolchain.toml, needs avr-gcc)
[group('fixtures')]
blink-avr:
    cd fixtures/blink-avr && cargo build --release --locked -Zbuild-std=core

# build every firmware fixture: 4 esp-hal chips, 4 ESP-IDF chips and AVR (slow)
[group('fixtures')]
blink-all:
    #!/usr/bin/env bash
    set -euo pipefail
    for chip in esp32 s3 c3 c6; do just blink-hal "$chip"; done
    for chip in esp32 s3 c3 c6; do just blink-idf "$chip"; done
    just blink-avr

# --- CI ------------------------------------------------------------------
# Each GitHub Actions job runs exactly one of these.

# CI job: check formatting of the workspace and the firmware fixture sources
[group('ci')]
ci-fmt:
    cargo fmt --all --check
    rustfmt --check --edition 2021 {{ fixture_sources }}

# CI job: lint the host workspace with warnings-as-errors
[group('ci')]
ci-clippy:
    cargo clippy --workspace --all-targets --locked -- -D warnings

# CI job: test the host workspace
[group('ci')]
ci-test:
    cargo test --workspace --locked

# CI job: cargo-deny licenses, advisories, bans and sources
[group('ci')]
ci-deny:
    cargo deny check

# CI job: cargo-audit advisories
[group('ci')]
ci-audit:
    cargo audit

# CI job (host-smoke): prove setup-rust-just installed its components and tools, then lint
[group('ci')]
ci-setup-rust-just:
    cargo fmt --version
    cargo clippy --version
    cargo deny --version
    cargo audit --version
    cargo clippy --workspace --all-targets --locked -- -D warnings

# CI job: build one smoke-targets matrix entry: `hal <chip>`, `idf <chip>` or `avr atmega328p`
[group('ci')]
ci-blink runtime chip:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ runtime }}" in
        hal) just blink-hal "{{ chip }}" ;;
        idf) just blink-idf "{{ chip }}" ;;
        avr)
            if [ "{{ chip }}" != atmega328p ]; then
                echo "ci-blink: avr supports atmega328p only (got '{{ chip }}')" >&2
                exit 2
            fi
            just blink-avr
            ;;
        *) echo "ci-blink: unknown runtime '{{ runtime }}' (hal, idf, avr)" >&2; exit 2 ;;
    esac

# --- act -----------------------------------------------------------------

# dry-run every workflow job with act (lists the 9 smoke-targets jobs and the host-smoke jobs)
[group('act')]
act-list:
    act -n --pull=false -P ubuntu-latest=catthehacker/ubuntu:act-latest -W .github/workflows/smoke-targets.yml
    act -n --pull=false -P ubuntu-latest=catthehacker/ubuntu:act-latest -W .github/workflows/host-smoke.yml --local-repository "datenkollektiv/rustyfarian-ci@v1={{ justfile_directory() }}"
