---
topic: just
version: 1.0.0
---

# Convention: just Recipe Contract

Every rustyfarian repo exposes the same core recipes with the same meaning, so a human or an agent can switch repos without re-learning the task runner.
Checked by the `family-resemblance` skill (`/family-resemblance just`); this file is the single source of the rules.

Repo types (`library`, `firmware`, `python-tool`) and the `private` modifier are defined in [card.md](card.md#repo-types).
"Rust types" means `library` and `firmware`; the `private` modifier adds no `just` rules.

## Core Contract

| Recipe | Meaning |
|:-------|:--------|
| `_default` | First recipe, private: `@just --list` |
| `fmt` | Format the code (modifies files) |
| `fmt-check` | Check formatting without modifying files |
| `verify` | Read-only, offline, host-only gate; depends on `fmt-check` |
| `pre-commit` | Exactly `fmt` + `verify`; the only gate that modifies files |
| `deny` | `cargo deny check` (Rust types) |
| `ci` | `verify` + `deny`, then device checks |
| `ci-<job>` | One per GitHub Actions job; the job runs only this recipe |
| `act job=""` | Run CI jobs locally with act: all host jobs, or one |
| `setup [component]` | Install whatever a fresh clone is missing; idempotent |
| `doctor` | Report what is missing; changes nothing |

### Gates

- `verify` is read-only: nothing in its graph formats (`fmt`, a formatter without `--check`) or applies fixes (`--fix`).
- `verify` is offline: no `deny`, `audit`, `cargo fetch` or `cargo update` in its graph; the advisory database needs the network.
- `verify` is host-only: no `+esp`, no esp, ESP-IDF or AVR target; device checks have their own `verify-<tier>` gates.
- `verify` depends on `fmt-check`; it never inlines its own format check.
- `pre-commit: fmt verify` with an empty body, so the two cannot drift apart.
- `ci: verify deny` first; further dependencies are device checks only (`verify-fw`, `verify-hal`), never host checks `verify` already runs.

### CI Job Recipes

- Every workflow job has a `ci-<job>` recipe, named after the job id; caller jobs of `host-checks.yml` need `ci-<check>` (`ci-fmt`, `ci-clippy`, `ci-test`, `ci-deny`, `ci-audit`).
- A matrix job passes its axis as an argument (`just ci-idf "$CHIP"`).
- The workflows themselves follow [ci.md](ci.md).

### act

- Exactly one `act` recipe, with one parameter `job=""`; no `act-*` family.
- Empty `job` runs all host jobs; a job id runs that job.
- It runs the family image: `-P ubuntu-latest=catthehacker/ubuntu:act-latest`.
- A rustyfarian-ci act image replaces it once built; this line then changes, and every repo follows.
- It maps rustyfarian-ci when `RUSTYFARIAN_CI` points at a checkout: `--local-repository "datenkollektiv/rustyfarian-ci@v1=<abs path>"`.

### setup and doctor

- `setup [component]` installs toolchains and tools a fresh clone needs, idempotent; `component` selects a part (`esp`, `hal`, `avr`, `tools`).
- No `setup-*` siblings (`setup-toolchain`, `setup-avr`): they are components of `setup`.
- `doctor` reports what is missing and how to install it; it changes nothing.

## Structure

- Every public recipe carries a `[group('…')]`.
- At most one comment line sits directly above a recipe — the line `just --list` shows.
- Longer explanations stay as comments, and the listed text moves to `[doc('…')]`; `just` lists only the last comment line, so the line above it is easily mistaken for the doc.
- No two recipes with the same dependencies and body; keep one, rename callers.
- The host package list is defined once in one variable (`host_pkgs := "-p a -p b"` by convention; the name is free) and used everywhere; never repeat a literal `-p` list across recipes.

## Device Recipes

Repos with a `flash` recipe:

| Recipe | Meaning |
|:-------|:--------|
| `flash` | Build and flash; **never** opens a monitor (also not via `cargo run` and a `--monitor` runner) |
| `flash-*` | Tier and example variants (`flash-hal`, `flash-example`); like `flash`, never a monitor |
| `run` | `flash` + monitor: depends on or calls `flash`, then monitors |
| `run-*` | The monitoring twin of a `flash-*` recipe (`run-hal`) |
| `monitor` | Open the interactive serial monitor |
| `monitor-log file` | Headless serial capture into `file` (firmware repos); agents rely on this name |

- Chip selection is a recipe parameter named `chip` (`build-hal chip="c6":`, called as `just build-hal c3`), never one recipe per chip (`flash-hal-c3`).
- `ci-<job>` recipes named after a workflow job (`ci-c3`) are exempt; the job id decides their name.

## RAM Disk and Shared Scripts

- RAM-disk target dirs stay at `/Volumes/RustBuilds/targets/{idf,hal,avr}/<repo>`.
- Detect the RAM disk with `scripts/ramdisk-mounted.sh`, never `path_exists`: a stale `/Volumes/<name>` directory fools `path_exists`.
- Shared scripts are copied byte for byte from `rustyfarian-ci/scripts/`; a repo that has one keeps it identical:

| Script | Canonical |
|:-------|:----------|
| `scripts/host-target.sh` | yes |
| `scripts/ramdisk-mounted.sh` | yes (self-contained) |
| `scripts/ramdisk.sh` | yes (self-contained; `attach`, `detach`, `prune [days]`) |

- `doctor.sh` and `lib.sh` stay per repo.

## OTA

Repos with OTA recipes use these names:

| Recipe | Meaning |
|:-------|:--------|
| `ota-image` | Build the OTA image, hash it, write the manifest |
| `ota-push` | Publish the staged manifest as an OTA command |
| `ota-pub payload` | Publish a raw payload to the OTA command topic |
| `ota-rollback from` | Ask the device running `from` to roll back |
| `ota-serve` | Serve the OTA images over HTTP |
| `ota-status` | Follow the device's OTA status messages |

- Retired names: `ota-artifact`, `ota-cmd`, `ota-command`, `ota-sub`.
- Test-only extras (`ota-burst`, `ota-repair`, `ota-image-unhealthy`) may stay.

## MQTT

Repos that talk to a broker use network's recipe names:

| Recipe | Meaning |
|:-------|:--------|
| `mqtt-pub topic message` | Publish one message under the repo's topic prefix |
| `mqtt-watch` | Follow the repo's topics with timestamps |
| `mqtt-status` | Print the retained `status` value once |

- Extra arguments (`target=""`) and extras (`mqtt-burst`) are free.
- Bench checks publish to a private topic prefixed `bench-` (`bench-tick`), so a running publisher cannot interfere.

## Extensions

| Type | Recipes |
|:-----|:--------|
| `firmware` | `build`, `build-release` (never a bare `release`), plus the Device Recipes; a release-only firmware has `build` alone and says so in its doc |
| `library` | `semver`, `release-dry-run`, `release-publish`; per-crate variants add a suffix (`release-publish-hal`) |
| `python-tool` | `lint`, `typecheck`, `lock`; `verify: lint fmt-check typecheck test` |

## Renames

- Recipes are dev-only, not public API: renames are hard renames, without deprecation aliases.
- A rename updates every caller in the repo — workflows, `AGENTS.md`, `CLAUDE.md`, README, bench TOML — and adds one CHANGELOG line.

## Checks

| ID  | Check                                                                          | Applies to |
|:----|:-------------------------------------------------------------------------------|:-----------|
| J01 | `_default` is the first recipe, private, and runs `just --list`                | all        |
| J02 | `verify` depends on `fmt-check` and inlines no format check                    | all        |
| J03 | `verify`'s graph is read-only                                                  | all        |
| J04 | `verify`'s graph is offline and host-only                                      | all        |
| J05 | `pre-commit` is exactly `fmt verify` with an empty body                        | all        |
| J06 | `ci` is `verify deny`, followed only by device checks                          | Rust types |
| J07 | A `ci-<job>` recipe exists for every workflow job                              | all        |
| J08 | Exactly one `act` recipe, one `job=""` parameter, no `act-*`                   | all        |
| J09 | `act` runs the family image                                                    | all        |
| J10 | Every public recipe has a `[group]`                                            | all        |
| J11 | At most one comment line above a recipe; longer text uses `[doc]`              | all        |
| J12 | No duplicate recipes                                                           | all        |
| J13 | `setup [component]` installs what is missing; no `setup-*` siblings            | all        |
| J14 | Shared scripts are byte-identical to the rustyfarian-ci copies                 | Rust types |
| J15 | No `path_exists`; RAM-disk detection via `scripts/ramdisk-mounted.sh`          | Rust types |
| J16 | The host package list is defined once, not repeated as literal `-p` lists      | Rust types |
| J17 | `flash` and every `flash-*` recipe open no monitor                             | with flash |
| J18 | `run` reaches `flash` and a monitor                                            | with flash |
| J19 | `monitor-log file` exists                                                      | firmware   |
| J20 | Chip selection is a `chip` parameter; no recipe per chip                       | Rust types |
| J21 | OTA recipes use the contract names                                             | with OTA   |
| J22 | `build` + `build-release`, or a documented release-only `build`; no `release` | firmware   |
| J23 | `semver`, `release-dry-run` and `release-publish` exist                        | library    |
| J24 | `lint`, `typecheck`, `lock` exist; `verify` is `lint fmt-check typecheck test` | python-tool |
| J25 | MQTT recipes use the contract names                                            | with MQTT  |

"with flash" means repos with a `flash` recipe; "with OTA" means repos with any `ota-*` recipe; "with MQTT" means repos with any `mqtt-*` recipe.
Check IDs are stable: retire an ID rather than renumber.
