# Performance sanity report

This report records the TASK-028 checks run on 2026-09-02 and revalidated on
2026-09-04 after the Dart correctness and UI smoke work. Performance changes
are accepted only when the Kotlin compatibility goldens remain unchanged. The
measurements below are sanity evidence from one host, not release budgets for
every supported target.

## Host and thresholds

- Host: Intel macOS 26.6.2, build 25G83, `x86_64`.
- Flutter 3.47.1 stable, Dart 3.13.1, Chrome 152.0.7977.66.
- Long-race RSS threshold: no more than 64 MiB of later-half peak growth after
  warm-up. This uses process RSS and allows normal garbage-collector sawtooth.
- Rendering threshold: after a three-second asset warm-up, at most 5% of 300
  profile-mode frames may exceed 16.667 ms on either the UI or raster thread.
  Flutter Web uses a 20 ms frame-cadence fallback because it does not expose
  engine `FrameTiming` values.

## Simulation and memory result

The production six-car living-room assembly ran 500 warm-up ticks followed by
5,000 measured fixed ticks with neutral player input:

```sh
dart run tool/performance_sanity.dart \
  --warmup-ticks 500 \
  --measured-ticks 5000 \
  --sample-every-ticks 500 \
  --allowed-growth-mib 64 \
  --report-output build/performance/task-028-long-race.json
```

Result: **PASS**. The measured loop took 89,564 ms (55 ticks/s in the JIT
process), and the final state fingerprint was `f2c93a7bd53a70c2`. RSS samples
in bytes were:

```text
257650688, 259829760, 261296128, 262901760, 263958528,
265531392, 267374592, 244310016, 245358592, 246931456,
248135680
```

The early-half peak was 265,531,392 bytes and the later-half peak was
267,374,592 bytes, so reported later-half growth was 1,843,200 bytes (1.76
MiB), well below the 64 MiB threshold. The last sample was also below the
initial sample. This 5,500-tick run is 91.7 seconds of simulated race time and
retains no per-tick trace or snapshot history.

The runner reports bounds from the production assembly rather than growing
collections while it runs. The six-car configuration has five opponents, at
most five dynamic obstacles per AI, three sensor rays with at most 20 samples
per ray, three collision circles per car, four track-resolution passes, 15 car
pairs, and six finish results. The loaded track owns immutable lists of 28
collision shapes, three checkpoints, six start positions, and 32 racing-line
points. Its strict worst-case contact-list bound is 360 contacts per car
(`3 circles * 4 passes * (2 world axes + 28 shapes)`). Presentation topology is
fixed at six car components and eight world children. The audio mix queue
retains only its current write and one replaceable pending target. Each
participant retains three fixed `CarState` copies (initial, previous-frame, and
last-safe) and no tick-history collection.

## Allocation audit and changes

The tick and render hot paths were inspected before optimization. The accepted
changes are intentionally allocation-only:

- `RaceParticipant` now reuses its previous-frame and last-safe `CarState`
  storage instead of replacing both objects every fixed tick. `CarState.copyFrom`
  copies already narrowed fields without arithmetic; a regression test checks
  equality and binary32 bits, including signed zero. This is an additive,
  source-compatible public API change.
- AI track rays pass the already computed binary32 `x`/`y` coordinates directly
  to containment checks instead of allocating a `TrackPoint` for every ray
  sample. Arithmetic and evaluation order are unchanged.
- AI obstacle enumeration is consumed once by `AiRaceContext` into its existing
  unmodifiable list, avoiding an intermediate growable list. Participant order
  is unchanged and the list is bounded by opponent count.
- Car and authored-track renderers retain their `Paint`, source `Rect`, and
  destination `Rect` objects; a car destination is rebuilt only if callers
  resize that component. Checkpoint endpoints and paints are projected once
  when their component is created. The render topology regression runs 1,000
  visual synchronizations and requires the same car map and child order.
- The profile probe retains at most the requested number of engine timings
  (300 by default). Its web fallback retains exactly one more timestamp than
  the requested interval count and stops scheduling callbacks on completion or
  timeout.

One candidate optimization was rejected after measurement: retaining the
one-or-three collision circles for an entire track-collision call produced only
86 of 113 passing compatibility fixtures. Earlier circle resolution mutates the
car state, so later circles must be recomputed from that updated state. The
original recomputation was restored; its small bounded allocations are part of
the compatibility behavior.

Small per-tick value objects and bounded collision/contact lists remain. They
were not pooled because mutability or reuse would complicate ownership and
risk compatibility behavior. No optimization changed floating-point grouping,
operation order, tolerances, scenarios, or golden files.

## Debug and release equivalence

The same six-car fixed-input run used 100 warm-up and 500 measured ticks in an
assert-enabled JIT process and in an AOT executable:

```sh
dart --enable-asserts run tool/performance_sanity.dart \
  --warmup-ticks 100 --measured-ticks 500 --sample-every-ticks 100 \
  --state-only --state-output build/performance/debug-state.json
dart compile exe tool/performance_sanity.dart \
  -o build/performance/performance_sanity
build/performance/performance_sanity \
  --warmup-ticks 100 --measured-ticks 500 --sample-every-ticks 100 \
  --state-only --state-output build/performance/release-state.json
cmp build/performance/debug-state.json build/performance/release-state.json
```

Result: **PASS**. Both modes produced simulation tick 600, state fingerprint
`fecfaba3cf53c309`, and byte-identical state documents with SHA-256
`b9b7e7f956c39f7f8755ba439148a7cbdbfb0861e1dbe837ef9803d6eb9d5be0`.
`flutter build apk --debug` and `flutter build apk --release` also succeeded
from the revalidated source; the release APK was 61.1 MB.
The AOT executable must run outside the Codex filesystem sandbox on this host
because the Dart runtime's macOS CPU probe aborts inside that sandbox before
creating an isolate.

## Rendering result and target limits

The reusable profile entry point is:

```sh
flutter run --profile -d <device> -t tool/render_performance_sanity.dart
```

It loads the production six-car race, excludes asset warm-up, and prints one
machine-readable line prefixed with `TOY_RACERS_RENDER_PERFORMANCE=`. The report
tests and topology regression pass, but this host did **not** provide a passing
representative desktop-and-mobile pair:

- Chrome profile, headless desktop host: **FAIL / not representative**. A
  60-frame diagnostic completed with all 60 intervals above 20 ms, cadence p90
  733,300 microseconds and p99 783,300 microseconds. Headless Chrome is retained
  as negative harness evidence, not promoted to a desktop performance pass.
- GPU-backed Chrome profile rerun on 2026-09-04: **BLOCKED / not
  representative**. The default 300-frame web build succeeded, but Flutter's
  temporary Chrome instance emitted no result after the probe timeout and was
  not visible to the connected browser-control session, so it could not be
  foregrounded to rule out background throttling. The run was stopped after
  approximately four minutes and is not counted as a desktop pass.
- Pixel 9 Pro API 35 `x86_64` emulator, profile mode, Impeller OpenGLES through
  SwiftShader: **BLOCKED**. The default 300-frame probe timed out after 45
  seconds without receiving 300 timing samples. A reduced 60-frame diagnostic
  APK built successfully, but the headless emulator then stopped completing
  ADB installation and was interrupted after 60 seconds. This repeats the ADB
  responsiveness limit recorded in `PLATFORM_SUPPORT.md`.
- Native macOS: **BLOCKED** because full Xcode is unavailable. iOS is blocked
  for the same reason; Windows and Linux require their native hosts.

Before release, rerun the default 300-frame command on a physical Android or
iOS device and on a representative native desktop or interactive Chrome
session. Record UI/raster percentiles and the exact device, refresh rate,
renderer, and power mode. The current automated environment cannot establish
the rendering-stability acceptance criterion, so no desktop or mobile pass is
claimed here.

## Verification commands

Focused checks:

```sh
flutter analyze --fatal-infos
flutter test test/performance_sanity_test.dart
dart run tool/full_behavioral_gate.dart
git diff --exit-code -- ../compatibility/golden
```

The final full gate was compiled to a temporary AOT executable to make the
long fixture inventory practical on this host. It reported **113 / 113 PASS**
across car, collision, race, track, surface, AI, and full-race categories, with
zero unexpected golden changes. The normal `dart run` command above exercises
the same gate but is substantially slower in this environment.

The performance test covers RSS scoring, collection bounds, repeated-run state
identity, binary32 state copying, fixed render topology, and rendering report
thresholds. The full behavioral gate is the required compatibility safeguard;
goldens must never be regenerated to make an optimization pass.
