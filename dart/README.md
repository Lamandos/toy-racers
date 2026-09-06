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
  --output build/behavior/straight_acceleration.json
```

The scenario input is
`../compatibility/scenarios/car/straight_acceleration.json`; the generated
canonical trace is written to
`dart/build/behavior/straight_acceleration.json` from the repository root.

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

## Audio

`lib/audio/` is a presentation-only controller with a Flame Audio backend. It
ports the reference music, one-shot effects, looping race mix, volume defaults,
pause behavior, and 0.8-second finish fade without adding audio to behavioral
traces or golden masters. Browser playback waits for the first semantic user
gesture and skips unsupported audio preloading. See
[`../docs/AUDIO_SMOKE_TESTS.md`](../docs/AUDIO_SMOKE_TESTS.md) for automated
smoke coverage and real-device/manual acceptance.

`package:toy_racers/simulation.dart` is the public pure-Dart entrypoint. The
included headless assembly check can be run without creating a Flutter binding:

```sh
dart run tool/simulation_architecture_check.dart
```

Read these contracts before adding simulation code:

- [`../compatibility/README.md`](../compatibility/README.md)
- [`../docs/BEHAVIORAL_TEST_STRATEGY.md`](../docs/BEHAVIORAL_TEST_STRATEGY.md)
- [`MIGRATION_BASELINE.md`](MIGRATION_BASELINE.md)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for Dart layer boundaries,
  fixed-step/input flow, assets, and snapshots
- [`docs/MIGRATION_REPORT.md`](docs/MIGRATION_REPORT.md) for the current
  migration evidence and open limitations
- [`docs/PLATFORM_SUPPORT.md`](docs/PLATFORM_SUPPORT.md) for per-target build,
  input, audio, and runtime evidence
- [`docs/MISMATCH_INVESTIGATION.md`](docs/MISMATCH_INVESTIGATION.md) for the
  required evidence-first Kotlin-to-Dart mismatch workflow
- [`docs/PORTING_DIFFERENCES.md`](docs/PORTING_DIFFERENCES.md) for confirmed
  difficult-divergence records

## Dependencies

- `flame` is the required presentation engine for the later Flutter layer.
- `flame_audio` provides the supported multi-platform playback backend; Flame
  alone does not include audio players.
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

From the repository root, the regular Dart suite is:

```sh
cd dart && flutter test
```

For analysis, coverage, and locked dependency resolution, run these commands
from this directory:

```sh
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test
flutter test --coverage
```

After resolving dependencies, run either complete compatibility workflow from
the repository root:

```sh
./gradlew dartCompatibilityTest --no-daemon
./gradlew fuzzSmokeTest --no-daemon
```

`dartCompatibilityTest` replays every Dart compatibility scenario against its
Kotlin golden. `fuzzSmokeTest` runs the fixed-seed Kotlin-versus-Dart
differential suite. Both use `dart` by default; use
`-PdartExecutable=/path/to/dart` before the task name when needed.

For each migration stage, run the focused regression gate from the repository
root, substituting the changed category:

```sh
./gradlew dartMigrationStageCheck -Psubsystem=car --no-daemon
```

It runs the affected Dart unit tests and then the entire compatibility
inventory, protecting every category that has already passed. Before merge,
run `./gradlew preMergeRegressionCheck --no-daemon` to execute the complete
Kotlin suite, Dart suite, and compatibility inventory.

The coverage output is `coverage/lcov.info` and is intentionally ignored by
Git. The repository CI runs analysis and the coverage-producing test command.

## Full behavioral gate

After subsystem scenarios pass, replay the complete current compatibility
inventory against its checked-in Kotlin goldens:

```sh
dart run tool/full_behavioral_gate.dart
```

The root-level equivalent is `./gradlew dartCompatibilityTest --no-daemon`.

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

## Performance sanity checks

Run the bounded six-car long-race probe and the focused regressions with:

```sh
dart run tool/performance_sanity.dart
flutter test test/performance_sanity_test.dart
```

Profile rendering on a real target with:

```sh
flutter run --profile -d <device> -t tool/render_performance_sanity.dart
```

Commands, thresholds, measurements, and target limitations are recorded in
[`docs/PERFORMANCE.md`](docs/PERFORMANCE.md). A headless browser or
software-rendered emulator result is not treated as a representative-device
pass.

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
