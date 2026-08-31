# Toy Racers — Dart/Flutter

This directory is the independent Flutter project for the cross-platform Dart
implementation of Toy Racers. It was generated with Flutter 3.47.1 on the
stable channel. Develop and run CI with the Flutter stable channel.

The project includes the Android, iOS, web, Windows, macOS, and Linux targets.
The committed `pubspec.lock` resolves Flame 1.38.1, the pure-Dart `xml`
parser, and every transitive package used by this bootstrap.

## Migration boundary

Issue #40 treats the Kotlin/libGDX implementation as the behavioral oracle.
This bootstrap contains no gameplay rendering, UI, audio, or input
implementation. The project now has a deliberately small simulation
architecture in
[`lib/simulation/`](lib/simulation/). It establishes the pure-Dart ownership
boundaries and binary32 data contracts, including the reference-compatible
`CarPhysics` integrator. `TrackLoader` now reads the canonical TMX sources
through an injected pure-Dart text source and supplies both built-in tracks,
their collision and road contours, world coordinates, race metadata, and
surface lookup. Collision response, surface speed effects, race rules, AI
behaviour, and complete compatibility replay execution still must be
implemented incrementally against the Kotlin golden masters.

`CompatibilityScenarioParser` reads the shared scenario v1-v3 and input-script
v1 documents directly. `CompatibilityTraceJson` writes the shared snapshot v2
and trace v3 output with canonical number formatting. The headless
`tool/behavior_runner.dart` replays one scenario using only the pure-Dart
simulation boundary; it does not create a Flutter binding, Flame game, or
render loop. The canonical contracts remain in
[`../compatibility/schemas/`](../compatibility/schemas/); the Dart project
deliberately does not contain a forked schema copy.

Run one scenario from this directory with:

```sh
dart run tool/behavior_runner.dart \
  --scenario ../compatibility/scenarios/car/straight_acceleration.json \
  --output build/behavior/actual.json
```

The runner already owns parsing, input-script resolution, initial-state
injection, one `1 / 60` fixed step per requested tick, lifecycle/event
sampling, and canonical JSON output. The reference-compatible car-physics
implementation is active in the runner. Track data is available to the pure
simulation through `TrackLoader`; connecting it to the replay pipeline waits
for collision, surface, race-rule, and AI migrations, so generated traces are
structurally valid but are not yet expected to match Kotlin golden masters.

New gameplay code must begin in `lib/simulation/` as pure Dart. Simulation
modules may not import Flutter, Flame, or `dart:ui`; they may not use wall-clock
time or a render loop. Flutter and Flame belong only in the later presentation
layer after the deterministic simulation gate passes.

## Flutter UI command boundary

Flutter UI follows this presentation-only flow:

```text
Main menu → car selection → track selection → race → results → menu / restart
```

Widgets receive the `RaceUiController` interface instead of a `RaceSession`.
They render its immutable `RaceUiState` and can change a race only with the
documented `togglePause()` and `restartRace()` commands. Desktop keyboard and
mobile touch adapters produce `PlayerInput` commands; the Flame adapter passes
them to `RaceSession.advanceFixedStep()` on the fixed-timestep boundary. UI
widgets must never mutate a `RaceSession`, `CarState`, race progress, or finish
results directly.

`package:toy_racers/simulation.dart` is the public pure-Dart entrypoint. The
included headless assembly check can be run without creating a Flutter binding:

```sh
dart run tool/simulation_architecture_check.dart
```

Read these contracts before adding simulation code:

- [`../compatibility/README.md`](../compatibility/README.md)
- [`../docs/BEHAVIORAL_TEST_STRATEGY.md`](../docs/BEHAVIORAL_TEST_STRATEGY.md)
- [`MIGRATION_BASELINE.md`](MIGRATION_BASELINE.md)

## Dependencies

- `flame` is the required presentation engine for the later Flutter layer.
- `xml` reads the canonical TMX collision and road-contour sources without
  bringing Flame Tiled into simulation.
- `flutter_lints` supplies the shared static-analysis rules.
- `flutter_test` is Flutter's SDK test framework.

No standalone coverage package is used: `flutter test --coverage` is Flutter's
built-in LCOV generator.

## Flutter asset pipeline

The repository-level [`../assets/`](../assets/) directory is the canonical
runtime asset source for both implementations. Flutter packages assets relative
to `pubspec.yaml`, so the committed [`assets/`](assets/) directory is a
generated materialized mirror; never edit its contents or the generated asset
block in `pubspec.yaml` manually.

From the repository root, update the mirror after changing a canonical asset:

```sh
python3 tools/flutter_asset_pipeline.py sync
```

The pipeline maps `assets/**` to `dart/assets/**` and materializes the
repository-level audio attribution record [`SOURCES.md`](../SOURCES.md) at
`dart/assets/attribution/SOURCES.md`. It also regenerates
`dart/assets/flutter_asset_manifest.json`, which records the source path and
SHA-256 checksum for every generated file. Verify the mirror without changing
it with:

```sh
python3 tools/flutter_asset_pipeline.py check
```

The check rejects missing, stale, or modified generated assets, checksum
manifest changes, and a stale generated `pubspec.yaml` asset list. It runs in
local hooks and CI. Flutter requires every nested asset directory to be
declared in `pubspec.yaml`; generating individual entries keeps new asset
directories automatically packageable. See Flutter's
[asset-bundling documentation](https://docs.flutter.dev/ui/assets/assets-and-images)
for the packaging rule.

## Verify

Run these commands from this directory:

```sh
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test
flutter test --coverage
```

The coverage output is `coverage/lcov.info` and is intentionally ignored by
Git. The repository CI runs analysis and the coverage-producing test command.

## Full behavioral gate

After subsystem scenarios pass, replay the complete current compatibility
inventory against its checked-in Kotlin goldens:

```sh
dart run tool/full_behavioral_gate.dart
```

The gate dynamically includes every legacy fixture plus every file-based
scenario with a matching golden, while excluding referenced input scripts. It
prints the total passed inventory and `PASS` or `FAIL` for car, collision,
race, track, surface, AI, and full-race scenarios. It does not regenerate or
modify golden masters, invokes the shared Kotlin trace comparator, and returns
a non-zero status for any deterministic mismatch. Do not begin Flame
integration until this command reports no failures.

## Stress and determinism gate

The separate long-running gate replays the existing 1,000- and 5,000-tick
fixtures, validates every sampled race state, runs the Dart 5,000-tick fixture
twenty times, and requires an identical canonical-output FNV-1a-64 hash on
every run. It then compares both retained Dart traces with newly generated
Kotlin oracle traces through the existing comparator contract:

```sh
./gradlew dartStressDeterminismTest --no-daemon
```

Its success output includes `Dart determinism: 20 / 20 identical` and
`Kotlin-vs-Dart stress: 2 / 2 PASS`. The task is intentionally manual and
available in GitHub Actions through **Run workflow** with
`run_dart_stress_determinism` enabled; it is too long for the normal pull
request checks. It never changes scenarios, golden masters, or tolerances.

## Build targets

```sh
flutter build apk --debug
flutter build ios --debug
flutter build web
flutter build windows
flutter build macos
flutter build linux
```

Each native build requires its matching host operating system and platform
toolchain. The generated project files enable all targets even when the local
host cannot build each one.
