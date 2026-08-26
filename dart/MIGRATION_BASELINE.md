# Dart Migration Baseline

This is the verified Kotlin/libGDX reference baseline for [issue #40](https://github.com/Lamandos/toy-racers/issues/40), recorded before introducing Dart simulation code. The Kotlin implementation is the behavioral oracle.

Baseline commit: `682939aa63d760d8675b98a83720dc504b40a72e` (`main`)

## Reference checks

All of the following completed successfully without regenerating golden files:

```sh
./gradlew unitTest
./gradlew behavioralTest
./gradlew fuzzSmokeTest
./gradlew verifyCompatibilityGoldens
```

## Compatibility baseline

- Kotlin behavioral scenarios: 63
- Passing: 63
- Failing: 0
- Full races: 10 three-lap scenarios
- Fuzz seeds: 100 fixed seeds, each run for 120 ticks: `Long.MIN_VALUE`, `-1`, `0`, `1`, `Long.MAX_VALUE`, and `104729 * n` for every integer `n` from 1 through 95
- Stress fixtures: `core/src/test/resources/compat/stress/long_running_1000.json` (1,000 ticks) and `core/src/test/resources/compat/stress/long_running_5000.json` (5,000 ticks); the 5,000-tick trace is byte-identical across 20 normalized runs
- Golden git status: clean (`git status --short compatibility/golden` produced no output and `git diff --exit-code -- compatibility/golden` passed)
- Compatibility schema versions: scenario v1, v2, and v3; input script v1; snapshot v2; trace v3
- Comparator tolerance: absolute `0.0001` for documented approximate floating-point fields; relative tolerance is disabled. Discrete fields, structure, and array order compare exactly.

## Migration gate

Do not begin Dart simulation work while any Kotlin reference check above is failing. A Dart mismatch is presumed to be a Dart implementation error unless a reviewed change intentionally updates the established compatibility contract.
