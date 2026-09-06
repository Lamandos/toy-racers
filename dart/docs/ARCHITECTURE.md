# Dart architecture

The Dart implementation keeps deterministic gameplay separate from Flutter and
Flame presentation. Kotlin/libGDX remains the behavioral reference; the
headless compatibility runners compare Dart output with the shared Kotlin
goldens.

## Layering

```text
Flutter screens and overlays
          |
          v
Flame game, components, camera, input and audio adapters
          |
          v
Pure-Dart simulation: RaceSession, physics, collision, track, AI and rules
          |
          v
Compatibility snapshots and canonical JSON traces
```

`lib/simulation/` is portable Dart. It must not import Flutter, Flame, or
`dart:ui`, and it owns no wall-clock or render-loop state. `RaceSession` owns
the race lifecycle, participant state, fixed-step updates, physics, collision,
surface effects, AI, checkpoints, laps, finishing, and deterministic snapshots.
`Float32` deliberately narrows arithmetic at reference-compatible boundaries.

`lib/game/`, `lib/audio/`, and `lib/main.dart` are presentation code. They may
depend on Flutter and Flame, but copy observations from simulation rather than
changing simulation state outside its public commands.

## Fixed timestep and input flow

Flame calls `ToyRacersGame.update` with a variable render delta.
`FixedTimestepScheduler` caps and accumulates that delta, then invokes
`RaceSession.advanceFixedStep()` in chronological order at the reference
`1 / 60` interval. The retained remainder is added to the next render delta and
therefore schedules later fixed ticks; it also yields the interpolation factor
for visual components. Pause, finish, and restart reset the accumulator, so
elapsed presentation time cannot become deferred gameplay ticks after those
state transitions.

Keyboard and touch adapters maintain presentation-side input state. The
combined `PlayerInputAdapter` normalizes it to one `PlayerInput`, which the
Flame adapter supplies on each fixed step. UI actions use the narrower
`RaceUiController` contract: widgets can observe immutable `RaceUiState` and
request pause or restart, but cannot mutate `RaceSession` or car state.

## Flame and Flutter presentation

`ToyRacersGame` is the adapter around one `RaceSession`. `RaceWorld` projects
the session into a track component, race-object component, and car components;
it synchronizes visual state after simulation steps without owning gameplay.
The camera, overlays, sprites, touch controls, and audio controller are all
presentation concerns. Flutter owns the menu, car/track selection, settings,
race shell, and results navigation; it selects landscape orientation at app
startup.

## Assets and tracks

Repository-level `assets/` is canonical. Run
`python3 tools/flutter_asset_pipeline.py sync` from the repository root after
changing it; this materializes `dart/assets/`, its checksum manifest, and the
generated `pubspec.yaml` asset entries. Do not edit that mirror directly.

`TrackLoader` reads the bundled canonical TMX text through an injected text
source and converts it into portable track geometry, road/surface data,
checkpoints, start grid, and race metadata. Presentation loads rasters through
Flutter's asset bundle (`RasterAssetLoader`); rendering assets never determine
simulation geometry.

## Snapshot adapter and compatibility boundary

`SimulationSnapshot` is an immutable simulation observation. The compatibility
parser accepts the shared scenario/input contracts in `compatibility/schemas/`,
and `CompatibilityTraceJson` emits canonical snapshot-v2/trace-v3 JSON.
`tool/behavior_runner.dart` uses this boundary headlessly: it creates no
Flutter binding, Flame game, renderer, device input, or audio backend. This
keeps behavioral evidence reproducible and prevents platform state from
entering golden traces.

For commands and the current evidence, see [`../README.md`](../README.md),
[`PORTING_DIFFERENCES.md`](PORTING_DIFFERENCES.md),
[`PLATFORM_SUPPORT.md`](PLATFORM_SUPPORT.md), and
[`MIGRATION_REPORT.md`](MIGRATION_REPORT.md).
