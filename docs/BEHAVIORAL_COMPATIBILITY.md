# Behavioral compatibility suite

The Kotlin/libGDX core is the reference implementation for gameplay behaviour. The suite replays
versioned, normalized player input without libGDX rendering, a GPU, a window, or Android runtime.
It advances only the game's `CarPhysics.FIXED_DELTA_SECONDS` (`1/60` second); it never sleeps or
waits for wall-clock time.

Run the suite locally or in CI with one command:

```sh
./gradlew :core:behavioralCompatibilityTest --no-daemon
```

`qualityCheck`, used by the repository's CI workflow, also executes this test through `:core:test`.

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
output trace. It applies every requested tick even when the race has already finished; the game
then performs no more physical steps under its existing rules. Invalid options, files, schemas,
tracks, or output writes cause the task to fail with
a non-zero exit code.

## Fixture contract

Scenario inputs live in `core/src/test/resources/compat/scenarios.json` and have
`"schemaVersion": 1`. Their formal, machine-readable contract is
[`scenario.schema.json`](../core/src/main/resources/compat/scenario.schema.json), which uses JSON
Schema draft 2020-12. A scenario declares a stable ID, seed, built-in `trackId`, player car, input
origin, simulation tick count, sampling interval, and `inputSegments`. Segments are inclusive
one-based tick ranges. A range omits any control that should be zero and may span an arbitrary
number of simulation ticks. The optional `initialStates` block is a test-only API boundary for a
fully specified starting state; it adds no gameplay rules. Initial numeric values must be finite and
representable as Kotlin `Float`; `currentCheckpointIndex` is bounded by the selected track's
checkpoint count (3 for `track-01`, 5 for `track-02`), and `completedLaps` is bounded by the
reference race's three required laps. A finished initial state must provide `finishPosition` in the
range `1..6`, and `finishPosition` is only valid when `finished` is true.

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

`seed` is part of every input and output contract. The current reference has no externally seeded
random gameplay source: its AI pseudo-random state derives deterministically from its starting
state. Therefore the supplied seed is recorded and echoed but intentionally does not alter existing
Kotlin behaviour. A Dart adapter must accept and preserve it in exactly the same way unless a
separately versioned reference change introduces seeded randomness.

Golden traces are deliberately separate from inputs in
`core/src/test/resources/compat/goldens.json`; their trace envelope has `"schemaVersion": 2`.
They are checked in and are never updated by an ordinary test run. A trace records the countdown and
racing transition, its first physical tick, then periodic normalized snapshots. A failure reports the
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

Snapshot and golden-trace version 2 is intentionally incompatible with the earlier version-1
snapshot shape: participant fields were renamed or removed, and race-level progress and finish
fields were added. Version-1 consumers must migrate to version 2 or remain pinned to the earlier
reference commit; they must not parse version-2 data as version 1. Scenario and input-script
documents remain at schema version 1 because their input shape is unchanged.

All non-float state is exact. Float fields are finite, serialized as locale-independent fixed-point
values with six digits after the decimal point, and canonicalize negative zero to `0.000000`.
Comparisons accept an absolute tolerance of `0.0001`, implemented by
`BehavioralTraceJson.FLOAT_TOLERANCE`; this tolerance applies after parsing JSON and does not relax
discrete fields.

## Updating Kotlin reference goldens

Do not regenerate a golden to hide a gameplay change. First document the intended change or an
observed gameplay bug in a separate issue, then review the trace diff. To intentionally establish a
new Kotlin reference baseline, run:

```sh
./gradlew :core:behavioralCompatibilityTest -DupdateBehavioralGoldens=true --rerun-tasks --no-daemon
```

Commit the corresponding scenario and golden changes together. The normal task runs each scenario
twice and requires byte-identical normalized traces before comparing the checked-in golden.

## Dart/Flame adapter checklist

1. Validate and read schema-1 scenario files as JSON; do not reinterpret `inputOrigin` as screen
   events.
2. Initialize the requested track, car, seed, and optional initial state.
3. Reproduce the `countdown` then `racing` transition and apply one normalized input per fixed tick.
4. Emit the schema-2 snapshot fields in the schema's array order and values, with the same
   six-decimal float normalization.
5. Compare the adapter's trace with the checked-in golden using exact discrete values and the
   documented float tolerance.

The public `BehavioralCompatibilityHarness` in `core` is the Kotlin implementation of this adapter
boundary. It is intentionally thin: session creation, optional state injection, fixed-step advance,
and observation only. It does not duplicate physics, collision, surface, race, or AI logic.
