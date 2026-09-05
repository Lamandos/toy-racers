# Code quality

The repository uses aligned Kotlin/Gradle and Dart/Flutter quality gates locally and in GitHub Actions.
Java 21, Gradle 9.5.0, ktlint 1.8.0 (Gradle plugin 14.2.0), and detekt 1.23.8 are pinned in the
repository. The Dart project uses the Flutter stable channel, `flutter_lints`, Flutter's built-in test
runner, and built-in LCOV coverage output.

GitHub Actions exposes the Dart and Kotlin reference gates independently as
`kotlin-reference`, `dart-static-analysis`, `dart-unit`, `dart-compatibility`,
`dart-fuzz`, and `dart-builds`. `dart-builds` uses native Ubuntu, Windows, and
macOS runners to compile Android, web, Linux, Windows, macOS, and an unsigned
simulator-compatible iOS target. Each matrix job writes its runtime/device
limitation to the workflow summary; successful compilation is not treated as a
device, interactive-input, or audible-output pass.

## Install Git hooks

Run this once after cloning:

```sh
./scripts/install-git-hooks.sh
```

The script is idempotent and sets `core.hooksPath` to `.githooks`. The pre-commit hook runs the Flutter asset pipeline
unit tests and staged SHA-256 parity check, Kotlin style checks, detekt, the 500-line source-file gate, JVM unit tests,
the desktop UI smoke flow, plus Dart format verification, Flutter analysis, and tests. The pre-push hook runs the same
asset pipeline tests and parity check, then the complete `preMergeRegressionCheck`: Kotlin `qualityCheck` (including
behavioral compatibility fixtures, deterministic repeat tests, Android debug unit tests, the core coverage gate, and
mutation testing), the full Dart and Flutter test suite, and the Dart full behavioral gate. It then runs fixed-seed
differential fuzz smoke. Flutter stable must be available on `PATH`. The `pre-merge-regression` GitHub Actions job runs
the same aggregate gate after the independently visible CI stages have passed. The 20-run full behavioral stability
suite remains intentionally opt-in.

On headless Linux, both hooks automatically use `xvfb-run --auto-servernum` for the desktop UI smoke flow. Install
Xvfb before committing or pushing from that environment.

## Run checks

```sh
./gradlew quickQualityCheck
./gradlew qualityCheck
./gradlew unitTest
./gradlew behavioralTest
./gradlew fuzzSmokeTest
./gradlew dartMigrationStageCheck -Psubsystem=car
./gradlew preMergeRegressionCheck
./gradlew coverageReport
./gradlew mutationTest
./gradlew behavioralStabilityTest
./gradlew ktlintCheck
./gradlew detekt
./gradlew test
./gradlew lwjgl3:uiSmokeTest
python3 tools/flutter_asset_pipeline.py check

cd dart
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
dart run tool/full_behavioral_gate.dart
```

`behavioralTest` is the primary local behavioral suite. It verifies the versioned behavioral fixtures and both
golden-master formats, then runs the long-running deterministic repeat test. `coverageReport` generates the JaCoCo
report and verifies overall Line and Branch coverage of at least 85%, plus at least 90% Line coverage in the AI, car,
collision, race, surface, and track packages. `mutationTest` runs PIT against the four critical deterministic rule
systems: car physics, collision response, race rules, and surface speed. It requires at least 70% killed mutations.
`fuzzSmokeTest` runs on every normal GitHub Actions workflow to compare fixed-seed Kotlin and Dart traces. It remains
available as an explicit local command for focused diagnosis.

`behavioralStabilityTest` intentionally takes much longer than pull-request checks: it runs the complete inventory of
legacy, file-per-scenario, full-race, and long-running fixtures twenty times sequentially and compares canonical JSON
from every replay. Reserve up to six hours for the manual GitHub Actions job (or use a sufficiently provisioned local
machine) before a release. Run it through **Run workflow** with `run_behavioral_stability` enabled; a successful
invocation is the evidence for a 0% flaky result across 20 full suite runs.

For Dart migration stages, use `dartMigrationStageCheck` with the affected
compatibility category. It runs the registered focused Dart tests and then the
entire compatibility inventory, so every already-green category is protected.
`preMergeRegressionCheck` is the required aggregate pre-merge command; it runs
the full Kotlin suite through `qualityCheck`, the entire Dart suite, and the
complete Dart compatibility inventory. See
[`BEHAVIORAL_COMPATIBILITY.md`](BEHAVIORAL_COMPATIBILITY.md) for the category
mapping and the workflow for future task authors.

Ordinary test tasks are read-only with respect to checked-in fixtures. Regenerate behavioral goldens only with:

```sh
./gradlew regenerateBehaviorGolden
```

Review every resulting golden diff before committing it.

`uiSmokeTest` launches the real desktop libGDX application in a fixed 1280×720 window with disabled audio. It
needs a working OpenGL display server; on a headless Linux machine, use `xvfb-run --auto-servernum` as CI does.

Formatting is checked without modifying files. To apply safe formatting fixes explicitly, run:

```sh
./gradlew ktlintFormat
cd dart
dart format .
```

Flutter analysis is also read-only. Its configured rules are in `dart/analysis_options.yaml`; the
coverage command writes ignored output to `dart/coverage/lcov.info`.

`tools/flutter_asset_pipeline.py check` validates that `dart/assets/` is the exact generated SHA-256 mirror of
the canonical `assets/` tree and the repository-level `SOURCES.md` attribution record. It also validates the
generated Flutter asset declarations in `dart/pubspec.yaml`. After changing a canonical asset, run
`python3 tools/flutter_asset_pipeline.py sync`, review the generated mirror, then run the check again.

## Diagnose failures

- ktlint reports are under `<module>/build/reports/ktlint/`; run `ktlintFormat`, review the diff, then rerun the check.
- detekt reports are under `<module>/build/reports/detekt/`; the console output includes the rule and source location.
- test reports are under `<module>/build/reports/tests/`; rerun a focused test with
  `./gradlew core:test --tests 'fully.qualified.TestName'`.
- `verifySourceFileLengths` reports every Kotlin or Java source file over 500 physical lines.
- Dart formatting is verified with `dart format --output=none --set-exit-if-changed .`.
  Flutter reports lint findings through `flutter analyze --fatal-infos`; Flutter test output and
  coverage are produced with `flutter test --coverage` from `dart/`.

Generated sources and build artifacts are excluded. `StartupHelper.kt` is also excluded from detekt because it is
the Apache-2.0-licensed libGDX launcher helper retained from the project generator; it remains covered by ktlint.
Ordinary game code is not excluded and no detekt or ktlint baseline is used.
