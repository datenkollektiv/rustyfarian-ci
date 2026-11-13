# rustyfarian-ci

Shared GitHub Actions for the rustyfarian repos: a reusable host-checks workflow and composite setup actions.
Conventions live in [`CONVENTIONS.md`](CONVENTIONS.md).

## Contents

- `.github/workflows/host-checks.yml` — reusable workflow; runs one `just ci-<check>` recipe (`fmt`, `clippy`, `test`, `deny`, `audit`).
- `.github/actions/setup-rust-just` — composite action: Rust toolchain, cargo cache, `just`, optional cargo tools.

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

## License

MIT, see [`LICENSE`](LICENSE).
