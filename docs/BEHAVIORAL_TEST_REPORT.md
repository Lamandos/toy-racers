# Behavioral Test Report

## Summary

Total scenarios: 113 versioned scenarios (50 legacy plus 63 file-per-scenario; the referenced `full-race-input.json` is an input script, not a scenario)
Passing: 113
Failing: 0
Long-running stress fixtures: 2 additional fixtures (1,000 and 5,000 physical ticks; excluded from the 63-scenario count)
Full-race scenarios: 11 (one legacy plus ten file-per-scenario three-lap races)
Fuzz scenarios: 100 generated 120-tick fixed-seed scenarios, each compared from the Kotlin oracle to Dart with the shared trace comparator
Determinism runs: Dart performs 20 repeated normalized-trace runs of the 5,000-tick scenario; both long-running Dart traces are compared to Kotlin, while the complete 115-fixture Kotlin inventory has a dedicated 20-run sequential release gate
Flaky tests: 0 observed; no retries or quarantines were used
Line coverage: 97.50% (2,028 / 2,080)
Branch coverage: 85.70% (863 / 1,007)
Mutation score: 73% (395 / 542 killed) for car physics, collision response, race rules, and surface speed

The scenario and golden-master results were collected with:

```sh
./gradlew behavioralTest fuzzSmokeTest dartStressDeterminismTest coverageReport mutationTest --no-daemon
```

Coverage is merged JaCoCo coverage for the configured portable `core` gameplay packages, unit tests, and behavioral
traces. The gate requires at least 85% overall Line and Branch coverage plus 90% Line coverage for each gameplay
package shown below. Scenario counts include both independently versioned fixture collections. The file-per-scenario
inventory contains 13 scenarios with at least 1,000 ticks; the exact-duration 1,000- and 5,000-tick stress fixtures
are additional resources under `core/src/test/resources/compat/stress`.

## Coverage by subsystem

| Subsystem | Scenarios | Line coverage | Notes |
|---|---:|---:|---|
| Car physics | 17 | 99.59% | Branch coverage: 90.14%; `car` package |
| Collision | 11 | 99.69% | Branch coverage: 83.04%; `collision` package |
| Race | 4 | 96.36% | Branch coverage: 82.22%; `race` package |
| Track | 9 | 96.97% | Branch coverage: 82.55%; `track` package |
| Surface | 5 | 100.00% | Branch coverage: 83.33%; `surface` package |
| AI | 7 | 98.95% | Branch coverage: 92.12%; `ai` package |
| Camera | — | 82.02% | Branch coverage: 55.00%; `camera` package; unit tests only |
| Input | — | 100.00% | Branch coverage: 83.33%; `PlayerControlConfig*` and `PlayerInput*`; unit tests only |

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

- Exact rendering and pixel output are not covered. GPU drivers, OpenGL implementations, fonts, window systems, and display scaling can change screenshots; screenshot goldens are intentionally not enabled.
- Real-device touch behavior, Android lifecycle behavior, frame pacing, memory use, and input timing still require a physical-device check.
- Audio playback, the audio fade before results navigation, and audio-device-specific behavior are outside the headless trace.
- Live render-delta accumulation and asynchronous input sampling are not represented by fixed-timestep scenario inputs.
- Non-default countdown durations and lap counts are not supported by the current `RaceSession` fixture boundary.
- A public immutable `RaceSession` snapshot is not available; accumulator remainder, next finish position, AI continuation state, and other mid-race continuation details cannot be restored and compared externally.
- `RaceStepResult` aggregates events and impact over an `advance` operation; ordered per-physical-step contact traces, especially AI track contacts, are not fully exposed by the current adapter.
- The 20-run full-inventory stability gate is intentionally a manual release check because it replays 4.3 million
  physical ticks. Reserve up to six hours for GitHub Actions, which exposes it through **Run workflow** with
  `run_behavioral_stability` enabled.

## Existing behavior anomalies

Golden masters intentionally preserve these current behaviors, which may be surprising or may become bug-fix candidates:

- The public scenario `seed` is recorded in traces but does not seed gameplay randomness. AI pseudo-random mistakes derive from initial state, so changing only the scenario seed does not change the replay. The Kotlin implementation remains the reference during migration.
- The race becomes `FINISHED` as soon as the player finishes, even when AI participants are still running. AI completion does not independently end the race. The Kotlin implementation remains the reference during migration.
- When the player finishes during an `advance` call, the accumulator is cleared and the loop stops. Any sub-tick remainder and additional whole ticks supplied by that same call are intentionally discarded; later requested samples keep the frozen finished state. The Kotlin implementation remains the reference during migration.
- `RaceStepResult.maxImpactSpeed` includes the player's track contacts and car contacts but excludes track contacts for AI cars, so it cannot always be recomputed as the maximum of the exposed contacts. The Kotlin implementation remains the reference during migration.
- A test-only explicitly seeded initial state may contain a speed component inconsistent with its emitted velocity. This is preserved as fixture behavior and is not produced by the normal constructor path. The Kotlin implementation remains the reference during migration.

This task records these anomalies only; it does not change or normalize them. Any later behavior change must be a separately reviewed change made in both implementations and their tests, with Kotlin remaining the reference during migration.
