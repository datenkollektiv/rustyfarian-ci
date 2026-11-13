# rustyfarian Conventions

Shared conventions for the rustyfarian repos: bench, knob, network, peripherals, power, rgb-clock, ws2812.

## CI

GitHub Actions in every rustyfarian repo look like eggs from the same hen.
The shared parts live in this repo; each repo keeps thin callers.

<details>
<summary>Workflow files and names</summary>

Workflow file names and `name:` values are stable, because badge URLs depend on them.

| File | `name:` | Jobs (`just` recipe) |
|:-----|:--------|:---------------------|
| `rust.yml` | `CI` | `test` (`ci-test`), `deny` (`ci-deny`) |
| `fmt.yml` | `Format` | `fmt` (`ci-fmt`) |
| `clippy.yml` | `Clippy` | `clippy` (`ci-clippy`) |
| `audit.yml` | `Audit` | `audit` (`ci-audit`), plus a weekly `schedule` |
| `cross-target-<arch>.yml` | `Cross-target <Arch>` | per repo, see below |

Repos may add jobs, but each job still runs exactly one `just ci-<job>` recipe.

</details>

<details>
<summary>Thin callers</summary>

Host checks call the reusable workflow `host-checks.yml` with one `check` input.
It runs `just ci-<check>` on the stable toolchain.

```yaml
name: Format

on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: fmt-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  fmt:
    uses: datenkollektiv/rustyfarian-ci/.github/workflows/host-checks.yml@v1
    with:
      check: fmt
```

- `check` is one of `fmt`, `clippy`, `test`, `deny`, `audit`.
- The workflow installs `rustfmt` / `clippy` / `cargo-deny` / `cargo-audit` as the check needs.
- Callers own triggers, `permissions: contents: read` and `concurrency`.
- A caller's `env:` does not reach a called workflow; the toolchain is passed via the `toolchain` input (default `stable`) and exported as `RUSTUP_TOOLCHAIN`, which overrides an `esp` or nightly `rust-toolchain.toml`.
- In the Checks UI a called job shows as `<caller job> / <check>`, e.g. `fmt / fmt`.

</details>

<details>
<summary>Recipes and timeouts</summary>

- Every job runs exactly one `just ci-<job>` recipe, so local == CI.
- No raw `cargo` in YAML.
- Every job has `timeout-minutes`.
- A caller's `uses:` job cannot set it, so `host-checks.yml` takes a `timeout-minutes` input (default 20).
- Jobs that are not callers set `timeout-minutes` directly.

</details>

<details>
<summary>Pinning and versions</summary>

- Callers pin this repo by the moving major tag `@v1`.
- Fixes land everywhere without one PR per repo; breaking changes go to `@v2`.
- Third-party actions are pinned by major tag and bumped by Dependabot.

| Action | Version |
|:-------|:--------|
| `actions/checkout` | `v5` |
| `extractions/setup-just` | `v4` |
| `Swatinem/rust-cache` | `v2` |
| `taiki-e/install-action` | `v2` (cargo tools; no `cargo install` from source, no `curl \| bash`) |
| `dtolnay/rust-toolchain` | `master` with a `toolchain` input |
| `esp-rs/xtensa-toolchain` | `v1.7.0` |
| `actions/cache` | `v6` |

Xtensa toolchain pin for all repos: `1.97.0.0`.
Each repo moves to it when its cross-target workflow adopts the shared setup actions (knob: still `1.95.0.0`).
Keep the version in the toolchain cache key.

| Pin | Version |
|:----|:--------|
| ESP-IDF | `v6.1` (network, power, ws2812; knob still `v5.3.3`) |
| AVR nightly | `nightly-2025-04-27` |
| avr-hal (git) | `e5c8f37fe48419956e722490a82b9ca9b9fc61a2` |
| ldproxy | `0.3.2` |

Never enable `defmt` features in an ESP-IDF build; its orphan sections break the v5.3 link.

</details>

<details>
<summary>Composite actions</summary>

- `setup-rust-just`: Rust toolchain, `Swatinem/rust-cache`, `just`, optional cargo tools.
- rust-cache keys on the job id, and every job of a reusable workflow has the same id; pass `cache-key` so jobs don't overwrite each other's cache.
- `host-checks.yml` caches only `clippy` and `test`, keyed by the check; `fmt`, `deny` and `audit` compile nothing.
- `setup-xtensa`: the `esp` toolchain via `esp-rs/xtensa-toolchain`, cached under `~/.rustup/toolchains/esp` by version and `buildtargets`.
- espup installs the `esp` toolchain only for an Xtensa target, so RISC-V ESP-IDF jobs pass `buildtargets: esp32`.
- `setup-esp-idf`: pinned `ldproxy`, the `~/.espressif` cache keyed by IDF version and MCU, and `ESP_IDF_VERSION`, `ESP_IDF_TOOLS_INSTALL_DIR=global` and `MCU` in the job env.
- `setup-avr`: `avr-gcc`, `binutils-avr` and `avr-libc` from apt, plus the AVR nightly with `rust-src`.
- None of the three installs `just` or restores the cargo cache; the job adds `extractions/setup-just` and `Swatinem/rust-cache` with `workspaces` and a per-job `key`.

`host-checks.yml` references `setup-rust-just` by full ref (`datenkollektiv/rustyfarian-ci/.github/actions/setup-rust-just@v1`).
A relative `./` path would resolve against the caller's checkout, not this repo.
A `v2` release therefore bumps that inner ref too.
Family repos use the other actions the same way, e.g. `datenkollektiv/rustyfarian-ci/.github/actions/setup-xtensa@v1`.

</details>

<details>
<summary>Smoke fixtures</summary>

This repo tests its own actions on a "blink one LED" fixture that builds on every target in the family.

| Chip | esp-hal (`no_std`) | ESP-IDF (std) | LED |
|:-----|:-------------------|:--------------|:----|
| esp32 | `xtensa-esp32-none-elf` | `xtensa-esp32-espidf` | GPIO2 (ESP32 DevKit V1) |
| s3 | `xtensa-esp32s3-none-elf` | `xtensa-esp32s3-espidf` | GPIO35 (Heltec WiFi LoRa 32 V3) |
| c3 | `riscv32imc-unknown-none-elf` | `riscv32imc-esp-espidf` | GPIO7 (ESP32-C3-DevKit-RUST-1) |
| c6 | `riscv32imac-unknown-none-elf` | `riscv32imac-esp-espidf` | GPIO15 (Seeed XIAO ESP32C6) |
| atmega328p | `avr-none` (avr-hal) | n/a | D13 (Arduino Nano) |

- `fixtures/blink` is the only root workspace member: a host-tested `Blinker` over `embedded-hal` 1.0.
- `fixtures/blink-esp-hal`, `blink-esp-idf` and `blink-avr` are excluded from the root workspace and have their own `Cargo.lock` and `target/`.
- Toolchains: `esp` for Xtensa esp-hal and every ESP-IDF build, `stable` with the prebuilt rustup target for RISC-V esp-hal, the AVR nightly for AVR.
- `-Zbuild-std=core` for Xtensa esp-hal and AVR, `-Zbuild-std=std,panic_abort` for ESP-IDF.
- `smoke-targets.yml` runs one matrix job per row and runtime; each runs `just ci-blink <runtime> <chip>`.
- `host-smoke.yml` calls `host-checks.yml` for all five checks and runs `setup-rust-just` directly.
- Dependabot groups `esp-idf-*` with `embuild`, because `esp-idf-sys` is a `links` crate.

```sh
just blink-hal s3
just blink-idf c3
just blink-avr
just ci-blink hal c6
```

</details>

<details>
<summary>Cross-target, CodeQL and Dependabot</summary>

- Cross-target workflows (riscv, xtensa, avr) stay per repo; path filters, chips and AVR nightly differ.
- They share toolchain setup through composite actions only.
- CodeQL runs in public repos only; private repos would need GitHub Advanced Security.
- Every repo has `.github/dependabot.yml` with `github-actions` and `cargo` (`uv` in bench), weekly, grouped.

</details>

<details>
<summary>Releasing this repo</summary>

`host-checks.yml` resolves `setup-rust-just@v1` from GitHub, so the host-smoke `uses:` jobs test the published `v1`, not the PR's copy.
On a fresh remote, push `main` and the `v1` tag first; until then those five jobs fail at "Setup Rust and just".

Every release gets a new immutable `vX.Y.Z` tag and moves the major tag callers pin; never re-point a `vX.Y.Z` tag.
Patch for fixes, minor for new actions, inputs or changed defaults, a new major (`v2`) for breaking changes.
`just release` tags `origin/main` with both as annotated tags and pushes them after one confirmation.
It refuses a dirty tree, a branch other than `main`, a `main` that differs from `origin/main`, and an existing version tag.

```sh
just release 1.1.0
```

</details>

<details>
<summary>Testing callers locally</summary>

`act --local-repository` maps this repo's `@v1` to a local checkout, including the composite action referenced inside `host-checks.yml`.
Callers stay in their final form; no temporary `uses: ./` copy is needed.

```sh
act -j fmt --pull=false -P ubuntu-latest=catthehacker/ubuntu:act-latest --local-repository datenkollektiv/rustyfarian-ci@v1=../rustyfarian-ci
```

Each repo wraps this in `just act job=""`, which applies the mapping when `RUSTYFARIAN_CI` points at a checkout.

</details>
