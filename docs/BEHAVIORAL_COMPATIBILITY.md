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

## Fixture contract

Scenario inputs live in `core/src/test/resources/compat/scenarios.json` and have
`"schemaVersion": 1`. A scenario declares a stable ID, seed, built-in `trackId`, player car,
input origin, simulation tick count, sampling interval, and `inputSegments`. Segments are inclusive
tick ranges and contain only normalized `throttle`, `brake`, and `steering` values. The optional
`initialStates` block is a test-only API boundary for a fully specified starting state; it adds no
gameplay rules.

The long complete-race replay is stored in a separate input fixture,
`full-race-input.json`, and referenced by `inputScript`. This keeps a normal scenario readable
while retaining every player input needed to replay its full three-lap race from the start grid.
`inputOrigin` records whether the same normalized `PlayerInput` came from the keyboard-equivalent
or touch-equivalent adapter. The simulation itself receives the normalized command, never UI clicks.

`seed` is part of every input and output contract. The current reference has no externally seeded
random gameplay source: its AI pseudo-random state derives deterministically from its starting
state. Therefore the supplied seed is recorded and echoed but intentionally does not alter existing
Kotlin behaviour. A Dart adapter must accept and preserve it in exactly the same way unless a
separately versioned reference change introduces seeded randomness.

Golden traces are deliberately separate from inputs in
`core/src/test/resources/compat/goldens.json`; they also have `"schemaVersion": 1`. They are
checked in and are never updated by an ordinary test run. A trace records the countdown and racing
transition, its first physical tick, then periodic normalized snapshots. A failure reports the first
sampled tick and JSON field that differs.

All non-float state is exact: IDs, cars, phases, surfaces, AI states, ticks, ranking, checkpoints,
laps, finish state, and booleans. Float fields use an absolute tolerance of `0.0001`, implemented
by `BehavioralTraceJson.FLOAT_TOLERANCE`. The JSON writer normalizes floats to six decimal places.

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

1. Read the schema-1 scenario files as JSON; do not reinterpret UI-origin fields as screen events.
2. Initialize the requested track, car, seed, and optional initial state.
3. Reproduce the `COUNTDOWN` then `RACING` transition and apply one normalized input per fixed tick.
4. Emit the schema-1 snapshot fields in the same ordering and values, with the same six-decimal
   float normalization.
5. Compare the adapter's trace with the checked-in golden using exact discrete values and the
   documented float tolerance.

The public `BehavioralCompatibilityHarness` in `core` is the Kotlin implementation of this adapter
boundary. It is intentionally thin: session creation, optional state injection, fixed-step advance,
and observation only. It does not duplicate physics, collision, surface, race, or AI logic.
