# Compatibility golden masters

This directory is the language-neutral behavioural contract for Toy Racers. The Kotlin/libGDX
core is the current reference implementation; a future Dart/Flame implementation must replay the
same scenario and produce a trace that a shared comparator can compare to the checked-in golden.
The contract covers deterministic gameplay state only. It deliberately excludes rendering, frame
rate, window size, device input events, audio, UI state, and platform metadata.

Kotlin and Dart runners may have different internal architecture. They must not have different
wire formats or comparison rules: scenario documents, snapshot documents, trace documents, and
comparator semantics in this directory are shared inputs to both runtimes.

## Layout

```
compatibility/
├── schemas/       Published JSON contracts for scenarios, scripts, snapshots, and traces
├── scenarios/     One scenario document per file, grouped by gameplay area
├── golden/        Checked-in golden trace with the same relative path as its scenario
└── tools/         Explicit maintenance commands
```

Scenario filenames are stable and use `snake_case`; their JSON `id` values are stable,
lowercase-kebab-case, and unique across every category. The path pairs input and expected output:
`scenarios/car/straight_acceleration.json` is compared with
`golden/car/straight_acceleration.json`. An `inputScript` lives next to its scenario and has no
golden of its own.

## Contract versions

Every producer and consumer must read `schemaVersion` before interpreting a document. Unknown
versions are errors; do not infer a newer layout from missing fields.

| Document | Current version | Canonical schema | Purpose |
| --- | ---: | --- | --- |
| Scenario | 1, 2, or 3 | [v1](schemas/scenario.schema.json), [v2](schemas/scenario-v2.schema.json), [v3](schemas/scenario-v3.schema.json) | Fixed-timestep replay input |
| Input script | 1 | [input-script.schema.json](schemas/input-script.schema.json) | Reusable input segments next to a scenario |
| Snapshot | 2 | [snapshot.schema.json](schemas/snapshot.schema.json) | One normalized race observation |
| Trace | 3 | [trace.schema.json](schemas/trace.schema.json) | Ordered samples for one scenario |

Scenario v1 is the base format. Version 2 adds `inputTweaks`; version 3 retains those tweaks and
adds `lapStartTime` and `bestLapTime` to optional initial states. A document must use the first
scenario version that supports the fields it contains. Input scripts remain at version 1. Snapshot
v2 and trace v3 replace earlier shapes; an adapter must not treat them as backward-compatible with
snapshot v1 or trace v2.

## Input

### Scenario JSON format

A scenario document is a JSON object with exactly `schemaVersion` and `scenarios`. The repository
stores one scenario per file, so the `scenarios` array must contain exactly one item when run by a
runner. For example:

```json
{
  "schemaVersion": 1,
  "scenarios": [
    {
      "id": "straight-acceleration",
      "seed": 42,
      "trackId": "track-01",
      "playerCar": "red-stripe",
      "inputOrigin": "keyboard",
      "tags": ["car", "physics", "throttle"],
      "ticks": 180,
      "snapshotIntervalTicks": 60,
      "inputSegments": [
        { "fromTick": 1, "toTick": 180, "throttle": 1 }
      ]
    }
  ]
}
```

Every scenario requires the following fields:

| Field | Contract |
| --- | --- |
| `id` | Lowercase kebab-case identifier: `^[a-z0-9]+(?:-[a-z0-9]+)*$`. |
| `seed` | Signed 64-bit integer, including its sign. It is copied to the trace exactly. |
| `trackId` | One of `track-01` or `track-02`. |
| `playerCar` | One of `red-stripe`, `blue-stripe`, `yellow-sport`, `green-racer`, or `orange-truck`. |
| `inputOrigin` | `keyboard` or `touch`. This is input provenance, not a request to synthesize keyboard keys, pointer coordinates, or UI events. |
| `tags` | Unique strings used to select fixture behaviour such as lifecycle or event snapshots. |
| `ticks` | Positive number of one-based physical simulation ticks, at most `2147483647`. |
| `snapshotIntervalTicks` | Positive sampling interval, at most `2147483647`. |
| `inputSegments` or `inputScript` | Exactly one source of normalized player commands. |

`initialStates` and `fullRace` are optional. An initial state can target `player` or `ai-0` through
`ai-4`; it may seed a car/race state before the first physical tick. Checkpoint indexes are bounded
by the selected track, completed laps are in `0..3`, `surfaceSpeedMultiplier` is in `[0, 1]`, and a
finished participant must provide a unique `finishPosition` in `1..6`. Version 3 additionally
permits `lapStartTime` and `bestLapTime`; all race times are non-negative and `lapStartTime` cannot
exceed `totalRaceTime`.

### Schema versions and seeds

The seed is part of scenario identity and trace identity, even though the present Kotlin gameplay
model has no externally seeded random source that changes a replay. A Dart runner must parse and
emit the signed 64-bit integer without IEEE-754 rounding, platform RNG substitution, or string
rewriting. If a later version makes a seeded decision observable, that decision must be specified
and versioned before either runner consumes the seed differently.

Scenario v2 and v3 may include sorted `inputTweaks`:

```json
"inputTweaks": [
  { "tick": 120, "steeringDelta": -0.25 }
]
```

Each tweak has a unique, strictly ascending `tick` in `1..ticks`. At that tick its supplied deltas
are added to the selected command before input normalization. Omitted delta fields are zero.

### Input ranges and segment rules

An inline `inputSegments` array, or the `segments` array in an input-script v1 file, contains one
or more inclusive tick ranges. `fromTick` and `toTick` are positive integers; every segment must
satisfy `1 <= fromTick <= toTick <= ticks`. Segments are sorted and cannot overlap. A tick outside
every segment receives a zero command.

`throttle`, `brake`, and `steering` are optional finite JSON numbers. Omitted controls are zero.
The raw document may deliberately use an out-of-range value to test normalization. For every tick,
the runner selects the segment, applies that tick's optional tweak, then normalizes exactly once:

| Control | Effective range |
| --- | --- |
| `throttle` | `[0, 1]` |
| `brake` | `[0, 1]` |
| `steering` | `[-1, 1]` |

Input scripts must validate against `input-script.schema.json`, be in the same directory as the
referencing scenario, and use a lowercase-hyphen filename matching
`[a-z0-9][a-z0-9-]*\.json`.

### Simulation tick semantics

The simulation is headless and fixed-step. It never waits for wall-clock time or depends on display
frames. Tick 0 is the pre-physics state; physical ticks are one-based and each uses exactly
`1 / 60` second. A tick's command is held for that one physics update only. The snapshot's
`simulationTick` counts completed physical updates, and its `elapsedSimulationTime` is
`simulationTick / 60` seconds.

The normal runner emits countdown and racing transition samples at trace tick 0, then applies input
for ticks `1..ticks`. It samples tick 1, every positive multiple of `snapshotIntervalTicks`, the
final requested tick, and the tick on which the race first finishes. Scenarios tagged
`state-machine` additionally emit loading, ready, and intermediate countdown samples at tick 0.
Scenarios tagged `event-snapshots` append `checkpoint`, `lap`, or `finish` samples after that
tick's normal `simulation` sample when the player's corresponding state changes. Sample order is
part of the trace contract.

## Output

### Trace and snapshot format

A runner writes one trace object, not a rendered result:

```json
{
  "schemaVersion": 3,
  "scenarioId": "straight-acceleration",
  "seed": 42,
  "samples": [
    {
      "label": "simulation",
      "tick": 1,
      "snapshot": {
        "schemaVersion": 2
      }
    }
  ]
}
```

`scenarioId` and `seed` must be the values from the input. Each sample has a label, its trace tick,
and one schema-v2 snapshot. Valid labels are `loading`, `ready`, `countdown`, `racing`,
`simulation`, `checkpoint`, `lap`, and `finish`.

Each complete snapshot has these race-level fields:

| Field | Semantics |
| --- | --- |
| `schemaVersion` | Always integer `2`. |
| `simulationTick` | Count of completed physical fixed steps. |
| `raceState` | `loading`, `ready`, `countdown`, `racing`, `paused`, or `finished`. |
| `countdown` | `state` is `not-started`, `active`, or `complete`; `remainingSeconds` is simulation seconds left in the countdown. |
| `elapsedSimulationTime` | Completed physical fixed-step time in seconds. Countdown-only samples remain at zero. |
| `currentLap` | Player's one-based active lap, capped at the required lap count after finishing. |
| `currentProgress` | Player's zero-based next checkpoint index and completed lap count. |
| `participants` | The complete normalized state of every participant. |
| `ranking` | Stable participant IDs in current race order. |
| `finishedParticipants` | Stable IDs of finishers. |
| `finishResults` | Timed result records for finishers. |

A participant contains `id`, `surface`, `x`, `y`, `rotation`, `velocityX`, `velocityY`,
`angularVelocity`, `longitudinalSpeed`, `lateralSpeed`, `driftAmount`, `checkpoint`, `lap`,
`racePosition`, and `finished`. `checkpoint` is the zero-based next checkpoint index; `lap` is the
number of completed laps. `racePosition` is one-based, while `finished` says whether the participant
has completed all required laps. `surface` is one of `asphalt`, `parquet`, `tile`, `grass`, `boost`,
or `oil`.

Each `finishResults` entry contains `participantId`, one-based `finishPosition`,
`elapsedSimulationTime`, and `bestLapTime`. `bestLapTime` is either a non-negative number of
seconds or `null` when the participant has not completed a lap time.

### Ordering and canonical JSON

JSON object member order is not semantically significant to the comparator, but producers should
write the canonical order in the schemas and Kotlin trace encoder. Missing fields, unexpected
fields, and duplicate keys are contract violations.

Arrays are semantic and must have the following exact order:

| Array | Required order |
| --- | --- |
| `samples` | Replay order described above; samples at the same tick keep their emitted label order. |
| `participants` | Ascending lexicographic participant ID (`ai-0` through `ai-4`, then `player`). |
| `ranking` | Ascending `racePosition`, then participant ID. |
| `finishedParticipants` | Ascending `finishPosition`, then participant ID. |
| `finishResults` | Ascending `finishPosition`, then `participantId`. |

All output numbers must be finite. Canonical output uses a period as decimal separator and six
digits after the decimal point for floating-point values. It writes zero as `0.000000`, never
`-0.000000`. This makes repeated runs reproducible; the cross-runtime comparator still compares
numeric values after parsing rather than comparing JSON text.

### Units, coordinate system, angles, and time

Positions are world units, independent of source image pixels and device pixels. The world origin
is the lower-left of the track bounds: positive X points right and positive Y points up. TMX source
coordinates with Y down are transformed into this world coordinate system before simulation.

`rotation` is degrees in `[0, 360)`: `0` faces positive X, `90` faces positive Y, and positive
angles rotate counter-clockwise. `angularVelocity` is degrees per second with the same sign. A
participant's forward axis is `(cos(rotation), sin(rotation))`; `longitudinalSpeed` is its velocity
projected on that axis, so positive values move forward and negative values reverse. The lateral
axis is `(-sin(rotation), cos(rotation))`; `lateralSpeed` is the velocity projected on that axis.
`velocityX` and `velocityY` are world units per second. `driftAmount` is a dimensionless value in
the simulation's normalized drift range `[0, 1]`.

All time fields are seconds. `remainingSeconds` measures countdown time; snapshot
`elapsedSimulationTime` measures completed physics time; result `elapsedSimulationTime` and
`bestLapTime` measure race progress time. Rendering time, wall-clock time, and frame deltas do not
belong in the trace.

## Comparison

The shared comparator parses both JSON traces and recursively compares the same structure. It must
validate the trace/snapshot versions, reject duplicate keys, and report a failure for missing or
unexpected fields, different JSON types, different array lengths, or changed array order.

### Exact fields

All discrete values compare exactly: schema versions, `scenarioId`, signed `seed`, sample labels and
ticks, `simulationTick`, state and surface enums, IDs, booleans, `null`, checkpoint/lap counters,
race and finish positions, and every array element/order. Numeric fields not listed below as
approximate must be JSON integers and compare exactly.

### Approximate fields and tolerance

The comparator uses absolute tolerance `0.0001` after parsing JSON. Relative tolerance is disabled
because important gameplay boundaries occur near zero.

| Value type | Fields | Unit | Comparison |
| --- | --- | --- | --- |
| Position | `x`, `y` | world units | Numeric delta |
| Velocity | `velocityX`, `velocityY` | world units per second | Numeric delta |
| Rotation | `rotation` | degrees | Shortest circular delta across `0`/`360` |
| Angular velocity | `angularVelocity` | degrees per second | Numeric delta |
| Speed | `longitudinalSpeed`, `lateralSpeed` | world units per second | Numeric delta |
| Drift | `driftAmount` | dimensionless | Numeric delta |
| Time | `remainingSeconds`, `elapsedSimulationTime`, `bestLapTime` | seconds | Numeric delta |

Both compared rotations must already be in `[0, 360)`. The angular delta wraps around the boundary,
so `359.99995` and `0.00000` can match within tolerance. `NaN`, positive infinity, negative
infinity, and negative zero are invalid rather than equivalent values. A mismatch report identifies
the first sample/tick, participant when available, field, expected value, actual value, and delta;
it may then show a bounded list of later differences.

## Dart/Flame integration contract

The Dart runner is a headless adapter, not a UI test. It must read a scenario from this repository,
load a neighboring input script when requested, apply the fixed-tick semantics above, and write a
single trace-v3 JSON file. It must not replace `inputOrigin` with Flutter pointer data, use a device
clock, sample frames, or include Flame/Flutter/runtime metadata in the output.

The required future command shape is:

```sh
dart run behavior_runner.dart \
  --scenario compatibility/scenarios/...json \
  --output actual-dart.json
```

For a concrete scenario, `...json` is replaced by its repository path, for example
`compatibility/scenarios/car/straight_acceleration.json`. The runner must preserve the scenario ID
and signed seed and produce the trace shape defined by `trace.schema.json` and
`snapshot.schema.json`.

The same language-neutral comparator interface must then compare a paired golden and actual trace:

```sh
compare \
  compatibility/golden/...json \
  actual-dart.json
```

The golden path must have the same relative category and basename as the input scenario. `compare`
is a contract for the common comparator CLI: its implementation may be Kotlin, Dart, or another
small portable tool, but its schema validation, ordered-array rules, exact fields, approximate
field list, angle handling, and `0.0001` tolerance must be the rules in this document. It must not
silently normalize malformed output into a passing result.

When the contract changes, update the affected JSON Schema, this README, the Kotlin reference
encoder/comparator tests, and the Dart adapter together. A behavior change that alters a golden
requires a reviewed scenario/golden update; ordinary verification must never rewrite golden files.

## Verification and regeneration

Normal tests only compare existing files; they never write a golden. Run the dedicated check with:

```sh
./gradlew verifyCompatibilityGoldens
```

Regeneration is deliberately a separate, explicit maintenance command:

```sh
./compatibility/tools/regenerate-goldens.sh
```

It runs the headless Kotlin reference simulation, rewrites only out-of-date goldens, and prints
every changed path. It fails if a golden has no matching scenario. Golden JSON files are versioned
repository inputs and must be committed with their scenario changes.

To regenerate this set together with the legacy behavioral golden master in
`core/src/test/resources/compat/goldens.json`, run:

```sh
./gradlew regenerateBehaviorGolden
```

Update a golden only after an intentional and reviewed change to the simulation contract, a
documented gameplay bug fix, or a new scenario. Do not regenerate a fixture merely to hide an
unexpected failure.
