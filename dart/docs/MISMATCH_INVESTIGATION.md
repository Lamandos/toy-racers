# Kotlin-to-Dart mismatch investigation

Use this procedure for every Kotlin-versus-Dart mismatch. It is deliberately
evidence-first: a later field difference is an effect, not a reason to change
the Dart simulation. Run commands from the repository root unless noted.

## Preserve the evidence

Keep the failing scenario, Kotlin trace, and Dart trace together in a scratch
directory outside checked-in fixtures. The differential fuzz task already keeps
these files for a failure under `core/build/differential-fuzz/`. Never
regenerate a golden or alter comparison tolerances while investigating.

For a checked-in scenario, make fresh traces with the two headless runners:

```sh
mkdir -p build/mismatch/<scenario>
./gradlew runBehaviorScenario \
  -Pscenario=compatibility/scenarios/car/straight_acceleration.json \
  -Poutput=build/mismatch/<scenario>/kotlin.json
(cd dart && dart run tool/behavior_runner.dart \
  --scenario ../compatibility/scenarios/car/straight_acceleration.json \
  --output ../build/mismatch/<scenario>/dart.json)
./gradlew :core:compareBehaviorTraces \
  -Pexpected=build/mismatch/<scenario>/kotlin.json \
  -Pactual=build/mismatch/<scenario>/dart.json
```

Replace the example path and `<scenario>` with the actual failing fixture. The
last command is the shared comparator. It compares sample arrays by index, not
by tick or label, so its first mismatch report is authoritative only after the
expected and actual sample sequences have been aligned. Before trusting it,
inspect both traces and record the ordered `(sample index, tick, label)`
sequence. Every sample through the candidate mismatch must have the same tick
and label; otherwise an extra Dart event can be paired with a later Kotlin
periodic sample and falsely identify the failing tick.

## Required sequence

1. **Find the scenario.** Record the exact scenario path (or the retained fuzz
   `scenario.json`), schema version, seed, and both trace paths. Do not replace
   it with an approximate hand-written input stream.
2. **Find the first divergent sample.** Inspect and align both ordered sample
   sequences by tick and label, then run the shared comparator above and retain
   its report. Its sample label distinguishes lifecycle/event samples from a
   normal physical-step sample. Resolve an insertion/deletion before treating
   any later paired sample as a mismatch.
3. **Find the first divergent tick.** After alignment, if the trace is sparse, copy the scenario
   (and its adjacent input script, when present) to the scratch directory and
   set only `snapshotIntervalTicks` to `1`; replay both copies and compare
   them. This creates an observation after every physical tick without changing
   the commands, seed, track, or initial state.
4. **Find the first divergent field.** Within the aligned sample, use the
   comparator's first reported field and participant. Confirm that all earlier samples and fields compare;
   do not choose a more visible downstream position or race-result difference.
5. **Reproduce one tick in isolation.** Prefer a single-step mode on the
   original live replay at the failing tick. This preserves state that a
   scratch scenario cannot describe. If a scratch scenario is more useful,
   create it with the pre-tick state and only the failing command. Include an
   `initialStates` record for every participant whose *public* state can affect
   that tick, preserve the original track and race progress, use `ticks: 1`,
   and set `snapshotIntervalTicks: 1`. Replay it through both runners.

   `initialStates` is not sufficient to establish isolation for stateful AI or
   recovery. Before claiming that the isolated tick reproduces the mismatch,
   restore every hidden value that can affect execution, using a temporary
   local state-injection probe or the original live replay. At minimum this
   includes `ReferenceAiDriver` random state, smoothed steering, mistake and
   recovery timers, target waypoint/path-follower state, recovery-controller
   state, and respawn state; for each `RaceParticipant` it includes
   `_lastSafeState` (and any other mutable recovery state). A fresh
   `ReferenceAiDriver` or `RaceParticipant` with only `initialStates` is not an
   isolated reproduction: it resets those values and may choose different AI
   input or a different respawn position. If hidden-state capture and restore
   is unavailable, label isolation inconclusive and return to the live replay;
   do not infer or reconstruct hidden state from a canonical trace. The
   canonical trace is not sufficient for reconstruction: its
   Float32 values are rendered to six decimal places. Capture the exact
   pre-tick binary32 values from both live replays before the failing tick as
   raw Kotlin `Float.toBits` and Dart `Float32.bits(value)` values (or another
   round-trippable representation), and restore those values in the isolated
   run. `Float32.bits` is the repository's Dart raw-bit helper. If lap or
   finish timing can affect the tick, the scratch scenario must use schema v3
   and restore `lapStartTime` and `bestLapTime` in `initialStates`; schema v1/v2
   cannot represent those timers.

   For accumulated drift, do not jump straight to a scratch scenario. First
   compare both runtimes' raw pre-states at the reported failing tick. If they
   differ, backtrack to the earliest tick with unequal raw pre-state (or add
   temporary live-replay instrumentation there) and isolate that tick instead.
   A scratch scenario that starts from only one runtime's rounded or inferred
   state can erase the history that caused the mismatch and produce a false
   result.
6. **Compare inputs and pre-state.** List the raw scenario command, applied
   normalized command, `inputTweaks`, fixed delta (`Float32(1 / 60)`), and each
   relevant pre-state value. Verify IDs, participant order, track/surface,
   checkpoint/lap/finish state, and Float32 narrowing before any physics. Do
   not call six-decimal trace values an exact pre-state; if exact capture was
   unavailable, label isolation inconclusive and return to the live run with
   instrumentation.
7. **Compare intermediate calculations.** Instrument the smallest affected
   Kotlin and Dart functions at the same named boundaries. Capture operands and
   results in execution order: normalization, surface lookup, steering,
   acceleration, drag, integration, collision/race-rule decisions, and final
   canonicalization as applicable. Keep the probes out of the committed trace
   contract and remove them when the focused regression test exists.
8. **Find the first mathematical divergence.** Identify the earliest unequal
   intermediate result, not merely the first unequal snapshot field. Check
   operation ordering, Float32 rounding points, integer conversion, angle
   normalization, collection ordering, and Kotlin `Float` versus Dart `double`
   semantics at that exact operation.
9. **Fix Dart.** Change only Dart behavior necessary to reproduce the Kotlin
   semantics. Do not modify Kotlin, golden fixtures, schemas, or tolerances to
   make the mismatch disappear unless a separately approved contract change
   requires it.
10. **Add a regression test.** Add a deterministic focused Dart test that
    fails before the fix and asserts the identified behavior. Retain or add a
    scenario-level regression when the issue crosses the replay boundary.
11. **Run the scenario again.** Recreate both traces and run the shared
    comparator using the original scenario. Run the focused regression test as
    well. Only then record the result in
    [`PORTING_DIFFERENCES.md`](PORTING_DIFFERENCES.md) using every required
    field; a mismatch is not resolved without both a reproducible regression
    test and a passing scenario rerun.

## Useful follow-up gates

After the focused investigation, run the affected migration stage from the
repository root, for example:

```sh
./gradlew dartMigrationStageCheck -Psubsystem=car --no-daemon
```

For a fuzz-derived failure, rerun its exact retained scenario first. The
broader fixed-seed check is:

```sh
./gradlew fuzzSmokeTest --no-daemon
```

These gates protect against regressions but do not replace the one-scenario
rerun required in step 11.
