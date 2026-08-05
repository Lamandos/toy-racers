# Architecture

## Goals

The architecture keeps the race simulation portable, deterministic, and testable while allowing desktop and Android launchers to share the same game. Rendering observes game state but never owns gameplay rules.

## Modules

### `core`

Contains all portable game code: screens, assets, input abstractions, race simulation, car physics, track data, AI, rendering, UI, audio coordination, and debug tools. It may use cross-platform libGDX APIs but must not import Android APIs.

### `lwjgl3`

Contains the desktop launcher and desktop-only configuration. It is the primary fast feedback target during development and must not contain gameplay rules.

### `android`

Contains the Android launcher, manifest, lifecycle integration, and Android-specific adapters. It must not contain gameplay rules or state that belongs to `core`.

### `assets`

Contains shared runtime textures, atlases, fonts, maps, music, sounds, and asset-license metadata. Both launchers use the same assets.

## Planned `core` packages

```text
core/src/main/kotlin/com/example/toyracers/
├── ToyRacersGame.kt
├── assets/
│   ├── AssetPaths.kt
│   └── GameAssets.kt
├── screen/
│   ├── LoadingScreen.kt
│   ├── MainMenuScreen.kt
│   ├── RaceScreen.kt
│   └── ResultsScreen.kt
├── world/
│   ├── RaceWorld.kt
│   ├── RaceState.kt
│   └── RaceConfig.kt
├── car/
│   ├── Car.kt
│   ├── CarState.kt
│   ├── CarConfig.kt
│   ├── CarController.kt
│   └── CarPhysics.kt
├── track/
│   ├── Track.kt
│   ├── TrackLoader.kt
│   ├── Checkpoint.kt
│   ├── StartGrid.kt
│   └── SurfaceType.kt
├── ai/
│   ├── AiDriver.kt
│   ├── RacingLine.kt
│   └── AiConfig.kt
├── input/
│   ├── PlayerInput.kt
│   ├── InputController.kt
│   ├── TouchInputController.kt
│   └── KeyboardInputController.kt
├── render/
│   ├── RaceRenderer.kt
│   ├── CarRenderer.kt
│   ├── TrackRenderer.kt
│   └── HudRenderer.kt
├── camera/
│   └── RaceCameraController.kt
├── collision/
│   ├── CollisionSystem.kt
│   └── CollisionResult.kt
├── race/
│   ├── LapTracker.kt
│   ├── PositionTracker.kt
│   └── RaceRules.kt
├── ui/
│   ├── MainMenuStage.kt
│   ├── RaceHudStage.kt
│   └── ResultsStage.kt
├── audio/
│   └── AudioManager.kt
└── debug/
    ├── DebugRenderer.kt
    └── DebugSettings.kt
```

This is a target structure, not a requirement to create empty placeholder classes. Packages and classes are added with the feature that needs them.

## Responsibilities

- `ToyRacersGame` owns application-wide resources and screen transitions.
- Screens coordinate a use case and lifecycle; they do not implement car physics or race rules.
- Input controllers translate keyboard or touch state into `PlayerInput` commands.
- `RaceSession` advances the simulation and owns the active `RaceState` and competitors.
- `CarPhysics` changes `CarState` from configuration, input, and fixed elapsed time.
- `CollisionSystem` detects and resolves contacts, returning explicit results.
- Race services validate checkpoints, laps, positions, and finish conditions.
- AI produces the same command type used by the player rather than moving cars directly.
- `AiDriver` coordinates focused `AiPathFollower`, `AiObstacleDetector`, and
  `AiRecoveryController` services. `CarController` consumes the shared `CarInput` command type.
- `RaceSession` performs a recovery respawn only after the AI requests it, restoring the last
  asphalt position without granting checkpoint progress for the move.
- Renderers read state and draw it. They must not mutate the simulation.
- UI stages display state and emit user intentions; they do not calculate gameplay outcomes.

## Update and rendering flow

```text
keyboard/touch ──> InputController ──> PlayerInput
                                             │
AI route ───────────────> AiDriver ──────────┤
                                             ▼
                                     RaceSession update
                                     /       |        \
                               CarPhysics  Collision  RaceRules
                                     \       |        /
                                             ▼
                                         RaceState
                                             │
                            ┌────────────────┴───────────────┐
                            ▼                                ▼
                       RaceRenderer                       UI stages
```

Input only creates commands. The model updates state, physics moves cars, collision correction keeps the state valid, and renderers only draw the resulting snapshot.

## Time model

Gameplay simulation uses a fixed timestep of `1 / 60` second. Screens cap accumulated frame time before stepping the world, so a temporary stall cannot trigger an unbounded update loop. Rendering may run at a different frame rate and can interpolate later if needed.

## Lifecycle and ownership

- The owner that creates a disposable libGDX resource also disposes it.
- Application-wide assets are created once and disposed by `ToyRacersGame`.
- Screen-specific batches, shape renderers, stages, and viewports are disposed by their screen.
- `pause` clears transient input so a held touch cannot remain active after resume.
- `resize` updates viewports; it does not modify world coordinates or simulation state.

## Dependency rules

- Dependencies point from presentation and platform code toward portable abstractions, never from `core` toward Android.
- Game model classes do not depend on renderers, Scene2D widgets, or launchers.
- AI and player controllers both depend on the portable input model.
- New libraries require a documented need and platform-impact review.
- Box2D is not part of the initial implementation; custom arcade physics is used first.
- Global mutable singletons are prohibited.

## Testing and verification

Unit tests in `core` cover deterministic behavior such as acceleration, steering, lateral grip, collision response, checkpoint order, laps, rankings, and AI decisions. Rendering and platform launchers are verified through desktop execution, Android debug builds, and manual testing on a real Android phone.

Standard checks:

```sh
./gradlew test
./gradlew lwjgl3:run
./gradlew android:assembleDebug
```
