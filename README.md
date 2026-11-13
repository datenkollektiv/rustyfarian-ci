# rustyfarian-ci

Shared GitHub Actions for the rustyfarian repos: a reusable host-checks workflow and composite setup actions.
Conventions live in [`CONVENTIONS.md`](CONVENTIONS.md).

## Contents

- `.github/workflows/host-checks.yml` — reusable workflow; runs one `just ci-<check>` recipe (`fmt`, `clippy`, `test`, `deny`, `audit`).
- `.github/actions/setup-rust-just` — composite action: Rust toolchain, cargo cache, `just`, optional cargo tools.
- `.github/actions/setup-xtensa` — composite action: the `esp` toolchain via `esp-rs/xtensa-toolchain`, cached by version.
- `.github/actions/setup-esp-idf` — composite action: `ldproxy`, the `~/.espressif` cache and the esp-idf-sys environment.
- `.github/actions/setup-avr` — composite action: `avr-gcc` and the pinned AVR nightly.
- `.github/workflows/smoke-targets.yml` — builds the blink fixture on all 9 family targets (4 esp-hal, 4 ESP-IDF, AVR).
- `.github/workflows/host-smoke.yml` — calls `host-checks.yml` for all five checks and runs `setup-rust-just` directly.
- `fixtures/` — the blink smoke fixture: a host-tested `embedded-hal` library and one firmware crate per runtime.

## Usage

```yaml
jobs:
  clippy:
    uses: datenkollektiv/rustyfarian-ci/.github/workflows/host-checks.yml@v1
    with:
      check: clippy
```

The calling repo provides the `just ci-clippy` recipe.

## Local testing

Point `act` at a local checkout of this repo:

```sh
act -j clippy --pull=false -P ubuntu-latest=catthehacker/ubuntu:act-latest --local-repository datenkollektiv/rustyfarian-ci@v1=../rustyfarian-ci
```

## Smoke fixtures

The fixtures build locally with the same recipes CI runs.
The firmware recipes need espup (`esp` toolchain), `ldproxy` and `avr-gcc`; see [`CONVENTIONS.md`](CONVENTIONS.md).

```sh
just ci-fmt ci-clippy ci-test ci-deny ci-audit
just blink-hal s3
just blink-idf c6
just blink-avr
just act-list
```

## License

MIT, see [`LICENSE`](LICENSE).
