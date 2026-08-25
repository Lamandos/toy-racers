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
complete `qualityCheck`, including behavioral compatibility fixtures, deterministic repeat tests, Android debug unit
tests, the core coverage gate, and mutation testing. The fixed-seed fuzz smoke and the 20-run full behavioral
stability suite are intentionally opt-in.

On headless Linux, both hooks automatically use `xvfb-run --auto-servernum` for the desktop UI smoke flow. Install
Xvfb before committing or pushing from that environment.

## Run checks

```sh
./gradlew quickQualityCheck
./gradlew qualityCheck
./gradlew unitTest
./gradlew behavioralTest
./gradlew fuzzSmokeTest
./gradlew coverageReport
./gradlew mutationTest
./gradlew behavioralStabilityTest
./gradlew ktlintCheck
./gradlew detekt
./gradlew test
./gradlew lwjgl3:uiSmokeTest
```

`behavioralTest` is the primary local behavioral suite. It verifies the versioned behavioral fixtures and both
golden-master formats, then runs the long-running deterministic repeat test. `coverageReport` generates the JaCoCo
report and verifies overall Line and Branch coverage of at least 85%, plus at least 90% Line coverage in the AI, car,
collision, race, surface, and track packages. `mutationTest` runs PIT against the four critical deterministic rule
systems: car physics, collision response, race rules, and surface speed. It requires at least 70% killed mutations.
`fuzzSmokeTest` runs only when invoked explicitly; the GitHub Actions fuzz job is available through **Run workflow**
with `run_fuzz_smoke` enabled.

`behavioralStabilityTest` intentionally takes much longer than pull-request checks: it runs the complete inventory of
legacy, file-per-scenario, full-race, and long-running fixtures twenty times sequentially and compares canonical JSON
from every replay. Reserve up to six hours for the manual GitHub Actions job (or use a sufficiently provisioned local
machine) before a release. Run it through **Run workflow** with `run_behavioral_stability` enabled; a successful
invocation is the evidence for a 0% flaky result across 20 full suite runs.

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
