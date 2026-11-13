# rustyfarian-ci — development tasks
#
# The root workspace is host-only (fixtures/blink) and backs the host-smoke workflow.
# The firmware fixtures are separate workspaces with their own toolchain and Cargo.lock;
# the smoke-targets workflow builds them one matrix job at a time via `just ci-blink`.
# Run `just doctor` on a fresh machine.

# list available recipes
_default:
    @just --list

# Firmware sources the host checks format without building them.
fixture_sources := "fixtures/blink-esp-hal/src/main.rs fixtures/blink-esp-idf/src/main.rs fixtures/blink-esp-idf/build.rs fixtures/blink-avr/src/main.rs"

# --- Fixtures ------------------------------------------------------------
# The chip → target mapping lives in scripts/blink.sh.

# build and link the bare-metal esp-hal blink fixture for one chip: esp32 | s3 | c3 | c6
[group('fixtures')]
blink-hal chip:
    scripts/blink.sh hal "{{ chip }}"

# build and link the ESP-IDF (std) blink fixture for one chip: esp32 | s3 | c3 | c6 (slow on first run)
[group('fixtures')]
blink-idf chip:
    scripts/blink.sh idf "{{ chip }}"

# build and link the AVR blink fixture for the ATmega328P (pinned nightly from its rust-toolchain.toml, needs avr-gcc)
[group('fixtures')]
blink-avr:
    scripts/blink.sh avr atmega328p

# build every firmware fixture: 4 esp-hal chips, 4 ESP-IDF chips and AVR (slow)
[group('fixtures')]
blink-all:
    #!/usr/bin/env bash
    set -euo pipefail
    for chip in esp32 s3 c3 c6; do just blink-hal "$chip"; done
    for chip in esp32 s3 c3 c6; do just blink-idf "$chip"; done
    just blink-avr

# --- Code Quality ----------------------------------------------------------

# format the workspace and the firmware fixture sources (modifies files)
[group('quality')]
fmt:
    cargo fmt --all
    rustfmt --edition 2021 {{ fixture_sources }}

# --- CI ------------------------------------------------------------------
# Each GitHub Actions job runs exactly one ci-* recipe.

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
ci-setup-rust-just: && ci-clippy
    cargo fmt --version
    cargo clippy --version
    cargo deny --version
    cargo audit --version

# CI job: build one smoke-targets matrix entry: `hal <chip>`, `idf <chip>` or `avr atmega328p`
[group('ci')]
ci-blink runtime chip:
    scripts/blink.sh "{{ runtime }}" "{{ chip }}"

# run every host-smoke check locally: fmt, clippy, test, deny, audit (non-modifying)
[group('ci')]
ci: ci-fmt ci-clippy ci-test ci-deny ci-audit

# --- Maintenance ---------------------------------------------------------

# set up a fresh clone: stable rustfmt and clippy, the RISC-V esp-hal targets, the AVR nightly (idempotent)
[group('maintenance')]
setup:
    rustup component add --toolchain stable rustfmt clippy
    rustup target add --toolchain stable riscv32imc-unknown-none-elf riscv32imac-unknown-none-elf
    cd fixtures/blink-avr && rustup toolchain install

# report the tools the host checks and fixtures need (espup, ldproxy, avr-gcc, …), with the fix for each
[group('maintenance')]
doctor:
    scripts/doctor.sh

# remove build artifacts of the host workspace and the three firmware fixtures
[group('maintenance')]
clean:
    cargo clean
    cd fixtures/blink-esp-hal && cargo clean
    cd fixtures/blink-esp-idf && cargo clean
    cd fixtures/blink-avr && cargo clean

# --- act -----------------------------------------------------------------

# dry-run every workflow job with act (lists the 9 smoke-targets jobs and the host-smoke jobs)
[group('act')]
act-list:
    act -n --pull=false -P ubuntu-latest=catthehacker/ubuntu:act-latest -W .github/workflows/smoke-targets.yml
    act -n --pull=false -P ubuntu-latest=catthehacker/ubuntu:act-latest -W .github/workflows/host-smoke.yml --local-repository "datenkollektiv/rustyfarian-ci@v1={{ justfile_directory() }}"

# --- Release -------------------------------------------------------------

# tag origin/main as vX.Y.Z and move its major tag (`just release 1.1.0`); asks before pushing
[group('release')]
release version:
    scripts/release.sh "{{ version }}"
