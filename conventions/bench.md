---
topic: bench
version: 1.0.0
---

# Convention: Bench

Every bench consumer writes its hardware checks the same way, against one board catalogue, so a check reads the same in every repo and a board key means the same board everywhere.
Checked by the `family-resemblance` skill (`/family-resemblance bench`); this file is the single source of the rules.

The runner is [rustyfarian-bench](https://github.com/datenkollektiv/rustyfarian-bench); its README documents the TOML schema, step kinds and the remote bench.
This file adds the family rules on top.

## Who It Applies To

- A **consumer** is a repo with a `bench/` directory; every check applies to it.
- A rustyfarian repo without `bench/` has no bench yet: the checks do not apply, and *A First Bench* lists what one needs.
- `rustyfarian-bench` is the runner, not a consumer; this topic does not apply to it.

## Family Values

The skill's helper reads this block; change a value here and every repo is checked against the new one.

```toml
[family]
pin = "v0.5.0"                                    # rustyfarian-bench release every consumer pins
chip_tokens = ["c3", "c6", "s3", "esp32"]         # the only chip tokens in example names
example_name = '^[A-Za-z0-9][A-Za-z0-9_-]*$'      # remote runs reject anything else
reject_core = ['PANIC', 'panicked', 'Guru Meditation', 'abort\(\)', 'WDT']
reject_reboot = ['ESP-ROM:', 'rst:0x']
recipes = ["bench", "bench-list", "bench-detect"]

[catalogue.c3]
chip = "esp32c3"
board = "ESP32-C3 SuperMini"

[catalogue.c3-mini1]
chip = "esp32c3"
board = "ESP32-C3-DevKitM-1 (ESP32-C3-MINI-1)"

[catalogue.c6]
chip = "esp32c6"
board = "ESP32-C6-DevKitC-1"

[catalogue.s3]
chip = "esp32s3"
board = "CrowPanel 1.28\" HMI"

[catalogue.s3-heltec]
chip = "esp32s3"
board = "Heltec WiFi LoRa 32 V3"

[catalogue.esp32]
chip = "esp32"
board = "ESP32-WROOM-32 DevKit"

[catalogue.esp32-feather]
chip = "esp32"
board = "Adafruit ESP32 Feather V2"

[catalogue.avr]
chip = "atmega328p"
board = "Arduino Nano (ATmega328P)"
```

## Board Catalogue

- The keys above are the only board keys; the same key means the same physical board in every repo.
- A second board of a chip gets a suffix: `<key>-<board>` (`s3-heltec`, `esp32-feather`); add it to the catalogue first.
- A board's `name` starts with the catalogue board name; the repo's wiring may follow (`ESP32-C6-DevKitC-1, 12-LED ring on GPIO18`).
- One key names one board: "board A / board B" under one key is two catalogue entries.

## Pinning and Wiring

- Consumers pin the runner at the family `pin`, through `uvx --from git+…@<pin>` or a local checkout in `RUSTYFARIAN_BENCH`.
- The justfile carries `bench target *args`, `bench-list` and `bench-detect`; `just bench-list` loads every check strictly without hardware.
- An ADR "adopt rustyfarian-bench" (`docs/adr/NNN-adopt-rustyfarian-bench.md`) records why the repo uses it.
- `AGENTS.md` tells agents the bench exists and how to run it.

## Writing a Check

- Example names match `example_name`; a `+` breaks remote runs.
- A build variant rides on the example name after `--` (`hal_s3_deep_sleep_gpio--r2`), split off by the repo's `bench-build`/`bench-flash` recipes.
- Chip tokens in example names come from `chip_tokens` only (`hal_s3_join`, not `hal_esp32s3_join` or `hal_esp_join`).
- On ESP boards, every `reject` contains the `reject_core` alternatives, each as its own alternative (`TG1WDT_SYS_RST` is not `WDT`); steps may add their own before them.
- Non-ESP boards (AVR) print none of these markers; their rejects are their own.
- `duration` and `settle` windows also contain `reject_reboot`: a reboot is a failure there, not only a panic.
- A step that reads the boot banner (an attended step right after the reset) may leave out `reject_reboot`; say so in a comment.
- No step waits for Enter: every step without `confirm` sets `arm = false`, so the board's reaction is judged even when it comes before a keypress.
- One exception: a `reset = true` step may stay armed when the operator must be ready before the reset (a meter in place); a comment on the step says so.
- A check that publishes to a shared broker uses a private topic prefixed `bench-` (`bench-tick`).
- `say` is imperative for an action ("Press the button 3 times") and a statement for a judged fact ("The ring shows a rainbow").
- `confirm` is always a question ("Did the ring show a rainbow?").
- Remote-safe and local-only steps live in separate files: a file whose unattended steps include a `probe` or `run` (which the remote bench refuses) holds no other unattended steps the remote bench could run.
- A check that needs host-side `setup`/`teardown` (a broker) is local-only as a whole; that is not mixing.

## Boards, MACs and Results

- No `mac` in the committed `bench.toml`: results are git-ignored because they record MACs, so a committed MAC defeats that.
- A board that must be pinned by MAC is pinned in a git-ignored `bench.local.toml` once the runner supports it (open upstream request); until then the pin stays out of the repo.
- `bench/*/logs/` and `bench/*/results.jsonl` are git-ignored.

## Recording a Pass

`bench/README.md` carries the board table with a "Last full pass" column (power's form): one row per board, the date of its last full pass, or `open` before the first.
A full pass means `--unattended` and `--attended` both passed on that board.
A date records a run that happened; it is never written ahead of the run.

## A First Bench

A repo adopting the bench needs, in this order:

1. `bench/bench.toml` with `[commands]` `build` and `flash` and its boards as catalogue keys.
   `flash` passes `{port}` (an argument, or `env ESPFLASH_PORT={port}`) and opens no monitor.
   A repo with two firmware tiers dispatches by example name in one recipe pair (`bench-build`, `bench-flash`) or sets per-board `build`/`flash`.
2. One directory per board with its checks; integration apps start with a boot check and one check per user-visible behaviour.
3. `bench/README.md` with usage and the "Last full pass" table.
4. The justfile recipes and the family `pin`.
5. The `.gitignore` lines for logs and results.
6. The ADR and the `AGENTS.md` mention.

## Checks

| ID  | Check                                                                          | Applies to |
|:----|:-------------------------------------------------------------------------------|:-----------|
| B01 | The runner pin is the family `pin`                                             | consumer   |
| B02 | An ADR adopts rustyfarian-bench                                                | consumer   |
| B03 | `AGENTS.md` mentions the bench                                                 | consumer   |
| B04 | `bench/README.md` has a "Last full pass" column with a date per passed board   | consumer   |
| B05 | The justfile has `bench target *args`, `bench-list` and `bench-detect`         | consumer   |
| B06 | Every board key is a catalogue key with the catalogue `chip`                   | consumer   |
| B07 | Every board `name` starts with the catalogue board name                        | consumer   |
| B08 | No `mac` in the committed `bench.toml`                                         | consumer   |
| B09 | `bench/*/logs/` and `bench/*/results.jsonl` are git-ignored                    | consumer   |
| B10 | Example names match the family `example_name`                                  | consumer   |
| B11 | Chip tokens in example names are family `chip_tokens` only                     | consumer   |
| B12 | ESP boards: every `reject` has `reject_core`; windows have `reject_reboot`     | consumer   |
| B13 | Every step without `confirm` sets `arm = false` (commented `reset` steps excepted) | consumer |
| B14 | Every `confirm` is a question                                                  | consumer   |
| B15 | `say` is imperative for actions, a statement for judged facts (judged)         | consumer   |
| B16 | No check file mixes remote-safe and local-only steps                           | consumer   |

"consumer" means a repo with `bench/`; a repo without it reports "no bench/ yet" and *A First Bench*.
Check IDs are stable: retire an ID rather than renumber.
