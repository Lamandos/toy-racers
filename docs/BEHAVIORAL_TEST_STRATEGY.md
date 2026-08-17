# Behavioral test strategy

## Purpose and scope

This document defines a headless, reproducible way to compare the observable gameplay behaviour
of Toy Racers implementations. It is an audit of the current Kotlin reference as it exists in
`core`; it does not prescribe a rendering, audio, or input-device test.

The comparison boundary is a race simulation supplied with a fully specified track, race
configuration, initial state, and normalized commands. A fully specified track means the
canonical serialized `Track` definition, including both TMX-derived geometry and the values
hard-coded by `TrackLoader`. Its result is a sequence of normalized snapshots and discrete events.
The reference step is
`CarPhysics.FIXED_DELTA_SECONDS` (`1f / 60f`).

The following are deliberately out of scope: pixels, draw-call counts, camera interpolation and
shake, Scene2D animation, audio playback and fade completion, asset-loading progress, native
screen navigation, and performance telemetry. They can have platform-visible effects but do not
own gameplay rules.

## Architecture audit

`RaceScreen` is the presentation coordinator. It samples libGDX keyboard and touch state, clamps
the render delta, calls `RaceSession.advance`, and consumes simulation events for audio, camera,
HUD, and results navigation. It must not be the test boundary.

`RaceSession` is the correct simulation boundary. For every physical step it processes its fixed,
ordered pipeline:

1. Preserve the previous state for rendering and capture the last safe AI state.
2. Convert player input or AI output into `PlayerInput`.
3. Update the car with `CarPhysics`.
4. Resolve track collision, then apply `SurfaceSpeedSystem`.
5. Advance checkpoints, laps, times, and finish status with `RaceRules`.
6. Resolve car-to-car collisions in participant-list order.
7. Move `RaceState` to `FINISHED` when the player has finished.

The participant order is stable: player first, followed by `ai-0` through `ai-4` in start-grid
order. Collision pair order and same-tick finishing order are consequently part of the current
behavioural contract.

### Deterministic gameplay subsystems

| Subsystem | Current behaviour | Comparison treatment |
| --- | --- | --- |
| `CarState` | Mutable vehicle state: position, heading, velocity, angular velocity, lateral speed, and drift. | Include every field. |
| `PlayerInput` and `PlayerControlConfig` | `RaceSession` first applies the player's 0.85 steering scale; `CarPhysics` then clamps throttle/brake to `[0, 1]` and steering to `[-1, 1]` before physics. | Supply already-normalized scenario input; record the scaled command if comparing a session. |
| `CarPhysics` | Deterministic numerical integration, steering, grip, drift, and position update for an explicit delta. | Run only at the fixed delta. |
| `CollisionSystem` | Ordered, bounded circle/capsule contact resolution for boundaries, track objects, and cars. | Compare post-step state and collision event summary. |
| `SurfaceSpeedSystem` | Deterministically ramps the per-car speed multiplier and clamps velocity from the current surface. | Include surface and multiplier. |
| `Track`, checkpoints, and `TrackLoader` | Immutable geometry, ordered checkpoint gates, start line/grid, racing line, and surfaces. `TrackLoader` combines committed TMX bytes with hard-coded world, gate, grid, racing-line, and waypoint-radius data. | Pin `trackId`, raw TMX content hash, and canonical complete-`Track` definition hash. |
| `RaceRules` | Ordered forward gate crossing, lap timing, best lap, and sequential finish position assignment. | Include progress, finish data, and race result. |
| `RaceSession` | Fixed-step accumulator and stable update order across cars, AI, physics, collision, surface, and rules. | Call with controlled deltas only; disable timings. |
| `PositionTracker` | Total ordering by finish, lap, checkpoint, distance to next gate, then participant ID. | Include rank for every participant. |
| AI (`AiDriver`, path, obstacle, recovery) | Deterministic waypoint following, sensing, recovery, and pseudo-random mistakes. | Include AI command, behaviour, and waypoint index. |
| Race state machine and countdown | `LOADING → READY → COUNTDOWN → RACING`; `RACING ↔ PAUSED`; and `RACING → FINISHED`. `restart()` may reset any `RaceState` phase to `READY`, then `COUNTDOWN`. Countdown converts a supplied delta into simulation time. | Include phase and remaining countdown; version 1 excludes restart from the `RaceSession` operation set. |
| Finish and results | `RaceRules` creates finish state; `RaceScreen` derives a `RaceResult` after presentation-only audio fade-out. | Compare the core finish state/result, not the screen transition. |

`CarStateInterpolation` is explicitly display-only. Its previous state and interpolation alpha must
not be sent back to the simulation or included in a gameplay golden.

## Observable inputs

Every scenario must contain the following data; no value may be inherited from a device or the
host process:

- Schema and reference profile versions.
- A stable scenario ID and a `seed` field.
- Track ID, SHA-256 of the exact TMX/collision fixture, and SHA-256 of a canonical complete
  serialized `Track` definition. The canonical definition includes every `Track` field in a fixed
  field/list order: bounds, collision shapes, road contours, surfaces, start line, checkpoints,
  start grid, racing line, and racing-line waypoint radius. It therefore changes when either TMX
  data or `TrackLoader`'s hard-coded track definition changes. The profile version owns this UTF-8
  JSON representation; it uses stable field names and list order, and encodes every `Float` as its
  raw IEEE-754 bits in eight lowercase hexadecimal digits, so hashing cannot hide a geometry change
  through decimal rounding.
- Player car, ordered opponent cars, AI difficulty, required laps, countdown duration, and all
  non-default simulation configuration values. A schema may reference a versioned default profile
  only when its content hash is also recorded.
- The initial global state and an initial state for every participant. This includes the complete
  `CarState`, `SurfaceSpeedState`, and `RaceProgress` (including `lapStartTime`). It also includes
  the last-safe state for AI participants when respawn is enabled.
- An ordered stream of operations. Version 1 operations are `start`, `pause`, `resume`, and
  `advance`; `restart` is intentionally excluded because `RaceSession` does not expose it. It is
  tested directly as a `RaceState` state-machine concern. An `advance` operation contains a
  positive, explicit delta and a player command already within the `PlayerInput` ranges. Its
  command is held for every physical step produced by that call. The runner rejects out-of-range
  session commands rather than pre-clamping them; normalization-boundary behaviour belongs in
  focused `PlayerInput.normalized` tests. In the Kotlin session, the accepted command is scaled by
  `PlayerControlConfig` and is then normalized by `CarPhysics` immediately before physics.

The current Kotlin `RaceSession` always constructs `RaceState()` and `RaceRules(track)`. Until a
headless adapter injects `RaceState(countdownDurationSeconds)` and
`RaceRules(track, requiredLaps)`, version-1 Kotlin fixtures must require the current defaults of
three seconds and three laps, and reject other values. A later profile may support non-default
values only together with that adapter change and a version bump.

For portable goldens, normal racing should use one `advance` operation per fixed tick after the
countdown. A separate scenario should exercise countdown boundary handling with its exact supplied
deltas. UI events, screen coordinates, pointer IDs, and raw keyboard keys are not scenario inputs;
their adapters must first produce a `PlayerInput` command.

## Observable outputs and minimal state

The smallest useful behavioural observation is the post-operation gameplay state below. It
excludes only values that cannot influence a future simulation step and have no gameplay-facing
meaning (render interpolation, debug data, telemetry, audio, and UI state).

At each requested sample, emit:

- Global: operation number, cumulative fixed-step count, `RacePhase`, countdown remaining seconds,
  accumulator remainder, required laps, and the next finish-position counter.
- Per participant, sorted by stable `id`: car model, rank, all `CarState` fields, current surface,
  surface-speed multiplier, and all `RaceProgress` fields.
- For AI participants: `AiBehaviorState`, target waypoint index, and the normalized command emitted
  for that step. This catches divergence before a later car-state difference hides its cause.
- A trace entry for every physical step executed by an `advance` operation, in execution order.
  Each entry identifies its cumulative fixed tick and records checkpoint passage, maximum impact
  speed, and the ordered collision contact types/impact speeds. A trace is empty when an operation
  executes no physical steps. Emit a snapshot after every event-bearing entry, so an event remains
  attributable to its physical tick even when one `advance` executes several ticks.
- On `FINISHED`: a `RaceResult` projection containing player finish position, competitor count,
  total race time, and best lap time.

`lapStartTime` is required even though it is not normally shown in the HUD: it changes the next lap
time. The accumulator remainder changes how many physical steps the next `advance` executes, and
the next finish-position counter changes the next finisher's result, so both are required snapshot
fields. AI recovery timers, path-follower target, steering smoothing, mistake timers, and the LCG
state are not minimal *output* fields, but they are continuation state. A runner that supports
mid-race save/restore must serialize them, or only compare replay runs from tick zero.

## Snapshot schema

The following JSON-shaped schema is the recommended version-1 output. Fields ending in `?` are
omitted for player cars or absent values; they are not encoded as platform-specific sentinels.

```json
{
  "schemaVersion": 1,
  "scenarioId": "track-01-player-lap",
  "operation": 184,
  "fixedTicks": 184,
  "race": {
    "phase": "RACING",
    "countdownRemainingSeconds": 0.0,
    "accumulatorRemainderSeconds": 0.0,
    "requiredLaps": 3,
    "nextFinishPosition": 1
  },
  "steps": [
    {
      "fixedTick": 184,
      "playerCheckpointPassed": false,
      "maxImpactSpeed": 0.0,
      "contacts": []
    }
  ],
  "participants": [
    {
      "id": "player",
      "carModel": "RED_STRIPE",
      "rank": 1,
      "surface": "ASPHALT",
      "car": {
        "x": 49.5,
        "y": 15.6,
        "rotationDeg": 0.0,
        "speed": 0.0,
        "velocityX": 0.0,
        "velocityY": 0.0,
        "angularVelocity": 0.0,
        "lateralSpeed": 0.0,
        "driftAmount": 0.0
      },
      "surfaceSpeedMultiplier": 1.0,
      "progress": {
        "currentCheckpointIndex": 0,
        "completedLaps": 0,
        "lapStartTime": 0.0,
        "totalRaceTime": 0.0,
        "bestLapTime": null,
        "finished": false,
        "finishPosition": null
      }
    }
  ],
  "result": null
}
```

Snapshots are required immediately after each operation returns, after the first physical step,
after every event-bearing physical-step trace entry, and at a fixed interval (at most 60 physical
steps) during a long replay. `RaceSession.start()` reaches `READY` and starts `COUNTDOWN`
synchronously, so a session trace can observe only the resulting `COUNTDOWN` phase; focused
`RaceState` tests cover the intermediate `READY` transition. A scenario may sample every tick for a
focused physics or collision test.

## Scenario schema

Scenarios are committed JSON fixtures rather than recordings of a live screen. A compact form is:

```json
{
  "schemaVersion": 1,
  "referenceProfileVersion": 1,
  "id": "track-01-countdown-and-lap",
  "seed": 0,
  "track": {
    "id": "track-01",
    "tmxSha256": "<sha256>",
    "definitionSha256": "<sha256 of canonical complete Track>"
  },
  "configuration": {
    "countdownDurationSeconds": 3.0,
    "requiredLaps": 3,
    "playerCar": "RED_STRIPE",
    "opponentCars": ["BLUE_STRIPE", "YELLOW_SPORT", "GREEN_RACER", "ORANGE_TRUCK", "BLUE_STRIPE"],
    "aiDifficulty": "NORMAL",
    "profileSha256": "<sha256>"
  },
  "initialState": {
    "phase": "LOADING",
    "countdownRemainingSeconds": 3.0,
    "accumulatorRemainderSeconds": 0.0,
    "fixedTicks": 0,
    "nextFinishPosition": 1,
    "participants": ["<full continuation state per participant>"]
  },
  "operations": [
    { "type": "start" },
    { "type": "advance", "deltaSeconds": 0.016666667, "input": { "throttle": 0, "brake": 0, "steering": 0 } },
    { "type": "advance", "deltaSeconds": 0.016666667, "input": { "throttle": 1, "brake": 0, "steering": 0 } }
  ],
  "samples": { "everyFixedTicks": 60, "onEvents": true }
}
```

The test suite should include focused scenarios for normalization boundaries, acceleration/reverse,
drift, each wall/object/car collision rule, surface transitions, every checkpoint direction,
wrong-way crossings, lap/finish ordering, ranking ties, countdown/pause/resume, AI overtaking and
recovery, and a complete multi-car race on each built-in track.

## Nondeterminism and random audit

There is no use of `kotlin.random.Random`, `java.util.Random`, `MathUtils.random`, UUIDs, clocks,
threads, or unordered concurrent collections in the gameplay path.

The only random-like gameplay code is `AiDriver.randomState`. It is a private linear congruential
generator (`state = state * 1664525 + 1013904223`) used for periodic AI mistakes. Its initial value
is the XOR of the AI start position's float bits and its deterministic racing-line bias. It is
therefore reproducible for a fixed track, grid order, and configuration, but it is not presently
seeded from a public race seed. The `seed` field is retained in the scenario contract for forward
compatibility; changing it cannot currently change Kotlin behaviour. If seeding becomes public,
the seed-to-AI-state derivation must be specified and golden fixtures versioned.

Potential sources of variation that must be controlled are:

- Floating-point `sin`, `cos`, `atan2`, `sqrt`, and XML number parsing can differ by a small number
  of ULPs across runtimes. This is not an intentional random source.
- The exact TMX bytes and XML parser implementation define collision contour order and geometry.
  Fixture hashing prevents an asset update from looking like a simulation regression.
- Live input arrival is asynchronous and is sampled once per render frame. Normalized commands in
  a scenario remove this source.
- Participant and geometry lists are ordered today. Replacing them with unordered collections would
  change AI obstacle selection, contact resolution, same-tick finishes, and ties.

## Wall-clock and frame-delta audit

`System.nanoTime()` appears in optional performance measurement: `RaceSession` can report
collision duration when `measureTimings` is true, and `RaceScreen`/`RaceTelemetryRecorder` record
frame timings. `RaceSessionTest` also uses it only for a performance assertion, not a behavioural
assertion. These values are inherently nondeterministic and must be disabled and omitted from
goldens. `Gdx.graphics.framesPerSecond` and display refresh rate are likewise telemetry only.

The simulation has a deliberate dependency on caller-provided frame delta:

- `RaceScreen` receives libGDX's render `delta`, discards time beyond 0.25 seconds, and samples
  input once for that frame.
- `RaceState` spends the supplied delta on `COUNTDOWN`; only the remainder enters racing.
- `RaceSession` accumulates that remainder and runs zero or more 1/60-second physical steps. A
  command is reused for all steps generated by one call.
- `CarPhysics`, `SurfaceSpeedSystem`, `RaceRules`, and AI timers all consume the fixed physical
  delta when called by `RaceSession`.
- Camera, UI stages, loading animation, audio fade, and touch visual animation consume render
  delta but do not mutate gameplay state.

Consequently, comparing a real-time render trace at different frame rates is invalid. Replay tests
must drive the session directly with an explicit delta sequence, normally one fixed tick per call.
Countdown and accumulator-edge tests must record their exact delta sequence rather than infer it
from elapsed wall time.

## Headless constraints

The deterministic simulation packages (`car`, `collision`, `surface`, `track` geometry/loader,
`race`, and `ai`) do not import Android or libGDX APIs. `TrackLoader` uses classpath
`InputStream` and JAXP DOM parsing, so a headless runner needs the TMX assets on its test classpath
or must pass an explicit stream.

The following must be excluded from a headless runner: `RaceScreen` and other screens, renderers,
Scene2D UI stages, `KeyboardInputController`, `TouchInputController`, `GameAssets`, `GameAudio`,
`ToyRacersGame`, debug renderers, and the LWJGL/Android launchers. They read `Gdx` global state,
need graphics/audio/input devices, or use platform window lifecycle. `TouchInputController`'s
`MathUtils.clamp` is not random, but the controller itself is presentation-dependent.

`RaceSession` is currently `internal`, so the first headless implementation should live in the
`core` test source set or expose a deliberately small public adapter. Do not make render classes or
libGDX application globals part of that adapter.

## Normalization and tolerance

Before encoding or comparing a snapshot:

1. Reject `NaN` and infinite numeric values.
2. Validate that scenario session commands already satisfy the Kotlin `PlayerInput.normalized`
   ranges; reject invalid commands instead of altering them. The Kotlin session applies
   `PlayerControlConfig` before `CarPhysics` invokes `normalized()`.
3. Normalize rotations to `[0, 360)` degrees and normalize `-0.0` to `0.0`.
4. Sort participants by stable ID and contacts by the simulation's emitted order. Serialize enum
   names, booleans, IDs, integer counters, ranks, phases, and nullability exactly.
5. Encode finite floats with `Locale.ROOT` and six decimal places.

Compare discrete values exactly. For normalized floats use absolute tolerance `0.0001`; do not use
relative tolerance, because many important boundaries are near zero. Compare angles after circular
normalization, using the shortest signed angular difference. A failing comparator must report the
first operation/sample and JSON path that differs.

For same-runtime Kotlin goldens, also run each scenario twice and require byte-identical normalized
traces. Cross-runtime comparisons may apply the float tolerance after parsing, but must still
require exact discrete fields and fixture/profile hashes.

## Known limitations and follow-up work

- A public seeded-random contract does not exist yet; AI pseudo-random continuation state cannot be
  restored externally without an adapter change.
- A public immutable snapshot of `RaceSession` does not exist. The proposed schema is a test
  boundary, not a statement that all current fields are public API. A test-only accessor or small
  headless adapter must expose the accumulator remainder and `RaceRules` finish-position counter.
- `RaceStepResult` aggregates checkpoint passage and maximum impact across an `advance` operation
  and discards individual collision contacts. The headless adapter must expose an ordered
  per-physical-step trace before scenarios with multi-step advances or contact assertions are
  supported.
- The current `RaceSession` only supports the default countdown duration and lap count. Non-default
  configuration requires a deliberate adapter/session change before it may be accepted by fixtures.
- The current finish phase is player-centric: the race becomes `FINISHED` when the player finishes,
  even if opponents are still running. That is current behaviour and must be preserved unless a
  gameplay change is explicitly approved.
- `RaceScreen` waits for an audio fade before navigating to `ResultsScreen`. This delay and audio
  device behaviour are intentionally outside headless results comparison.
- Cross-language ports must match geometry parsing, Float/Double conversion, arithmetic order, and
  list order; tolerance can absorb small numerical drift but cannot repair a different algorithm.

Any intentional change to these contracts requires a schema/profile version bump, scenario update,
review of the normalized trace diff, and a documented gameplay reason. Golden files must never be
regenerated solely to hide a regression.
