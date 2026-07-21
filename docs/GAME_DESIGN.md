# Game design

## Working title

**Toy Racers**

The name is provisional and will be checked before public release.

## High concept

Toy Racers is a fast top-down arcade racing game with short events and toy cars competing on compact tracks laid out among oversized everyday objects.

## Design pillars

- **Immediate:** start a race quickly and understand the controls at a glance.
- **Arcade handling:** forgiving acceleration and braking with readable, controllable sliding.
- **Compact spectacle:** small tracks, close opponents, and oversized original household props.
- **Fair competition:** ordered checkpoints prevent shortcuts and AI follows the same driving rules as the player.
- **Phone first:** landscape presentation, scalable touch controls, and clear information on a small display.

## Core game loop

1. Select a track.
2. Select a car.
3. Start the event after a countdown.
4. Complete three valid laps.
5. Fight opponents for position.
6. Cross the finish line.
7. Review position, total time, lap times, and the best-time result.
8. Retry the event or continue to the next available event.

The MVP contains one track and one selectable player car, so the first two steps are simple confirmations while preserving the intended flow for future content.

## MVP scope

- One original compact track
- One player car
- Three AI-controlled opponent cars
- One three-lap race format
- Start countdown
- Acceleration, braking, reverse, steering, and controlled drift
- Collisions with track boundaries and other cars
- Ordered checkpoints, lap validation, timing, and race positions
- Pause and resume
- Results screen and race restart
- Local best-time persistence
- Basic original or properly licensed engine, collision, countdown, and UI sounds

## Player experience

- The first playable input should occur within a few seconds of choosing a race.
- The car should be stable and forgiving at low speed but reward smooth steering at high speed.
- Sliding should be visible and controllable rather than an unpredictable loss of control.
- Leaving the intended route must not grant a shortcut advantage.
- Opponents should finish reliably and feel competitive without visible teleporting or artificial speed boosts.
- A complete MVP race should be short enough to encourage an immediate retry.

## MVP controls

The game uses landscape orientation.

### Touch

- Left side: separate left and right steering buttons.
- Right side: a large accelerator button.
- Beside the accelerator: brake/reverse button.
- Multiple simultaneous touches are required so steering and acceleration work together.
- Pressing brake while moving forward slows the car; holding it near zero speed engages reverse.
- Touch state is cleared when the game is paused or loses focus.

### Desktop development controls

- `W` or Up Arrow: accelerate
- `S` or Down Arrow: brake/reverse
- `A` or Left Arrow: steer left
- `D` or Right Arrow: steer right
- `Escape`: pause
- `R`: restart the race

Desktop controls support development and testing; the Android touch layout is the primary MVP interface.

## Race rules

- A lap counts only after all checkpoints are crossed in order and the finish line is crossed in the valid direction.
- Race position is based on completed laps, checkpoint progress, and progress toward the next checkpoint.
- The player finishes after three valid laps.
- AI standings are resolved consistently when the player finishes.
- Pausing stops simulation time and clears active controls.
- Restarting returns every car and race counter to the initial grid state.

## Presentation

- Virtual presentation target: `1280 × 720`, scaled without stretching.
- Gameplay uses world units independent of phone pixels.
- Cars, boundaries, checkpoints, controls, and HUD must remain readable on a phone-sized landscape display.
- Camera movement should prioritize the route ahead while keeping the player car easy to track.

## Art and audio direction

The visual identity is playful and original, using distinct car silhouettes, colors, track layouts, and household props. Audio should be concise and readable on phone speakers. Every asset must be original, public domain, or used under a compatible license with recorded attribution.

The project must not copy protected names, logos, characters, vehicle designs, tracks, graphics, music, sounds, or other recognizable content from Micro Machines or any other game.

## Explicitly outside the MVP

- Online or local network multiplayer
- Shop or in-game economy
- Advertising
- User accounts
- Cloud saves
- Dozens of tracks
- Complex tuning or vehicle customization
- Story or campaign narrative
- Track editor
- Multiple vehicle classes
- Box2D unless custom arcade collision proves insufficient

## MVP success criteria

- A complete three-lap race can be played from start to results on a real Android phone.
- Touch steering, acceleration, braking, and reverse work simultaneously and recover correctly after pause.
- The race cannot be completed by skipping checkpoints.
- Three AI cars complete the track without routine deadlocks.
- Best time survives an application restart.
- Desktop tests pass and the Android debug build remains reproducible.
