# Repository instructions

These instructions apply to the entire repository.

## Kotlin style

- Follow the official Kotlin coding conventions and the formatting already present in the project.
- Prefer small, focused classes and functions with explicit responsibilities.
- Use immutable data by default. Do not introduce global mutable singletons.
- Name game concepts consistently and avoid unexplained abbreviations.
- Do not create oversized classes without documenting why separation is impractical.

## Architecture

- Keep gameplay rules and simulation separate from rendering, input presentation, and platform integration.
- The `core` module contains portable game logic and must not depend on Android APIs.
- The Android module should contain only the launcher and Android-specific integrations.
- Keep changes scoped to one concern; do not modify multiple subsystems in one task unless the coupling is explained.
- Do not change public interfaces without explaining the compatibility impact.

## Tests and dependencies

- Add unit tests for new or changed gameplay logic wherever practical.
- Do not add a dependency without explaining why existing code or current dependencies are insufficient.
- Prefer deterministic tests for physics, race rules, checkpoints, laps, and AI decisions.

## Verification

After code changes, run the tasks available in the generated project:

```sh
./gradlew test
./gradlew lwjgl3:run
./gradlew android:assembleDebug
```

If a task name differs, use its generated equivalent and record that in the handoff. Before finishing, inspect `git diff`, show `git diff --stat`, and list test results and known risks.

## Intellectual property

- Use only original, properly licensed, or public-domain names, code, graphics, models, music, and sounds.
- Do not copy protected resources, branding, characters, tracks, or other recognizable content from Micro Machines or any other game.
- Preserve license and attribution information for permitted third-party resources.
