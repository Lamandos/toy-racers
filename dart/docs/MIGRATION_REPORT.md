# Dart migration report

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
screens, Flame race rendering and camera, keyboard and touch input, overlays,
and presentation-only audio lifecycle/mixing.

## Test evidence

The latest recorded full behavioral gate reports **113 / 113 PASS** across
car, collision, race, track, surface, AI, and full-race scenarios. The stress
gate's recorded success is **20 / 20 identical** Dart replays and **2 / 2
PASS** Kotlin-versus-Dart stress traces. On 2026-09-05, the complete Flutter
suite recorded **238 tests passed**. These are recorded results, not a claim
that the commands were rerun by this documentation task.

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

No confirmed difficult Kotlin-to-Dart divergence is currently recorded; the
evidence-log template and future records are in
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
