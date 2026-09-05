# Kotlin-to-Dart porting differences

This is the evidence log for difficult, confirmed Kotlin-to-Dart behavioral
divergences. The Kotlin implementation is the oracle unless the compatibility
contract has been deliberately changed and reviewed. Do not use this log for a
suspected divergence that has not yet been reproduced.

## Recording rules

Create one entry after the cause is known. Every entry must include all of the
following fields; link paths relative to the repository root so another
developer can repeat the investigation.

```md
## <short divergence title> — <resolved YYYY-MM-DD>

- Scenario: `compatibility/scenarios/...`; command: `<replay command>`
- Tick: `<physical tick, or 0 for a lifecycle sample>` (`<sample label>`)
- Field: `<first field reported by the shared comparator>`
- Root cause: <the first operation whose result differs>
- Kotlin semantics: <source location and the relevant numeric/order semantics>
- Incorrect Dart semantics: <source location and the behavior before the fix>
- Fix: <Dart source location and concise correction>
- Regression test: `<test path or command>`; `<passing scenario rerun command>`
```

Lifecycle samples emitted during loading, ready, countdown, or racing
transitions use tick `0`; this is valid evidence and must not be changed to a
one-based physical tick. Confirm the tick and label against both traces before
copying a comparator report: the comparator zips sample arrays by index, so an
inserted event sample can make its reported tick refer to the wrong observations.
If traces are not aligned, record the insertion/deletion first and align them
before recording a field-level divergence.

For one-tick isolation, canonical trace values are display values only: trace
floats are formatted to six decimal places. Capture the exact Float32 pre-state
from both live replays before the failing tick using raw Kotlin `Float.toBits`
and Dart `Float32.bits(value)` values or another round-trippable representation;
`Float32.bits` is the repository's Dart raw-bit helper. If lap or finish timing
can affect the tick, use a schema-v3 scratch scenario and restore
`lapStartTime` and `bestLapTime` in `initialStates`, because schema v1/v2 cannot
represent those timers. For accumulated drift, compare both runtimes' raw
pre-states first and backtrack (or instrument the live replay) to the earliest
unequal pre-state before isolating a tick; otherwise isolation can erase the
history that caused the mismatch. A divergence is resolved only when that state
reproduces it, the focused regression test passes, and the original scenario is
rerun successfully.

`Regression test` must name both a focused, reproducible test and the scenario
rerun that passed after the fix. An entry is not resolved until both commands
have passed. Do not remove historical entries: they explain intentionally
non-obvious Float32, ordering, lifecycle, and collision decisions.

## Entries

No difficult divergences have been recorded yet.
