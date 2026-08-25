# Behavioral Test Report

## Summary

Total scenarios: 63 (the referenced `full-race-input.json` is an input script, not a scenario)
Passing: 63
Failing: 0
Long-running scenarios: 2 (1,000 and 5,000 physical ticks)
Full-race scenarios: 10 (three-lap races)
Fuzz scenarios: 100 generated scenarios, 120 ticks each, fixed seeds
Determinism runs: 20 repeated normalized-trace runs of the 5,000-tick scenario; the 50 legacy scenarios also require a byte-identical second run
Flaky tests: 0 observed; no retries or quarantines were used
Line coverage: 93.70% (1,949 / 2,080)
Branch coverage: 67.13% (676 / 1,007)
Mutation score: Not measured; no mutation-testing tool or repository task is configured

The scenario and golden-master results were collected with:

```sh
./gradlew behavioralTest fuzzSmokeTest coverageReport --no-daemon
```

Coverage is JaCoCo coverage for the configured portable `core` gameplay packages and the regular JVM unit-test task. Scenario counts are taken from `compatibility/scenarios`, excluding the referenced input script.

## Coverage by subsystem

| Subsystem | Scenarios | Line coverage | Notes |
|---|---:|---:|---|
| Car physics | 17 | 98.78% | Branch coverage: 59.86%; `car` package |
| Collision | 11 | 82.04% | Branch coverage: 64.29%; `collision` package |
| Race | 4 | 95.44% | Branch coverage: 78.52%; `race` package |
| Track | 9 | 93.47% | Branch coverage: 61.32%; `track` package |
| Surface | 5 | 100.00% | Branch coverage: 60.00%; `surface` package |
| AI | 7 | 98.74% | Branch coverage: 72.12%; `ai` package |

## Behavioral coverage

| Behavior | Covered |
|---|---|
| Acceleration | yes |
| Braking | yes |
| Reverse | yes |
| Steering | yes |
| Drift | yes |
| Car collision | yes |
| Track collision | yes |
| Surface effects | yes |
| Checkpoints | yes |
| Laps | yes |
| Ranking | yes |
| Finish | yes |
| AI | yes |
| AI recovery | yes |
| Full race | yes |

## Known gaps

The following cannot currently be checked reliably by the automated headless behavioral suite:

- No Kotlin-versus-Dart/Flame differential run exists yet; fuzz currently exercises only the Kotlin reference simulation and checks invariants, not an independent implementation's output.
- Exact rendering and pixel output are not covered. GPU drivers, OpenGL implementations, fonts, window systems, and display scaling can change screenshots; screenshot goldens are intentionally not enabled.
- Real-device touch behavior, Android lifecycle behavior, frame pacing, memory use, and input timing still require a physical-device check.
- Audio playback, the audio fade before results navigation, and audio-device-specific behavior are outside the headless trace.
- Live render-delta accumulation and asynchronous input sampling are not represented by fixed-timestep scenario inputs.
- Non-default countdown durations and lap counts are not supported by the current `RaceSession` fixture boundary.
- A public immutable `RaceSession` snapshot is not available; accumulator remainder, next finish position, AI continuation state, and other mid-race continuation details cannot be restored and compared externally.
- `RaceStepResult` aggregates events and impact over an `advance` operation; ordered per-physical-step contact traces, especially AI track contacts, are not fully exposed by the current adapter.
- Mutation score is unavailable because mutation testing is not configured.

## Existing behavior anomalies

Golden masters intentionally preserve these current behaviors, which may be surprising or may become bug-fix candidates:

- The public scenario `seed` is recorded in traces but does not seed gameplay randomness. AI pseudo-random mistakes derive from initial state, so changing only the scenario seed does not change the replay.
- The race becomes `FINISHED` as soon as the player finishes, even when AI participants are still running. AI completion does not independently end the race.
- When the player finishes during an `advance` call, the accumulator is cleared and the loop stops. Any sub-tick remainder and additional whole ticks supplied by that same call are intentionally discarded; later requested samples keep the frozen finished state.
- `RaceStepResult.maxImpactSpeed` includes the player's track contacts and car contacts but excludes track contacts for AI cars, so it cannot always be recomputed as the maximum of the exposed contacts.
- A test-only explicitly seeded initial state may contain a speed component inconsistent with its emitted velocity. This is preserved as fixture behavior and is not produced by the normal constructor path.

