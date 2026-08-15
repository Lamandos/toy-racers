# Toy Racers

Toy Racers is an original arcade 2D top-down racing game about toy cars on compact tracks built around everyday objects. The MVP targets Android and includes one track, a player car, three AI opponents, three laps, a starting countdown, pause, results, best-time persistence, and basic audio.

The project does not use names, artwork, tracks, audio, characters, or other protected assets from existing racing games.

## Technology

- Kotlin
- libGDX
- Gradle
- Android Studio
- Desktop LWJGL3 and Android launchers

## Project status

The repository currently contains the project documentation. The libGDX modules will be generated in the next setup step with GDX-Liftoff.

## Run

After the Gradle project is generated:

```sh
./gradlew lwjgl3:run
./gradlew android:installDebug
```

The Android task requires an Android SDK and a connected device or running emulator.

## Test and verify

```sh
./gradlew test
./gradlew lwjgl3:test
./gradlew android:assembleDebug
```

Task names may be adjusted to match the generated GDX-Liftoff project. Before completing a change, run the relevant tests, the desktop task, and the Android debug build.

## Assets

Runtime assets will live in `assets/`, which is shared by the platform launchers according to the generated libGDX configuration. Only original, licensed, or public-domain assets may be added. Record licenses and attribution alongside third-party assets.

## Build rules

- Use a JDK version compatible with the checked-in Gradle wrapper and Android Gradle Plugin.
- Build through the checked-in Gradle wrapper; do not rely on a system Gradle installation.
- Keep gameplay logic in `core` and platform integration in platform modules.
- Do not access Android APIs from `core`.
- Add tests for gameplay logic where practical.
- Do not add dependencies without documenting the need and trade-offs.

See [game design](docs/GAME_DESIGN.md), [architecture](docs/ARCHITECTURE.md), [tasks](docs/TASKS.md), and
[code quality](docs/CODE_QUALITY.md).
