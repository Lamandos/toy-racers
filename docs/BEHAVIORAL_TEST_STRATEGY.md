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

1. Preserve the previous state of every participant for rendering.
2. For each participant in stable participant-list order, capture its last safe AI state and convert
   player input or AI output into `PlayerInput` using the state already updated by earlier
   participants in this step.
3. Update that participant's car with `CarPhysics`.
4. Resolve that participant's track collision, then apply `SurfaceSpeedSystem`.
5. Advance that participant's checkpoints, laps, times, and finish status with `RaceRules`.
6. Resolve car-to-car collisions in participant-list order.
7. Move `RaceState` to `FINISHED` when the player has finished.

After step 6, the fixed tick is complete: increment the operation's physical-step count and
subtract one fixed delta from the accumulator. If the player finished during that tick, capture
every participant's resulting state for rendering, transition to `FINISHED`, set the accumulator
to exactly `0f`, and stop the `advance` loop. This deliberately discards both any sub-tick
remainder and every additional whole tick supplied by that `advance`; no later step from the same
operation is executed or emitted.

Steps 2–5 run to completion for one participant before beginning the next; all participant updates
finish before step 6. The participant order is stable: player first, followed by `ai-0` through
`ai-4` in start-grid order. Collision pair order and same-tick finishing order are consequently
part of the current behavioural contract.

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

- Schema and reference profile versions. `referenceProfileVersion: 1` selects the committed
  [`reference-profiles/v1.json`](reference-profiles/v1.json) file. Its SHA-256, calculated over
  the file's exact UTF-8 bytes, is required as `configuration.profileSha256`; a runner must reject
  a fixture if that hash does not match before applying any operation.
- A stable scenario ID and a `seed` field.
- Track ID, SHA-256 of the exact TMX/collision fixture, and SHA-256 of a canonical complete
  serialized `Track` definition. The canonical definition includes every `Track` field in a fixed
  field/list order: bounds, collision shapes, road contours, surfaces, start line, checkpoints,
  start grid, racing line, and racing-line waypoint radius. It therefore changes when either TMX
  data or `TrackLoader`'s hard-coded track definition changes. The version-1 UTF-8 representation
  is defined in [Reference profile and track-definition bytes](#reference-profile-and-track-definition-bytes):
  it uses stable field names and list order, and encodes every `Float` as its raw IEEE-754 bits in
  eight lowercase hexadecimal digits, so hashing cannot hide a geometry change through decimal
  rounding.
- Player car, ordered opponent cars, AI difficulty, required laps, and countdown duration. Version 1
  has a closed `configuration` object: it permits exactly the properties in
  [Scenario schema](#scenario-schema) and rejects unknown properties and configuration overrides.
  The selected profile is complete: it defines the base car, model-performance, collision, surface,
  player control, session, fixed-delta, and per-difficulty AI values. The track-specific AI
  waypoint-radius overlay is applied after the profile, as defined in [Reference profile and
  track-definition bytes](#reference-profile-and-track-definition-bytes). A fixture may not inherit
  a setting from source-code defaults or from the host process.
- Version 1 requires `configuration.aiDifficulty: "NORMAL"`. `AiDriver` applies
  `AiConfig.forDifficulty` internally, and `NORMAL` is the identity transformation; `EASY` and
  `HARD` are reserved for a later adapter/profile contract so an effective profile is not adjusted
  twice.
- The initial global state. Version 1 accepts only a constructor-derived fresh session: the phase
  must be `LOADING`, countdown and accumulator remainder must equal their profile defaults, and
  `fixedTicks` and `nextFinishPosition` must both be zero/one respectively. Its participants are
  derived from the selected `Track`, cars, and profile; a fixture may not supply restored
  participant state in version 1.
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
three seconds and three laps. A runner must reject a fixture whose
`configuration.countdownDurationSeconds` or `configuration.requiredLaps` differs from its selected
profile's defaults; it must not hash or execute such a configuration. A later profile may support
non-default values or a named nested override schema only together with that adapter change and a
version bump.

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
- Per participant, sorted by stable `id`: car model, rank, all `CarState` fields, the surface
  consumed by `SurfaceSpeedSystem`, surface-speed multiplier, and all `RaceProgress` fields. The
  consumed surface is sampled after that participant's track collision and before car-to-car
  collision resolution; it is not recomputed from the final post-collision position. It is `null`
  until that participant completes its first physical step, then retains the most recently
  consumed value across snapshots produced by operations with no physical step.
- For AI participants: `AiBehaviorState`, target waypoint index, and the normalized command emitted
  for that step, or `null` when the sample has no physical step. This catches divergence before a
  later car-state difference hides its cause.
- A trace entry for every physical step executed by an `advance` operation, in execution order.
  Each entry identifies its cumulative fixed tick and contains participant-tagged race-rule events
  and ordered collision contacts. A trace is empty when an operation executes no physical steps.
  Emit a snapshot after every event-bearing entry, so an event remains attributable to its physical
  tick even when one `advance` executes several ticks.
- On `FINISHED`: a `RaceResult` projection containing player finish position, competitor count,
  total race time, and best lap time.

`lapStartTime` is required even though it is not normally shown in the HUD: it changes the next lap
time. The accumulator remainder changes how many physical steps the next `advance` executes, and
the next finish-position counter changes the next finisher's result, so both are required snapshot
fields. AI recovery timers, path-follower target, steering smoothing, mistake timers, and the LCG
state are not minimal *output* fields, but they are continuation state. Version-1 fixtures only
compare replay runs from tick zero. A later version that supports mid-race save/restore must
serialize every participant continuation field and inject the accumulator remainder and
next-finish-position counter into the restored session.

## Snapshot schema

The following JSON-shaped schema is the recommended version-1 output. Fields named with `?` in the
rules after the example are optional and omitted when absent. Every other field is required; a
required field whose value is unavailable uses the JSON literal `null`, never an omitted property or
a platform-specific sentinel.

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
      "events": [],
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

The version-1 encoding rules are:

- `participants[].progress.bestLapTime`, `participants[].progress.finishPosition`, and `result`
  are required properties. They contain `null` until the corresponding value exists, then a number
  or result object as applicable.
- `participants[].surface` is a required `SurfaceType|null` property. It is `null` before that
  participant's first physical step, including the mandatory post-`start` snapshot, because
  `SurfaceSpeedSystem` has not consumed a surface. A runner must not synthesize it with
  `Track.surfaceAt`. After a physical step it contains the surface consumed by the participant's
  most recent `SurfaceSpeedSystem` update.
- `participants[].ai?` is omitted for the player and required for every AI participant. Its object
  is `{ "behaviorState": AiBehaviorState, "targetWaypointIndex": integer,
  "command": { "throttle": float, "brake": float, "steering": float } | null }`. `command` is
  the normalized command returned by that driver for the snapshot's just-completed fixed tick.
  When an `advance` executes several physical steps, use the command from the highest
  `fixedTick` included in that snapshot's `steps` prefix; for the final post-operation snapshot,
  this is the command from the operation's last executed physical step. It is `null` when the
  enclosing operation executed no physical step. A snapshot must not reuse a command from an
  earlier operation or step.
- Each `steps[]` entry is `{ "fixedTick": integer, "events": [event, ...],
  "maxImpactSpeed": float, "contacts": [contact, ...] }`. `event` is one of
  `{ "kind": "CHECKPOINT_PASSED", "participantId": string, "checkpointOrder": integer }`,
  `{ "kind": "LAP_COMPLETED", "participantId": string, "completedLaps": integer,
  "lapTimeSeconds": float, "bestLapTimeSeconds": float }`, or
  `{ "kind": "FINISHED", "participantId": string, "finishPosition": integer }`. Emit a
  `CHECKPOINT_PASSED` event when a gate is crossed; a start-line crossing emits
  `LAP_COMPLETED`, followed by `FINISHED` when that lap reaches the required count. Append events
  in participant-list execution order as each participant's `RaceRules.update` completes. Within
  one participant update, emit `LAP_COMPLETED` before `FINISHED`; no other pair of event kinds can
  be emitted by the same participant on one physical step. Do not sort the completed step's event
  array by kind or participant ID.
- Each `contact` is `{ "participantId": string, "otherParticipantId": string|null,
  "type": CollisionType, "normalX": float, "normalY": float, "penetration": float,
  "impactSpeed": float }`. Track contacts use `null` for `otherParticipantId`; car contacts use
  the other participant's stable ID. Contacts are appended in the exact order produced while
  resolving track contacts for each participant, then car-pair contacts in participant-list order.
  For a car pair `(first, second)` selected by increasing participant-list indices, emit exactly
  one contact with `participantId` equal to `first.id` and `otherParticipantId` equal to
  `second.id`. Its normal is the contact normal returned by `resolveCarCollision`: the negation of
  the separation normal from `first` toward `second`, so it points from `second` toward `first`.
  Do not emit a mirrored second contact.
- `steps[].maxImpactSpeed` is the maximum impact speed from the player's track contacts and every
  car-pair contact in that physical step. It intentionally excludes track contacts for AI cars,
  matching `RaceSession`; therefore it cannot in general be recomputed as the maximum of the
  emitted `contacts` array.
- A non-null `result` is `{ "finishPosition": integer, "competitorCount": integer,
  "totalRaceTime": float, "bestLapTime": float|null }`. It is the `RaceResult` projection used by
  this contract; omit the presentation/persistence-only `isNewRecord` source field.
- `AiBehaviorState` is exactly `FOLLOW_ROUTE`, `AVOID`, `OVERTAKE`, `RECOVER`, or `FINISHED`.
  `CollisionType` is exactly `WORLD_BOUNDARY`, `TRACK_OBJECT`, or `CAR`.
- No other property is optional. Empty collections are represented by `[]`, as shown for `steps`
  and collision `contacts`.

`operation` is one-based: `start`, the first item in `operations`, has operation number 1. A
physical step is also one-based: `fixedTick` and `fixedTicks` are 0 before the first step, then 1,
2, and so on. `fixedTicks` equals the `fixedTick` of the most recently completed physical step.
Snapshots are required immediately after each operation returns, after fixed tick 1, after every
event-bearing physical-step trace entry, and at the fixed-tick multiples selected by
`samples.everyFixedTicks`. Thus an interval of 60 samples ticks 60, 120, 180, and so on; it does
not use the first sample as its origin. When several rules request the same post-step state, emit
one snapshot. `steps` is an operation-local prefix: a snapshot after fixed tick `k` contains only
the entries through `k` from the current `advance`; the final post-operation snapshot contains the
complete trace for that operation. A snapshot before any physical step has `steps: []`. An adapter
that exposes intra-operation samples gives them the enclosing operation number and the just-completed
fixed tick. `RaceSession.start()` reaches `READY` and starts
`COUNTDOWN` synchronously, so a session trace can observe only the resulting `COUNTDOWN` phase;
focused `RaceState` tests cover the intermediate `READY` transition. A scenario may sample every
tick for a focused physics or collision test.

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
    "profileSha256": "86cecabf57030f9330148aa8276c9a0c9fff1686f6d5aa00c17b89842e5d5ddb"
  },
  "initialState": {
    "phase": "LOADING",
    "countdownRemainingSeconds": 3.0,
    "accumulatorRemainderSeconds": 0.0,
    "fixedTicks": 0,
    "nextFinishPosition": 1
  },
  "operations": [
    { "type": "start" },
    { "type": "advance", "deltaSeconds": 0.016666667, "input": { "throttle": 0, "brake": 0, "steering": 0 } },
    { "type": "advance", "deltaSeconds": 0.016666667, "input": { "throttle": 1, "brake": 0, "steering": 0 } }
  ],
  "samples": { "everyFixedTicks": 60, "onEvents": true }
}
```

Version-1 scenario values with `float` semantics, including `deltaSeconds`, player input,
configuration values, and initial-state floats, are parsed from their JSON decimal representation
and rounded to IEEE-754 binary32 with round-to-nearest, ties-to-even before validation or
execution. Integer counters remain JSON integers. The example's `0.016666667` therefore becomes
the same binary32 value as Kotlin's `1f / 60f`.

Validation must then reject any non-finite binary32 result before execution. This includes a JSON
decimal that is finite at the input boundary but overflows during conversion, such as `1e100`
becoming positive infinity. In particular, `deltaSeconds` must be finite after binary32 conversion
and strictly positive before it is added to the accumulator; reject it rather than entering the
fixed-step loop. The same post-conversion finiteness rule applies to every scenario float, including
negative overflow to negative infinity and values that convert to `NaN`.

After input conversion, all simulation state and scalar arithmetic must remain IEEE-754 binary32:
accumulator and countdown updates, physics, collision, surface, race-rule, and AI calculations
round to binary32 after each operation as Kotlin `Float` does. Runners must not retain values in
double precision, fuse operations, or use extended-precision registers when those choices can alter
a comparison or fixed-step count. The intentional transcendental boundary matches the Kotlin
reference: `sin`, `cos`, `atan2`, `toRadians`, and `toDegrees` are evaluated through their explicit
`Double` calls where the source converts to `Double`, retaining binary64 intermediates across a
composed expression until its final `.toFloat()` conversion. In particular, convert the Float
heading to binary64, apply `Math.toRadians`, and keep the result in binary64 through `sin`/`cos`,
rounding only those final trigonometric results to `Float`; for headings, keep the binary64 result
of `atan2` through `Math.toDegrees` and round only the resulting degrees to `Float`. Never round
an intermediate `toRadians`, `atan2`, or `toDegrees` result to `Float` before the next call.
`TrackLoader` has one additional geometry boundary for non-circular ellipses: with
`ELLIPSE_SEGMENTS = 24`, compute each angle in binary64 as the left-associated expression
`((Math.PI * 2.0) * index) / 24.0`, using the standard binary64 `Math.PI` constant. Evaluate
`sin(angle)` and `cos(angle)` in binary64, convert each result to `Float`, and only then perform
the Float radius and position arithmetic that produces the vertex. `CollisionSystem.outwardNormal`
has a separate double-precision boundary: each cross product is calculated as `Float`, converted
to `Double`, and then accumulated in the vertex-list order as a binary64 signed area. Its binary64
sign chooses the normal's orientation. Runners must preserve these explicit Float-rounding points,
the per-product rounding, and the ordered binary64 sum; they must not fuse the cross-product
expression or accumulate it as `Float`. These are the only permitted double-precision arithmetic
boundaries in the gameplay path.

The cross-runtime corpus must also be decision-stable around runtime math results. A fixture is
ineligible when a small difference in a rounded `sin`, `cos`, `atan2`, `sqrt`, or `hypot` result
can alter a discrete decision, such as an AI behavior, contact, event, finish state, or phase.
Before admitting a fixture, the Kotlin reference validator must model an additive error selected
independently from the closed interval `[-0.0001f, +0.0001f]` for every such rounded result that
contributes directly or through derived values to a predicate. This includes square-root-derived
distances and normalized vectors used by `RaceRules`, AI path/obstacle decisions, and collision
branches. The
validator must conservatively propagate the full Cartesian product of those independent closed
perturbation intervals through each affected predicate and prove that only the canonical Boolean
outcome is possible. Exhaustive replays of all independently signed endpoint combinations are an
acceptable equivalent; two uniform-sign replays or changing one result at a time are not. If the
validator cannot prove that every combination retains the canonical discrete trace, the fixture is
JVM-only until it is reframed away from the boundary or the contract specifies deterministic math.

The initial state above is an assertion of the fresh constructor-derived state, not a restore
payload. Version 1 requires exactly `LOADING`, profile-default countdown duration, zero accumulator
remainder, `fixedTicks: 0`, and `nextFinishPosition: 1`; runners derive participant state from the
track start grid and the configuration, then reject any extra initial participant data. Version 1
also requires `samples.onEvents: true`; a runner rejects `false` rather than silently changing the
mandatory event-snapshot rule.

The test suite should include focused scenarios for normalization boundaries, acceleration/reverse,
drift, each wall/object/car collision rule, surface transitions, every checkpoint direction,
wrong-way crossings, lap/finish ordering, ranking ties, countdown/pause/resume, AI overtaking and
recovery, and a complete multi-car race on each built-in track.

## Nondeterminism and random audit

There is no use of `kotlin.random.Random`, `java.util.Random`, `MathUtils.random`, UUIDs, clocks,
threads, or unordered concurrent collections in the gameplay path.

The only random-like gameplay code is `AiDriver.randomState`. It is a private 32-bit linear
congruential generator used for periodic AI mistakes. Its initial signed 32-bit state is exactly
`initialPosition.x.toBits() xor initialPosition.y.toBits() xor racingLineBias.toBits()`, where each
operand is the raw IEEE-754 binary32 bit pattern interpreted as a signed Kotlin `Int`. Each
check replaces it with `(state * 1664525 + 1013904223) mod 2^32`, using two's-complement wraparound.
The sample is the upper 24 bits interpreted as an unsigned integer, divided by `2^24`: in Kotlin,
`(state ushr 8).toFloat() / 0x01000000`. A non-JVM implementation must use these state width,
wraparound, unsigned-shift, and conversion rules rather than its native integer-overflow defaults.
It is therefore reproducible for a fixed track, grid order, and configuration, but it is not
presently seeded from a public race seed. The `seed` field is retained in the scenario contract for
forward compatibility; changing it cannot currently change Kotlin behaviour. If seeding becomes
public, the seed-to-AI-state derivation must be specified and golden fixtures versioned.

Potential sources of variation that must be controlled are:

- Floating-point `sin`, `cos`, `atan2`, `sqrt`, `hypot`, and XML number parsing can differ by a
  small number of ULPs across runtimes. This is not an intentional random source.
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

## Reference profile and track-definition bytes

`reference-profiles/v1.json` is the version-1 default simulation profile. Version 1 scenarios select
`NORMAL` difficulty only: this is the identity path through `AiConfig.forDifficulty`. It is an ordinary
committed UTF-8 JSON file, with no BOM and a terminating newline. Its property order and the
literal bytes in Git are normative; `profileSha256` hashes those bytes, including the newline. A
string in a field documented as `float32` is the eight lowercase hexadecimal digits of the
IEEE-754 binary32 bit pattern, most-significant byte first. `"3f800000"`, for example, is `1f`.
All other numbers in that file are JSON integers. The `aiByDifficulty` objects are already the
effective configurations after Kotlin's `AiConfig.forDifficulty`; do not apply that transformation
again. When creating an `AiDriver`, Kotlin then applies a separate track overlay:
`waypointRadius` is replaced by `Track.racingLineWaypointRadius`. Thus the profile's
`aiByDifficulty.*.waypointRadius` is a base value, while the complete `Track` definition supplies
the effective value (`10f` for track 01 and `7f` for track 02); runners must apply this overlay in
that order. A later profile must be a new file and version, never an edit that changes v1's bytes.

For each selected car model, derive its effective `CarConfig` from `baseCarConfig` by multiplying
only these three fields, with binary32 rounding after each multiplication:
`acceleration *= modelPerformance[model].acceleration`,
`maxForwardSpeed *= modelPerformance[model].maxSpeed`, and
`steeringSpeed *= modelPerformance[model].handling`. Copy every other `baseCarConfig` field
unchanged; in particular, do not scale braking, reverse acceleration/speed, grip, drift, size, or
collision fields. For opponent index `i` in the ordered `ai-0` through `ai-4` list, select
`opponentRacingLineBiases[i % opponentRacingLineBiases.length]`. With the version-1 list this yields
`[-0.65f, 0f, 0.65f, -0.65f, 0f]`; zipping, clamping, or redistributing the list is invalid.

`Track.definitionSha256` is calculated from a separate canonical byte sequence, not from a
platform JSON serializer. The encoder writes a single minified UTF-8 JSON value with no BOM, no
whitespace, and no final newline. JSON strings use these exact rules: `"`, `\\`, `\b`, `\t`, `\n`,
`\f`, and `\r` use their short escapes; a remaining U+0000--U+001F code point uses lowercase
`\u00xx`; every other code point is emitted directly as UTF-8. `float32` leaves are JSON strings
using the eight-digit encoding above, integer leaves use base-10 with no leading zero, enum leaves
are their Kotlin enum names, and a missing road contour is the literal `null`.

The top-level fields, in this exact order, are `id`, `name`, `worldBounds`, `cameraBounds`,
`outerBoundary`, `innerObstacles`, `collisionShapes`, `backgroundSurface`, `surfaceRegions`,
`roadOuter`, `roadInner`, `startLine`, `checkpoints`, `startGrid`, `racingLine`, and
`racingLineWaypointRadius`. Their exact object forms and field orders are:

```text
point        = {"x":float32,"y":float32}
rectangle    = {"x":float32,"y":float32,"width":float32,"height":float32}
segment      = {"start":point,"end":point}
circle       = {"kind":"CIRCLE","center":point,"radius":float32}
polygon      = {"kind":"POLYGON","vertices":[point,...]}
surface      = {"bounds":rectangle,"surface":SurfaceType}
startLine    = {"bounds":rectangle,"forwardX":float32,"forwardY":float32}
checkpoint   = {"order":integer,"gate":segment,"forwardX":float32,"forwardY":float32}
startGrid    = {"position":point,"rotationDeg":float32}
track        = {"id":string,"name":string,"worldBounds":rectangle,
                "cameraBounds":rectangle,"outerBoundary":rectangle,
                "innerObstacles":[rectangle,...],"collisionShapes":[circle|polygon,...],
                "backgroundSurface":SurfaceType,"surfaceRegions":[surface,...],
                "roadOuter":polygon|null,"roadInner":polygon|null,"startLine":startLine,
                "checkpoints":[checkpoint,...],"startGrid":[startGrid,...],
                "racingLine":[point,...],"racingLineWaypointRadius":float32}
```

`SurfaceType` is exactly one of `ASPHALT`, `PARQUET`, `TILE`, `GRASS`, `BOOST`, or `OIL`.
For version 1, the normative `isRoad` mapping is `ASPHALT`, `BOOST`, and `OIL` → `true`,
and `PARQUET`, `TILE`, and `GRASS` → `false`. Runners must use this mapping for both the
`SurfaceSpeedSystem` speed multiplier and AI recovery/safe-state decisions; they must not infer
road status from the enum name, track geometry, or display styling.
Arrays retain the current `Track` list order exactly; no sorting, deduplication, omission of empty
arrays, coordinate rounding, or normalization is permitted. `definitionSha256` is the lowercase
hex SHA-256 of the resulting bytes. This definition covers both TMX-derived values and every value
that `TrackLoader` supplies in Kotlin.

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
