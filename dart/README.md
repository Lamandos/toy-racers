# Toy Racers — Dart/Flutter

This directory is the independent Flutter project for the cross-platform Dart
implementation of Toy Racers. It was generated with Flutter 3.47.1 on the
stable channel. Develop and run CI with the Flutter stable channel.

The project includes the Android, iOS, web, Windows, macOS, and Linux targets.
The committed `pubspec.lock` resolves Flame 1.38.1 and every transitive package
used by this bootstrap.

## Migration boundary

Issue #40 treats the Kotlin/libGDX implementation as the behavioral oracle.
This bootstrap contains no gameplay rendering, UI, audio, or input
implementation. The project now has a deliberately small simulation
architecture in
[`lib/simulation/`](lib/simulation/). It establishes the pure-Dart ownership
boundaries and binary32 data contracts; it does not yet port gameplay physics,
collision handling, race rules, AI behaviour, track loading, or compatibility
replay execution. Those behaviours must be implemented incrementally against
the Kotlin golden masters.

`CompatibilityScenarioParser` reads the shared scenario v1-v3 and input-script
v1 documents directly. `CompatibilityTraceJson` writes the shared snapshot v2
and trace v3 output with canonical number formatting. The canonical contracts
remain in [`../compatibility/schemas/`](../compatibility/schemas/); the Dart
project deliberately does not contain a forked schema copy.

New gameplay code must begin in `lib/simulation/` as pure Dart. Simulation
modules may not import Flutter, Flame, or `dart:ui`; they may not use wall-clock
time or a render loop. Flutter and Flame belong only in the later presentation
layer after the deterministic simulation gate passes.

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
- `flutter_lints` supplies the shared static-analysis rules.
- `flutter_test` is Flutter's SDK test framework.

No standalone coverage package is used: `flutter test --coverage` is Flutter's
built-in LCOV generator.

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
