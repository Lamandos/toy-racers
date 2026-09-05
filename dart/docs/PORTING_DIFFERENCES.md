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
- Tick: `<one-based physical tick>` (`<sample label>`)
- Field: `<first field reported by the shared comparator>`
- Root cause: <the first operation whose result differs>
- Kotlin semantics: <source location and the relevant numeric/order semantics>
- Incorrect Dart semantics: <source location and the behavior before the fix>
- Fix: <Dart source location and concise correction>
- Regression test: `<test path or command>`; `<passing scenario rerun command>`
```

`Regression test` must name both a focused, reproducible test and the scenario
rerun that passed after the fix. An entry is not resolved until both commands
have passed. Do not remove historical entries: they explain intentionally
non-obvious Float32, ordering, lifecycle, and collision decisions.

## Entries

No difficult divergences have been recorded yet.
