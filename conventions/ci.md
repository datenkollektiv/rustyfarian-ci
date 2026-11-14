---
topic: ci
version: 1.0.0
---

# Convention: CI

GitHub Actions in every rustyfarian repo look like eggs from the same hen.
The shared parts live in this repo; each family repo keeps thin callers.
Checked by the `family-resemblance` skill (`/family-resemblance ci`); this file is the single source of the rules.

Repo types (`library`, `firmware`, `python-tool`) and the `private` modifier are defined in [card.md](card.md#repo-types).
"Rust types" means `library` and `firmware`.

## Workflow Files and Names

File names and `name:` values are stable, because badge URLs depend on them.

| File | `name:` | Jobs (`just` recipe) |
|:-----|:--------|:---------------------|
| `rust.yml` | `CI` | `test` (`ci-test`), `deny` (`ci-deny`) |
| `fmt.yml` | `Format` | `fmt` (`ci-fmt`) |
| `clippy.yml` | `Clippy` | `clippy` (`ci-clippy`) |
| `audit.yml` | `Audit` | `audit` (`ci-audit`), plus a weekly `schedule` |
| `cross-target-<target>.yml` | free | per repo, see Cross-target Jobs |
| `codeql.yml` | free | public repos only |

- Rust types have exactly these four host workflows, plus any number of `cross-target-*.yml` and an optional `codeql.yml`.
- `rust.yml` may carry extra jobs (e.g. a firmware build); each follows the job rules below.
- `python-tool` repos keep their own workflow names; the job, pin and Dependabot rules still apply.

## Thin Callers

The four host workflows call the reusable `host-checks.yml` with one `check` input; it runs `just ci-<check>` on the stable toolchain.

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

- `check` is one of `fmt`, `clippy`, `test`, `deny`, `audit`; the workflow installs `rustfmt`, `clippy`, `cargo-deny` or `cargo-audit` as needed.
- Callers own triggers, `permissions: contents: read` and `concurrency` — every workflow, not only callers.
- `audit.yml` adds `schedule: - cron: "0 6 * * 1"`.
- A caller's `env:` does not reach a called workflow; pass the toolchain via the `toolchain` input (default `stable`), exported as `RUSTUP_TOOLCHAIN`.
- `host-checks.yml` takes `timeout-minutes` (default 20), because a `uses:` job cannot set it.
- In the Checks UI a called job shows as `<caller job> / <check>`, e.g. `fmt / fmt`.

## Cross-target Jobs

Cross-target workflows stay per repo — path filters, chips and AVR nightly differ — and share toolchain setup through the composite actions only.

```yaml
jobs:
  xtensa:
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v7
      - uses: datenkollektiv/rustyfarian-ci/.github/actions/setup-xtensa@v1
        with:
          version: ${{ env.XTENSA_VERSION }}
          buildtargets: esp32,esp32s3
      - uses: Swatinem/rust-cache@v2
        with:
          key: xtensa-${{ env.XTENSA_VERSION }}
      - uses: extractions/setup-just@v4
      - run: just ci-xtensa
```

| Action | For |
|:-------|:----|
| `setup-rust-just@v1` | stable or pinned rustup toolchain, cargo cache, `just`, cargo tools (RISC-V esp-hal) |
| `setup-xtensa@v1` | the `esp` toolchain; RISC-V ESP-IDF jobs pass `buildtargets: esp32` |
| `setup-esp-idf@v1` | `ldproxy`, the `~/.espressif` cache, `ESP_IDF_VERSION` / `MCU` env |
| `setup-avr@v1` | `avr-gcc` and the AVR nightly with `rust-src` |

- `setup-xtensa`, `setup-esp-idf` and `setup-avr` neither install `just` nor restore the cargo cache: add `extractions/setup-just` and `Swatinem/rust-cache` with a per-job `key`.
- rust-cache sees the default rustc, not the `esp` or AVR toolchain: put the toolchain version in the key (`env`, literal, or `hashFiles('rust-toolchain.toml')`).
- This holds for every job that builds for esp, ESP-IDF or AVR, whether it uses the setup actions yet or not.
- ESP-IDF jobs also put the IDF version and a hash of `sdkconfig.defaults` in the key; a restored CMake tree from another IDF version or sdkconfig fails to configure.
- Reference the actions by full ref, `datenkollektiv/rustyfarian-ci/.github/actions/<action>@v1`.

## Jobs and Recipes

- Every job that is not a `uses:` job has exactly one `run:` step: `just ci-<name>`, so local == CI.
- `codeql.yml` is exempt: its steps are all `uses:`, so it has no `run:` step.
- No `cargo`, `rustup` or install commands in YAML; setup goes through `uses:` steps.
- No `curl … | bash` or `| sh` installs anywhere; prebuilt tools come from `taiki-e/install-action`.
- Every non-`uses:` job sets `timeout-minutes`.
- The `ci-<name>` recipes themselves belong to the `just` topic.

## Path Filters

A workflow with a `paths:` filter must rebuild when the build recipe or the cargo config changes:

- `justfile` is always in the filter.
- `.cargo/config.toml` is in the filter whenever the repo has one.

## Pins and Versions

- Callers pin this repo by the moving major tag `@v1`; breaking changes go to `@v2`.
- Third-party actions are pinned by major tag and bumped by Dependabot.

| Action | Version |
|:-------|:--------|
| `actions/checkout` | `v7` |
| `actions/cache` | `v6` |
| `extractions/setup-just` | `v4` |
| `Swatinem/rust-cache` | `v2` |
| `taiki-e/install-action` | `v2` |

| Pin | Version |
|:----|:--------|
| Xtensa (`esp`) toolchain | `1.97.0.0` |
| ESP-IDF | `v6.1` |
| AVR nightly | `nightly-2025-04-27` |
| ldproxy | `0.3.2` (inside `setup-esp-idf`) |

- Set the Xtensa and ESP-IDF pins once per workflow as `env: XTENSA_VERSION` / `IDF_VERSION`.
- The AVR nightly in a workflow matches the `channel` of the AVR crate's `rust-toolchain.toml`.
- A repo moves to a new pin together with its cross-target workflow; until then the old pin is drift, reported as such.
- Not checked, but binding: never enable `defmt` features in an ESP-IDF build; its orphan sections break the link.

## Toolchain Pin

- A repo with a Dependabot `cargo` update has no root `rust-toolchain.toml` with `channel = "esp"`.
- Dependabot's cargo updater fails on every run against that channel, which rustup cannot install (network and power, seen 2026-11-14).
- Device builds select the toolchain per command instead: `cargo +esp …` in recipes, `setup-xtensa` in CI, as ws2812 and peripherals do.
- A pinned nightly (`channel = "nightly-…"`) installs fine and is not affected.

## Dependabot

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
    groups:
      github-actions:
        patterns: ["*"]

  - package-ecosystem: cargo        # `uv` in python-tool repos
    directory: "/"
    schedule:
      interval: weekly
    groups:
      esp-idf:
        patterns: ["esp-idf-*", "embuild"]   # esp-idf-sys is a `links` crate: move in lockstep
      cargo:
        patterns: ["*"]
```

- `github-actions` plus `cargo` (Rust types) or `uv` (`python-tool`), each weekly and grouped.
- No `rust-toolchain` ecosystem: it fails on `channel = "esp"` and nightly channels.
- Extra groups (e.g. `esp-hal`) and extra directories are free.

## CodeQL

- Public repos may run CodeQL; it is optional.
- Private repos do not: it needs paid GitHub Advanced Security.

## Required Status Checks

Called jobs report as `<caller job> / <check>` (`test / test`, `fmt / fmt`).
Branch rules that require a host check use those names, never the pre-migration job names.

## Testing Callers Locally

`act --local-repository` maps this repo's `@v1` to a local checkout, composite actions included; callers stay in their final form.

```bash
act -j fmt --pull=false -P ubuntu-latest=catthehacker/ubuntu:act-latest --local-repository datenkollektiv/rustyfarian-ci@v1=../rustyfarian-ci
```

Each repo wraps this in `just act job=""`, which applies the mapping when `RUSTYFARIAN_CI` points at a checkout.

## Checks

| ID  | Check                                                                         | Applies to |
|:----|:------------------------------------------------------------------------------|:-----------|
| A01 | The four host workflows exist with their file names and `name:`s              | Rust types |
| A02 | Their host jobs are thin callers of `host-checks.yml@v1` with the right check | Rust types |
| A03 | `audit.yml` has a weekly `schedule`                                           | Rust types |
| A04 | Every workflow sets `permissions: contents: read` and a cancelling group      | all        |
| A05 | Every other workflow is `cross-target-<target>.yml` or `codeql.yml`           | Rust types |
| A06 | Toolchain setup only through the `setup-*@v1` actions                         | Rust types |
| A07 | Xtensa, ESP-IDF and AVR pins match, wherever a workflow sets them             | Rust types |
| A08 | esp, IDF and AVR jobs key the cargo cache by toolchain (and IDF, sdkconfig)   | Rust types |
| A09 | Every non-`uses:` job outside `codeql.yml` has one `run:`, `just ci-<name>`   | all        |
| A10 | No `curl … \| bash` or `\| sh` anywhere in `.github/**`                       | all        |
| A11 | Every non-`uses:` job sets `timeout-minutes`                                  | all        |
| A12 | Every `paths:` filter has `justfile`, and `.cargo/config.toml` if it exists   | all        |
| A13 | Actions listed in the version table use that version                          | all        |
| A14 | rustyfarian-ci workflows and actions are referenced `@v1`                     | all        |
| A15 | Dependabot: `github-actions` + `cargo` (or `uv`), weekly, grouped             | all        |
| A16 | Dependabot has no `rust-toolchain` ecosystem                                  | all        |
| A17 | No CodeQL workflow                                                            | private    |
| A18 | Required status checks use the `<job> / <check>` names                        | all        |
| A19 | Every `just ci-<name>` a workflow calls exists in the justfile                | all        |
| A20 | No root `channel = "esp"` toolchain pin while Dependabot updates `cargo`      | Rust types |

"public" and "private" follow card.md; Check IDs are stable: retire an ID rather than renumber.
