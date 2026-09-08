# Dart/Flame Migration Report

Recorded: 2026-09-06. Kotlin/libGDX is the behavioral oracle; the runners use
the shared compatibility schemas, scenarios, goldens, and comparator.

Behavioral scenarios:

Passed: 113 / 113 (100%)

Failed: 0

Skipped: 0

Full races:

Passed: 10 / 10 (100%)

Differential fuzz seeds:

Passed: 100 / 100 (100%)

Stress:

1,000 ticks: PASS

5,000 ticks: PASS

Determinism:

20-run result: PASS — 20 / 20 identical complete 113-fixture replays, plus
20 / 20 byte-identical 5,000-tick stress traces.

Golden files modified: 0

Comparator tolerance modified: 0

Dart line coverage:

Simulation: 3,082 / 3,324 lines (92.72%)

Critical simulation modules: AI 95.10%, car 97.97%, collision 95.88%, race
97.60%. Every critical module is at or above 95%.

flutter analyze:

Errors: 0

Warnings: 0

Platforms:

Android: PASS — flutter build apk --debug completed locally on 2026-09-06.

iOS: BLOCKED (documented) — full Xcode and CocoaPods are unavailable. See
[PLATFORM_SUPPORT.md](PLATFORM_SUPPORT.md#ios).

Web: PASS — flutter build web --release completed locally on 2026-09-06; the
Wasm dry run also succeeded.

Windows: BLOCKED (documented) — a Windows host is required. See
[PLATFORM_SUPPORT.md](PLATFORM_SUPPORT.md#windows).

macOS: BLOCKED (documented) — the host has Command Line Tools, not full Xcode.
See [PLATFORM_SUPPORT.md](PLATFORM_SUPPORT.md#macos).

Linux: BLOCKED (documented) — a Linux host and GTK toolchain are required. See
[PLATFORM_SUPPORT.md](PLATFORM_SUPPORT.md#linux).

UI smoke tests:

PASS — flutter test test/ui_smoke_test.dart covers menu, selections, race
controls, pause/resume, and results. Kotlin desktop UI smoke also passed via
./gradlew qualityCheck --no-daemon.

Known behavioral differences:

None confirmed. Five deliberately preserved Kotlin oracle properties are
documented in [BEHAVIORAL_TEST_REPORT.md](../../docs/BEHAVIORAL_TEST_REPORT.md):
scenario seeds currently do not alter gameplay randomness; a player may finish
while AI cars race; finishing discards the current accumulator remainder and
later ticks; AI track contacts are omitted from aggregate impact speed; and a
seeded fixture may contain inconsistent velocity and speed components. These
are shared contract behavior, not Dart deviations.

Known visual differences:

The race camera uses the Kotlin `ExtendViewport` rule, and the HUD includes
the original standings, lap segments, and minimap geometry/markers. Automated
Flutter checks cover those structural elements, minimap projection coordinates,
and live marker repaints. This is not
a pixel-perfect claim: widget composition, not rendering goldens, is checked,
and interactive iOS, Windows, macOS, and Linux evidence is absent.

Known audio differences:

No confirmed controller or lifecycle difference. Audible device output has not
been verified, so decoder, routing, and speaker-output equivalence are open.

Remaining limitations:

- Android and Web are the only locally built targets. iOS, Windows, macOS, and
  Linux are documented host/toolchain blocks, not supported targets.
- TASK-028 has no representative native desktop and physical-mobile rendering
  performance result; see [PERFORMANCE.md](PERFORMANCE.md).
- Compatibility proves deterministic fixed-step scenarios, not live
  render-delta accumulation, asynchronous input timing, non-default fixtures,
  or every mid-race internal adapter state.

## Acceptance gates

### Gate A — Pure Dart simulation

PASS — every car, collision, track, surface, race, AI, and full-race scenario
passes; stress and determinism pass; goldens and comparator tolerance are
unchanged.

Pure Dart behavioral compatibility: PASS

### Gate B — Differential testing

PASS — 100 reproducible fixed seeds ran against Kotlin and Dart with no
ignored mismatch. The runner retains a failing seed for reproduction.

Kotlin ↔ Dart differential testing: PASS

### Gate C — Flame game

PASS — Flutter widget, Flame adapter, input, application, audio-controller,
and UI-smoke tests exercise track and car rendering, camera synchronization,
player input, AI synchronization, HUD, countdown, results, and pause.

Flame gameplay frontend: PASS

### Gate D — Cross-platform

BLOCKED — Android and Web build locally. The remaining four native targets
have documented host/toolchain blocks and are not counted as supported merely
because Flutter generates their runners.

### Gate E — Clean checkout

PASS — a detached clean worktree of commit e945f34 restored the lockfile with
flutter pub get --enforce-lockfile, then completed Flutter analysis and 255
tests, the coverage gate, Kotlin quality and test suites, Dart compatibility,
100-seed fuzz, stress/determinism, and 20-run behavioral stability. It ended
with empty compatibility/golden and compatibility/schemas diffs and no tracked
generated artifacts.

Kotlin Android tasks need a configured Android SDK in a clean checkout. Set
ANDROID_HOME to the installed SDK directory, or provide the equivalent ignored
local.properties sdk.dir value, before running Gradle:

    export ANDROID_HOME=/path/to/Android/sdk
    ./gradlew qualityCheck --no-daemon

## Final migration result

    Toy Racers Dart/Flame migration: FAIL

    Pure Dart behavioral compatibility:
    113 / 113 scenarios

    Full races:
    10 / 10

    Differential fuzz:
    100 / 100

    Stress:
    1,000 ticks: PASS
    5,000 ticks: PASS

    Determinism:
    20 / 20 identical

    Golden files changed:
    NO

    Comparator tolerance changed:
    NO

    Dart simulation coverage:
    92.72%

    Flutter analyze:
    0 errors
    0 warnings

    Tests:
    Kotlin: PASS
    Dart unit: PASS
    Compatibility: PASS
    Flutter UI: PASS

    Platform builds:
    Android: PASS
    iOS: BLOCKED (documented)
    Web: PASS
    Windows: BLOCKED (documented)
    macOS: BLOCKED (documented)
    Linux: BLOCKED (documented)

    Known behavioral differences:
    None confirmed; documented oracle quirks are preserved.

    Known visual differences:
    No confirmed automated difference; native interactive coverage is incomplete.

    Known audio differences:
    No confirmed controller difference; audible output is unverified.

    Ready to replace Kotlin/libGDX version:
    NO

The migration is FAIL only because Cross-platform Gate D is incomplete. It is
not a behavioral compatibility failure.

## Supporting evidence

## Scope

The Dart project ports Toy Racers' deterministic Kotlin/libGDX gameplay to
pure Dart and presents it with Flutter and Flame. Kotlin is still the oracle;
the shared schemas, scenarios, goldens, and comparator remain at the repository
root and are not forked into `dart/`.

## Ported behavior

The simulation covers fixed-step car physics, Float32-compatible arithmetic,
track/TMX loading, collision response, surfaces, race lifecycle and rules,
checkpoints/laps/results, deterministic AI, scenario replay, and canonical
compatibility traces. The presentation includes Flutter menu/selection/settings
screens, Flame race rendering with an `ExtendViewport`-equivalent camera,
keyboard and touch input, HUD standings, lap progress, a screen-space minimap,
overlays, and presentation-only audio lifecycle/mixing.

## Test evidence

The latest recorded full behavioral gate reports **113 / 113 PASS** across
car, collision, race, track, surface, AI, and full-race scenarios. The stress
gate's recorded success is **20 / 20 identical** Dart replays and **2 / 2
PASS** Kotlin-versus-Dart stress traces. On 2026-09-06, the complete Flutter
suite recorded **255 tests passed**. Its critical pure-Dart line coverage was
AI **95.10%**, car **97.97%**, collision **95.88%**, and race **97.60%**.
The 20-run full behavioral stability result is recorded only after the manual
`dartBehavioralStabilityTest` release gate completes; it is not inferred from
individual test runs.

Reproduce the main gates from the repository root:

```sh
./gradlew dartCompatibilityTest --no-daemon
./gradlew fuzzSmokeTest --no-daemon
./gradlew dartStressDeterminismTest --no-daemon
cd dart && flutter analyze --fatal-infos && flutter test
```

`dart/docs/PERFORMANCE.md` records the commands, exact measurements, and
constraints behind the performance evidence. `dart/docs/PLATFORM_SUPPORT.md`
separates compile evidence from runtime and audible-output evidence.

## Known anomalies and limitations

The compatibility goldens intentionally preserve five surprising oracle
behaviors: scenario seeds do not affect gameplay randomness; the player can
finish while AI cars are still running; finishing discards the accumulator
remainder and later ticks from that `advance` call; AI track contacts are
omitted from aggregate impact speed; and an explicitly seeded test fixture can
contain inconsistent velocity and speed components. These are recorded in the
[behavioral test report](../../docs/BEHAVIORAL_TEST_REPORT.md) and are not
silently treated as new Dart defects. No additional confirmed difficult
Kotlin-to-Dart divergence is currently recorded; the evidence-log template and
future records are in
[`PORTING_DIFFERENCES.md`](PORTING_DIFFERENCES.md). A broad Chrome test command
previously hung after 27 tests; the isolated browser suites were used instead
and are documented in [`PLATFORM_SUPPORT.md`](PLATFORM_SUPPORT.md).

TASK-028 remains incomplete: no representative native desktop or physical
mobile rendering-performance pass has been recorded. Headless Chrome and the
software-rendered Android emulator are explicitly negative/non-representative
evidence, not release-performance evidence. Several native targets have only
shared-test or CI build evidence; iOS, Windows, macOS, and Linux do not have a
local interactive runtime verification in the recorded environment. Audible
output has not been verified on any target. See the platform matrix for the
precise status.

The 113/113 behavioral result also has deliberate boundaries. The headless
scenarios do not represent live render-delta accumulation or asynchronous input
timing; non-default countdown durations and lap counts are unsupported by the
current fixture boundary; and the public snapshot adapter cannot restore or
compare mid-race accumulator remainder, next finish position, or AI continuation
state. Ordered per-physical-step contact traces are also not fully exposed.
These limits mean the behavioral pass establishes deterministic scenario
compatibility, not complete runtime equivalence. The authoritative list is in
[`docs/BEHAVIORAL_TEST_REPORT.md`](../../docs/BEHAVIORAL_TEST_REPORT.md).

## Performance result

The bounded six-car simulation probe, memory/collection bounds, state-identity
checks, and debug/AOT state comparison passed as recorded in
[`PERFORMANCE.md`](PERFORMANCE.md). The recorded debug and AOT state documents
were byte-identical. That confirms deterministic simulation for that probe; it
does not prove frame pacing on user hardware.

## Remaining work

Before a release-quality claim, run the rendering probe on a physical Android
or iOS device and a representative native desktop or interactive Chrome target,
record renderer/device/refresh/power details and UI/raster percentiles, and
close each platform-specific input, lifecycle, resize, and audible-output gap.
Continue to investigate any future mismatch with
[`MISMATCH_INVESTIGATION.md`](MISMATCH_INVESTIGATION.md); do not change goldens
or tolerances merely to silence a difference.
