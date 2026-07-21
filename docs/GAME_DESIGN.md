# Game design

## Vision

Toy Racers is a quick, readable arcade race viewed from above. Small toy cars compete on compact, original tracks laid out among oversized everyday objects. Controls should feel immediate on a touchscreen, while momentum and controlled sliding provide room for mastery.

## MVP

- One original track
- One player car and three AI cars
- Three-lap race
- Start countdown and pause
- Acceleration, braking, reverse, steering, and controlled drift
- Collisions with track boundaries and cars
- Ordered checkpoints, lap counting, race positions, and results
- Best-time persistence
- Basic engine, collision, countdown, and UI sounds

## Player experience

- A race should start quickly and remain understandable on a phone-sized display.
- The car should be forgiving at low speed and reward smooth steering at high speed.
- Leaving the intended route must not provide a shortcut advantage.
- AI opponents should finish reliably and provide competition without cheating visibly.

## Controls

The initial touch layout uses left/right steering and acceleration/brake controls. Reverse engages through braking when the car is nearly stopped. Exact placement and optional alternatives will be validated on a real Android phone.

## Race rules

- A lap counts only after all checkpoints are crossed in order and the finish line is crossed in the valid direction.
- Race position is based on completed laps, checkpoint progress, and distance toward the next checkpoint.
- The race ends when the player completes three valid laps; AI results are resolved consistently at that moment.

## Art and audio direction

Use a distinct, playful visual identity built from original shapes, colors, props, cars, and track layouts. Assets must be original, properly licensed, or public domain. The project must not imitate protected names, logos, characters, track designs, graphics, music, or sounds from existing games.

## Out of scope for MVP

- Online multiplayer
- Car customization economy
- Track editor
- Campaign progression
- Box2D unless custom arcade collision proves insufficient
- Multiple tracks or vehicle classes
