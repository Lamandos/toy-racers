# Code quality

The repository uses the same Gradle quality gates locally and in GitHub Actions. Java 21, Gradle 9.5.0,
ktlint 1.8.0 (Gradle plugin 14.2.0), and detekt 1.23.8 are pinned in the repository.

## Install Git hooks

Run this once after cloning:

```sh
./scripts/install-git-hooks.sh
```

The script is idempotent and sets `core.hooksPath` to `.githooks`. The pre-commit hook runs Kotlin style checks,
detekt, the 500-line source-file gate, JVM unit tests, and the desktop UI smoke flow. The pre-push hook runs the
complete `qualityCheck`, including Android debug unit tests and the existing core coverage gate.

## Run checks

```sh
./gradlew quickQualityCheck
./gradlew qualityCheck
./gradlew ktlintCheck
./gradlew detekt
./gradlew test
./gradlew lwjgl3:uiSmokeTest
```

`uiSmokeTest` launches the real desktop libGDX application in a fixed 1280×720 window with disabled audio. It
needs a working OpenGL display server; on a headless Linux machine, use `xvfb-run --auto-servernum` as CI does.

Formatting is checked without modifying files. To apply safe formatting fixes explicitly, run:

```sh
./gradlew ktlintFormat
```

## Diagnose failures

- ktlint reports are under `<module>/build/reports/ktlint/`; run `ktlintFormat`, review the diff, then rerun the check.
- detekt reports are under `<module>/build/reports/detekt/`; the console output includes the rule and source location.
- test reports are under `<module>/build/reports/tests/`; rerun a focused test with
  `./gradlew core:test --tests 'fully.qualified.TestName'`.
- `verifySourceFileLengths` reports every Kotlin or Java source file over 500 physical lines.

Generated sources and build artifacts are excluded. `StartupHelper.kt` is also excluded from detekt because it is
the Apache-2.0-licensed libGDX launcher helper retained from the project generator; it remains covered by ktlint.
Ordinary game code is not excluded and no detekt or ktlint baseline is used.
