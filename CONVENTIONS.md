# rustyfarian Conventions

Shared conventions for the rustyfarian repos: bench, knob, network, peripherals, power, rgb-clock, ws2812.
One file per topic under [`conventions/`](conventions/); the `family-resemblance` skill checks a repo against them (`/family-resemblance <topic>`).

| Topic | File | Covers | Check IDs |
|:------|:-----|:-------|:----------|
| `card` | [conventions/card.md](conventions/card.md) | README skeleton, banner, badges, Family diagram, dual licence, GitHub metadata | `C01`–`C23` |
| `ci` | [conventions/ci.md](conventions/ci.md) | GitHub Actions: thin callers, setup actions, pins, jobs, Dependabot | `A01`–`A20` |
| `just` | [conventions/just.md](conventions/just.md) | Recipe contract: gates, `ci-<job>`, `act`, device recipes, shared scripts | `J01`–`J25` |
| `bench` | [conventions/bench.md](conventions/bench.md) | Bench checks: board catalogue, pin, reject patterns, prompts, MACs, pass record | `B01`–`B16` |

- Each topic file carries `topic` and `version` frontmatter, a rules part, and a `## Checks` table (ID / Check / Applies to).
- Check IDs are stable and prefixed per topic, so a report row never names two rules.
- Change a rule in its topic file and bump that file's `version`; every repo picks it up on its next check.

How this repo itself is built, tested and released is in the [README](README.md).
