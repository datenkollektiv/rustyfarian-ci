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

Xtensa toolchain pin for all repos: `1.97.0.0`.
Each repo moves to it when its cross-target workflow adopts the shared setup actions (knob: still `1.95.0.0`).
Keep the version in the toolchain cache key.

</details>

<details>
<summary>Composite actions</summary>

- `setup-rust-just`: Rust toolchain, `Swatinem/rust-cache`, `just`, optional cargo tools.
- rust-cache keys on the job id, and every job of a reusable workflow has the same id; pass `cache-key` so jobs don't overwrite each other's cache.
- `host-checks.yml` caches only `clippy` and `test`, keyed by the check; `fmt`, `deny` and `audit` compile nothing.
- `setup-esp-idf`: planned, extracted from rgb-clock.

`host-checks.yml` references `setup-rust-just` by full ref (`datenkollektiv/rustyfarian-ci/.github/actions/setup-rust-just@v1`).
A relative `./` path would resolve against the caller's checkout, not this repo.
A `v2` release therefore bumps that inner ref too.

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

Tag the release and move the major tag.

```sh
git tag v1.0.0
git tag -f v1
git push origin v1.0.0
git push -f origin v1
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
