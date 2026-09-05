# Behavioral compatibility suite

The Kotlin/libGDX core is the reference implementation for gameplay behaviour. The suite replays
versioned, normalized player input without libGDX rendering, a GPU, a window, or Android runtime.
It advances only the game's `CarPhysics.FIXED_DELTA_SECONDS` (`1/60` second); it never sleeps or
waits for wall-clock time.

Run the primary behavioral suite locally with one command:

```sh
./gradlew behavioralTest --no-daemon
```

It verifies the versioned legacy fixture set, the file-per-scenario compatibility goldens, and the long-running
deterministic repeat test. GitHub Actions runs these mandatory checks in separate jobs; `qualityCheck`, used by the
pre-push hook, runs them together.

For release acceptance, run the full 115-fixture inventory twenty times sequentially:

```sh
./gradlew behavioralStabilityTest --no-daemon
```

This deliberately long task compares the canonical JSON trace of every legacy, file-per-scenario, full-race, and
long-running replay on every run. GitHub Actions exposes the same task through **Run workflow** with
`run_behavioral_stability` enabled.

## Repository golden masters

The file-per-scenario golden-master infrastructure lives in
[`compatibility/`](../compatibility/README.md). Its scenarios are grouped by gameplay area and each
one maps to a checked-in golden trace with the same relative path. The normal verification task is
read-only:

```sh
./gradlew verifyCompatibilityGoldens
```

Regenerate every checked-in behavioral golden master with the explicit maintenance task:

```sh
./gradlew regenerateBehaviorGolden --no-daemon
```

The file-per-scenario-only script remains available as
[`compatibility/tools/regenerate-goldens.sh`](../compatibility/tools/regenerate-goldens.sh). Both regeneration
commands are explicit maintenance operations; ordinary test runs do not modify checked-in fixtures. The rules for
when an update is acceptable are in the [compatibility README](../compatibility/README.md).

## Headless scenario runner

The `runBehaviorScenario` Gradle task replays exactly one scenario document through the existing
`RaceSession` simulation and writes its normalized trace. It creates no game, screen, renderer,
audio device, touch adapter, or window, so it works on a machine without a monitor or GPU.

```sh
./gradlew runBehaviorScenario \
  -Pscenario=compatibility/scenarios/car/straight_acceleration.json \
  -Poutput=build/behavior/actual.json
```

The task uses the repository root as its working directory. `scenario` must point to a
schema-versioned document containing exactly one scenario; any `inputScript` it references is
loaded from the same directory. The supplied seed is passed into the deterministic race
configuration and is recorded in the trace. The current game model has no externally seeded
random source, so the seed does not alter existing gameplay behaviour. Inputs are applied once per
inclusive, one-based simulation tick, and every physical step uses
`CarPhysics.FIXED_DELTA_SECONDS` (`1/60` second). Countdown and racing transition snapshots, the
first physical tick, each configured interval, the final tick, and a finish tick are saved in the
output trace. Scenarios tagged `state-machine` additionally sample `LOADING`, `READY`, and
intermediate countdown states before the `GO` transition. It applies every requested tick even
when the race has already finished; the game then performs no more physical steps under its
existing rules. Invalid options, files, schemas, tracks, or output writes cause the task to fail with
a non-zero exit code.

## Differential fuzz scenarios

`generateDifferentialFuzzScenario` creates a self-contained scenario for future Kotlin-versus-Dart
comparison. It accepts a signed 64-bit seed and a positive physical tick count. Supply `output` to
write the JSON file; without it, the generated document is printed to standard output.

```sh
./gradlew :core:generateDifferentialFuzzScenario \
  -Pseed=104729 \
  -Pticks=600 \
  -Poutput=build/differential-fuzz/seed-104729.json

./gradlew :core:runBehaviorScenario \
  -Pscenario=build/differential-fuzz/seed-104729.json \
  -Poutput=build/differential-fuzz/seed-104729-kotlin-trace.json
```

The generated document uses scenario schema v1, `track-01`, `red-stripe`, and the normal default
grid. It materializes one `inputSegments` entry per tick, so the JSON contains the complete control
stream and reproduces a failure even if the generator later changes. It deliberately does not rely
on the simulation's `seed` field to alter game behavior.

Generation is a language-neutral 32-bit LCG contract. Initialize `state` to the low 32 bits of the
signed seed XOR its high 32 bits. Before each command, replace it with
`(state * 1664525 + 1013904223) mod 2^32` and treat the result as an unsigned 32-bit value `u`.
For each tick, generate commands in the order throttle, brake, steering. Throttle and brake are
`(u mod 1000001) / 1000000`; steering is `(u mod 2000001 - 1000000) / 1000000`. JSON writes these
values with six decimal places, so all controls remain in the normalized ranges `[0, 1]`, `[0, 1]`,
and `[-1, 1]` respectively.

The fixed-seed fuzz smoke task runs 100 generated 120-tick scenarios through both implementations.
For every seed it writes the materialized `scenario.json` and Kotlin oracle trace to
`core/build/differential-fuzz/seed-<unsigned-seed>/kotlin.json`, then runs the same scenario with
the headless Dart runner. The existing Kotlin trace comparator checks the pair with the shared
contract and unchanged tolerances. Passing Dart traces are discarded; on any failure `dart.json`
remains beside the scenario and Kotlin trace for exact reproduction.

```sh
./gradlew fuzzSmokeTest --no-daemon
```

The command reports `100 / 100 PASS` only after every fixed seed matches. A mismatch reports the
signed seed, first divergent tick, field, expected value, actual value, and delta. GitHub Actions
runs it as the independently visible `dart-fuzz` stage on every normal workflow.

## Dart stress and determinism

The Kotlin-versus-Dart stress gate replays the two existing exact-duration
fixtures in `core/src/test/resources/compat/stress`: one 1,000-tick fixture and
one 5,000-tick fixture. It rejects NaN, Infinity, serialized negative zero,
invalid rotations, exploding velocity, corrupt race positions or ranking,
regressing progress, inconsistent finish ordering, and impossible lifecycle
states. The Dart runner produces the 5,000-tick normalized trace twenty times,
requires byte-for-byte equality and an identical FNV-1a-64 hash, then compares
the first output for each fixture against a trace newly replayed by the Kotlin
oracle with the existing comparator and unchanged tolerance.

```sh
./gradlew dartStressDeterminismTest --no-daemon
```

The successful result includes `Dart determinism: 20 / 20 identical` and
`Kotlin-vs-Dart stress: 2 / 2 PASS`. It is an explicitly long, manual release
check. GitHub Actions exposes it through **Run workflow** with
`run_dart_stress_determinism` enabled and uploads the Kotlin and Dart trace
artifacts for diagnosis.

## Fixture contract

Scenario inputs live in `core/src/test/resources/compat/scenarios.json` and have
`"schemaVersion": 1`. Their formal, machine-readable contract is
[`scenario.schema.json`](../core/src/main/resources/compat/scenario.schema.json); scenarios using
the v2 extension use [`scenario-v2.schema.json`](../core/src/main/resources/compat/scenario-v2.schema.json), and
scenarios seeding lap timers use [`scenario-v3.schema.json`](../core/src/main/resources/compat/scenario-v3.schema.json).
All use JSON Schema draft 2020-12. A scenario declares a stable ID, seed, built-in `trackId`, player car, input
origin, simulation tick count, sampling interval, and `inputSegments`. Segments are inclusive
one-based tick ranges. A range omits any control that should be zero and may span an arbitrary
number of simulation ticks. The optional `initialStates` block is a test-only API boundary for a
fully specified starting state; it adds no gameplay rules. Initial numeric values must be finite and
representable as Kotlin `Float`; `currentCheckpointIndex` is bounded by the selected track's
checkpoint count (3 for `track-01`, 5 for `track-02`), and `completedLaps` is bounded by the
reference race's three required laps. A finished initial state must provide `finishPosition` in the
range `1..6`, and `finishPosition` is only valid when `finished` is true. `totalRaceTime` may seed
the total race timer; v3 additionally permits `lapStartTime` and `bestLapTime`. When supplied,
`lapStartTime` must not exceed the effective `totalRaceTime` (zero when omitted).

The schema's identifiers are deliberately language-neutral: tracks are `track-01` and `track-02`,
while selectable cars are `red-stripe`, `blue-stripe`, `yellow-sport`, `green-racer`, and
`orange-truck`. Kotlin enum constant names are never input or output contract values. Scenario
inputs are normalized at the simulation boundary (`throttle` and `brake` to `0..1`, `steering` to
`-1..1`), so fixture values outside those ranges are permitted only to assert that boundary rule.
The current game model fixes the racers to `player` plus five deterministic AI opponents
(`ai-0` through `ai-4`); their observed snapshots are emitted as an ordered `participants` array
rather than serialized engine objects. The schema therefore supports targeting an initial state at
any current racer without inventing an unsupported custom grid.

The long complete-race replay is stored in a separate input fixture,
`full-race-input.json`, and referenced by `inputScript`. This keeps a normal scenario readable
while retaining every player input needed to replay its full three-lap race from the start grid.
Referenced scripts use the published [`input-script.schema.json`](../core/src/main/resources/compat/input-script.schema.json)
document shape: an object containing only `schemaVersion: 1` and a non-empty `segments` array.
The reference loader additionally requires every segment to satisfy
`1 <= fromTick <= toTick <= scenario.ticks`, and requires segments to be ordered and non-overlapping.
`inputOrigin` records whether the same normalized `PlayerInput` came from the keyboard-equivalent
or touch-equivalent adapter. The simulation itself receives the normalized command, never UI clicks.
The v2 `inputTweaks` array applies explicit additive control adjustments at listed simulation ticks
after the referenced script is loaded and before normalizing the command. It is intended for small,
reproducible scenario variations without duplicating a large input script; it is part of the effective
input and must be reproduced by another adapter.

`seed` is part of every input and output contract. The current reference has no externally seeded
random gameplay source: its AI pseudo-random state derives deterministically from its starting
state. Therefore the supplied seed is recorded and echoed but intentionally does not alter existing
Kotlin behaviour. A Dart adapter must accept and preserve it in exactly the same way unless a
separately versioned reference change introduces seeded randomness.

Golden traces are deliberately separate from inputs in
`core/src/test/resources/compat/goldens.json`; their trace envelope has `"schemaVersion": 3`.
They are checked in and are never updated by an ordinary test run. A trace records the countdown and
racing transition, its first physical tick, then periodic normalized snapshots; a `state-machine`
trace also records the loading and ready phases plus countdown progression. A failure reports the
first sampled tick and JSON field that differs.

## Normalized snapshot contract

[`snapshot.schema.json`](../core/src/main/resources/compat/snapshot.schema.json) is the formal,
machine-readable schema for a snapshot. Every snapshot includes `schemaVersion: 2`, the simulation
tick, race state, countdown state and remaining time, elapsed simulation time, and the player's
current lap/progress. Its participant records include only the stable ID and simulated equivalence
data: position, velocity, rotation, angular velocity, longitudinal and lateral speed, drift amount,
surface, checkpoint, completed lap, race position, and finish flag. The race-level `ranking`,
`finishedParticipants`, and `finishResults` capture the resulting order and completed timings.

Arrays have a fixed order: `participants` by ascending participant ID; `ranking` by race position
then ID; and finished IDs/results by finish position then ID. Snapshot output deliberately excludes
input metadata such as the seed, car selection, AI internals, collision diagnostics, runtime object
identifiers, memory addresses, FPS, rendering state, and platform metadata.

Snapshot version 2 and golden-trace version 3 are intentionally incompatible with the earlier
version-1 snapshot shape and version-2 trace envelope: participant fields were renamed or removed,
race-level progress and finish fields were added, and full-race traces now include checkpoint, lap,
and finish event labels. Consumers must migrate to snapshot version 2 and trace version 3 or remain
pinned to the earlier reference commit; they must not parse newer data as version 1 or 2. Scenario
documents without `inputTweaks` or lap timer seeds remain at schema version 1, and the strict v1
schema remains unchanged. Documents using `inputTweaks` declare schema version 2 and validate
against the v2 scenario schema. Documents that seed `lapStartTime` or `bestLapTime` declare schema
version 3 and validate against the v3 scenario schema; v3 also retains the v2 input-tweak contract.
Input-script documents remain at schema version 1. Consumers must opt in to the schema version
whose extensions they use.

All non-float state is exact: IDs, ticks, state/surface enums, checkpoints, laps, finish flags,
race positions, and every ordered array value must be identical. Float fields are finite,
serialized as locale-independent fixed-point values with six digits after the decimal point, and
canonicalize negative zero to `0.000000`.

`SnapshotComparisonEngine` applies the following absolute tolerance after parsing JSON. Relative
tolerance is deliberately disabled: the comparison must remain sensitive at important gameplay
boundaries near zero.

| Value type | Fields | Absolute tolerance | Comparison |
| --- | --- | ---: | --- |
| Position | `x`, `y` | `0.0001` world units | Numeric delta |
| Velocity | `velocityX`, `velocityY` | `0.0001` world units per second | Numeric delta |
| Rotation | `rotation` | `0.0001` degrees | Shortest circular delta across `0`/`360` |
| Angular velocity | `angularVelocity` | `0.0001` degrees per second | Numeric delta |
| Speed | `longitudinalSpeed`, `lateralSpeed` | `0.0001` world units per second | Numeric delta |
| Drift | `driftAmount` | `0.0001` | Numeric delta |
| Simulation time | `remainingSeconds`, `elapsedSimulationTime`, `bestLapTime` | `0.0001` seconds | Numeric delta |

`NaN`, positive infinity, and negative infinity are always mismatches, including when both files
contain the same non-finite value. The engine retains the first mismatching tick and participant,
prints a table of the mismatched fields with expected/actual values and deltas, then lists a small
number of following differences. This makes the same comparator suitable for checked-in Kotlin
goldens and a future Dart runtime's output files. It also rejects rotations outside the required
`[0, 360)` range and duplicate JSON object keys rather than normalizing ambiguous or invalid trace
output into a passing comparison.

## Updating behavioral goldens

Do not regenerate a golden to hide a gameplay change. First document the intended change or an observed gameplay bug
in a separate issue, then regenerate the checked-in behavioral goldens with:

```sh
./gradlew regenerateBehaviorGolden --no-daemon
```

This updates `core/src/test/resources/compat/goldens.json`, used by the 50 scenarios in
`core/src/test/resources/compat/scenarios.json`, and any out-of-date file-per-scenario fixtures. Review the complete
trace diff before committing it. The normal behavioral test suite is read-only: it runs each scenario twice and
requires byte-identical normalized traces before comparing checked-in fixtures.

## Dart/Flame adapter checklist

1. Validate and read schema-1 scenario files as JSON; do not reinterpret `inputOrigin` as screen
   events.
2. Initialize the requested track, car, seed, and optional initial state.
3. Reproduce the `countdown` then `racing` transition, apply any ordered `inputTweaks`, and normalize
   one input per fixed tick.
4. Emit the schema-2 snapshot fields in the schema's array order and values, with the same
   six-decimal float normalization.
5. Compare the adapter's trace with the checked-in golden using exact discrete values and the
   documented float tolerance.

The public `BehavioralCompatibilityHarness` in `core` is the Kotlin implementation of this adapter
boundary. It is intentionally thin: session creation, optional state injection, fixed-step advance,
and observation only. It does not duplicate physics, collision, surface, race, or AI logic.
