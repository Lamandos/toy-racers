# Code quality

The repository uses the same Gradle quality gates locally and in GitHub Actions. Java 21, Gradle 9.5.0,
ktlint 1.8.0 (Gradle plugin 14.2.0), and detekt 1.23.8 are pinned in the repository.

## Install Git hooks

Run this once after cloning:

```sh
./scripts/install-git-hooks.sh
```

The script is idempotent and sets `core.hooksPath` to `.githooks`. The pre-commit hook runs Kotlin style checks,
detekt, the 500-line source-file gate, and JVM unit tests through a Gradle daemon. The pre-push hook runs the
complete `qualityCheck`, including Android debug unit tests and the existing core coverage gate, through the same
mode. CI uses the same commands.

## Run checks

```sh
./gradlew quickQualityCheck --daemon
./gradlew qualityCheck --daemon
./gradlew ktlintCheck
./gradlew detekt
./gradlew test
```

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
