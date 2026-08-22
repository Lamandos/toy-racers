# Compatibility golden masters

This directory stores versioned, rendering-independent behavioural compatibility fixtures. A
scenario is a deterministic input to the headless simulation; its golden is the accepted normalized
trace for that one scenario.

## Layout

```
compatibility/
├── schemas/       Published JSON contracts for scenarios, input scripts, and traces
├── scenarios/     One scenario document per file, grouped by gameplay area
├── golden/        Checked-in golden trace with the same relative path as its scenario
└── tools/         Explicit maintenance commands
```

Scenario filenames are stable and use `snake_case`; their JSON `id` values are stable,
lowercase-kebab-case, and must be unique across every category. The path is the pairing rule: for
example, `scenarios/car/straight_acceleration.json` is verified against
`golden/car/straight_acceleration.json`. Input-script files kept beside a scenario must use a
lowercase-hyphen-separated `.json` filename matching `[a-z0-9][a-z0-9-]*\.json`; referenced
scripts are excluded from scenario discovery and have no golden of their own.

The recommended categories are `car`, `collision`, `race`, `track`, `surface`, `ai`, and
`full_race`. Add a scenario to the narrowest category that owns the behaviour being locked down.

## Verification and regeneration

Normal tests only compare existing files; they never write a golden. Run the dedicated check with:

```sh
./gradlew verifyCompatibilityGoldens
```

Regeneration is deliberately a separate, explicit maintenance command:

```sh
./compatibility/tools/regenerate-goldens.sh
```

It runs the headless Kotlin reference simulation, rewrites only out-of-date goldens, and prints
every changed path. It fails if a golden has no matching scenario. Golden JSON files are versioned
repository inputs and must be committed with their scenario changes.

## When updating a golden is acceptable

Update a golden only after an intentional and reviewed change to the simulation contract, a
documented gameplay bug fix, or the addition of a new scenario. Do not regenerate to make an
unexpected test failure disappear. Review the printed trace diff, explain why each changed state is
expected in the pull request, and commit the scenario, golden, and any relevant contract or test
changes together.
