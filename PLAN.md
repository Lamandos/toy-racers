# Sequential implementation plan

This file is consumed from top to bottom by `scripts/orchestrator.py`.
The tasks below are the remaining Flutter/Dart migration and delivery work.
The orchestrator stops at the first task that is not merged, so later tasks never
start on an unmerged base.

## TASK-026: Verify platform support

Verify each supported platform separately. Record exact commands, toolchain
versions, and limitations in `dart/docs/PLATFORM_SUPPORT.md`.

Acceptance criteria:

- Android: debug and release builds succeed; touch input, audio, lifecycle pause/resume, and landscape/orientation behavior are verified.
- iOS: build succeeds using an unsigned or simulator-compatible configuration; touch input, audio, and lifecycle behavior are verified.
- Web: build succeeds; keyboard input, browser resize, audio restrictions, and independence from JavaScript frame timing are verified.
- Windows: build succeeds; keyboard input, audio, window resize, and fullscreen behavior are verified.
- macOS: build succeeds; keyboard input and audio are verified.
- Linux: build succeeds; keyboard input and audio are verified.
- Platform-specific gaps are documented instead of being silently treated as passing.

## TASK-027: Add automated UI smoke tests

Add Flutter widget and/or integration smoke tests for the application flow. These
tests must exercise the UI boundary only; physics correctness remains covered by
the compatibility suite.

Acceptance criteria:

- The app launches and displays the main menu.
- A car can be selected and a track can be selected.
- A race can be started and the countdown is displayed.
- Pause and resume work.
- Results are displayed after an injected finished-simulation state.
- The tests do not use UI assertions as evidence of physics correctness.

Depends on: `TASK-026` platform test setup.

## TASK-028: Run performance sanity checks

Perform performance checks after correctness work is green. Do not optimize at
the cost of behavioral differences.

Acceptance criteria:

- The simulation does not create obvious large allocations on every tick.
- Collections used during simulation and rendering are bounded.
- A long race does not show unbounded memory growth.
- Rendering is stable on a representative desktop and mobile target.
- Debug and release builds produce the same simulation results for the same inputs.
- Any optimization that changes floating-point evaluation order is rejected unless equivalence is demonstrated and the compatibility goldens remain unchanged.
- Results, measurements, and known limits are recorded in the migration documentation.

Depends on: `TASK-026` and `TASK-027`.

## TASK-029: Complete CI coverage

Extend CI with Dart/Flutter jobs without weakening the existing Kotlin CI. Keep
the stages independently visible and make platform limitations explicit.

Acceptance criteria:

- CI has separate stages named or clearly equivalent to `kotlin-reference`, `dart-static-analysis`, `dart-unit`, `dart-compatibility`, `dart-fuzz`, and `dart-builds`.
- Kotlin reference tests and compatibility goldens continue to run.
- Dart runs format verification with `dart format --output=none --set-exit-if-changed`.
- Dart runs `flutter analyze`, unit tests, widget tests, the compatibility suite, differential fuzz smoke, and coverage.
- Suitable runners verify Android, Web, Linux, Windows, macOS, and an unsigned or simulator-compatible iOS build.
- A platform limitation or unavailable runner is documented and visible in CI rather than hidden.

Depends on: `TASK-026`, `TASK-027`, and `TASK-028`.

## TASK-030: Add convenient verification commands

Document simple commands for common Dart and compatibility workflows. Add one
root-level command or script for all Dart compatibility scenarios and one for
Kotlin-versus-Dart differential tests.

Acceptance criteria:

- `cd dart && flutter test` is documented and works.
- A single-scenario behavioral command is documented, including the scenario input and output paths.
- A root-level command runs all Dart compatibility scenarios.
- A root-level command runs Kotlin-versus-Dart differential tests.
- The chosen command names and arguments are stable, concise, and documented in the root and Dart READMEs.

Depends on: `TASK-029`.

## TASK-031: Enforce the regression rule

Define and automate the rule that a subsystem that has become green must not
become red in a later migration stage.

Acceptance criteria:

- Each subsequent stage runs the affected Dart unit tests, the affected compatibility category, and all previously ported compatibility categories.
- The pre-merge gate runs the entire Kotlin suite, entire Dart suite, and entire compatibility suite.
- A regression causes a visible failure with the failing subsystem/category identified.
- The rule and its expected workflow are documented for future task authors.

Depends on: `TASK-029` and `TASK-030`.

## TASK-032: Establish the mismatch investigation workflow

When Kotlin and Dart disagree, use evidence rather than guessing. Apply the
following sequence to every mismatch:

1. Find the scenario.
2. Find the first divergent sample.
3. Find the first divergent tick.
4. Find the first divergent field.
5. Reproduce one tick in isolation.
6. Compare inputs and pre-state.
7. Compare intermediate calculations.
8. Find the first mathematical divergence.
9. Fix Dart.
10. Add a regression test.
11. Run the scenario again.

Acceptance criteria:

- A reusable diagnostic command or documented procedure supports the sequence above.
- `dart/docs/PORTING_DIFFERENCES.md` exists as the evidence log for difficult divergences.
- Each recorded divergence includes: Scenario, Tick, Field, Root cause, Kotlin semantics, Incorrect Dart semantics, Fix, and Regression test.
- A mismatch is not marked resolved without a reproducible regression test and a rerun of the scenario.

Depends on: `TASK-030` and `TASK-031`.

## TASK-033: Record existing behavioral anomalies

Read `docs/BEHAVIORAL_TEST_REPORT.md` and record the existing anomalies before
making further migration changes. These are compatibility behavior during the
migration and must not be fixed as part of this task.

Acceptance criteria:

- The anomaly list covers AI seed behavior.
- The anomaly list covers player-finishes-race semantics.
- The anomaly list covers accumulator behavior after finish.
- The anomaly list covers impact/contact reporting anomalies.
- The anomaly list covers seeded inconsistent-state behavior.
- Other currently documented anomalies are included.
- Each entry states that the Kotlin implementation remains the reference during migration.
- No anomaly is changed or normalized by this task.
- Later behavior changes, if desired, are explicitly separate reviewed changes made in both implementations and tests while Kotlin remains the reference.

Depends on: `TASK-032`.

## TASK-034: Complete migration documentation

Create the documentation set for the Dart implementation and its support
matrix. Keep the documents synchronized with the commands and evidence produced
by the previous tasks.

Acceptance criteria:

- `dart/README.md` exists and explains setup, test, compatibility, and platform commands.
- `dart/docs/ARCHITECTURE.md` describes the simulation layer, Flame layer, Flutter UI, fixed timestep, input flow, asset flow, and snapshot adapter.
- `dart/docs/PORTING_DIFFERENCES.md` contains the mismatch evidence format and links to recorded divergences.
- `dart/docs/PLATFORM_SUPPORT.md` contains a table with Platform, Build, Input, Audio, and Tested columns for Android, iOS, Web, Windows, macOS, and Linux.
- `dart/docs/MIGRATION_REPORT.md` summarizes scope, ported behavior, known anomalies, test evidence, performance results, and remaining limitations.
- Root-level `ARCHITECTURE.md` explains how the Dart migration fits alongside the Kotlin reference implementation.
- Documentation does not claim unsupported platform capabilities or silently omit known limitations.

Depends on: `TASK-026` through `TASK-033`.
