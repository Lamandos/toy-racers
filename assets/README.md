# Runtime assets

## `sprites/player-car.png`

- Original top-down toy car sprite created for Toy Racers with OpenAI image generation on 2026-07-21.
- The generated source used a flat chroma-key background; the checked-in image has had that background removed and was resized to `64 × 128` pixels.
- No third-party game artwork or vehicle branding was used as a reference.

## `audio/*.wav`

- Original procedural prototype sounds generated specifically for Toy Racers.
- The deterministic source is `tools/generate_audio_assets.py`; it uses only Python's standard
  library and does not sample or derive from third-party recordings or music.
- The generated set contains engine and skid loops, race/UI cues, collision SFX, and a short
  original background loop.

## `sprites/ai-car-orange.png`

- Original top-down toy car created for Toy Racers with OpenAI built-in image generation on
  2026-07-27.
- Generated on a chroma-key background and processed with
  `tools/ProcessGeneratedSprite.java` into a transparent `64 × 128` sprite.
- No brand, real vehicle, protected character, or third-party artwork was used as a reference.

## `game.atlas`

- Project-authored libGDX atlas descriptor collecting the two original car sprites.

## `tracks/track_01.png`

- User-provided original track background, imported from `Desktop/track_01.png` on 2026-07-28.
- A black-and-white start/finish stripe was added with OpenAI built-in image editing on
  2026-07-29; the edit prompt requested a single stripe on the lower straight while preserving
  the existing scene, road geometry, lighting, objects, colors, dimensions, and crop.
- Its road, parquet, object collision masks, and world boundary are authored separately in
  `TrackLoader`, so simulation does not depend on image pixels.

## `tracks/track_01.tmx`

- Editable Tiled map for `track_01.png`.
- The `collisions` object layer is the runtime source of polygon and circular collision contours.
- Open this file in Tiled, edit only the object layer, save, and restart the game to apply changes.

## `tracks/track_02.png`

- User-provided original track background, imported from `Desktop/track_02.png` on 2026-07-29.
- A black-and-white start/finish stripe was added with OpenAI built-in image editing on
  2026-07-29; the edit prompt requested a single stripe on the lower straight while preserving
  the existing bathroom scene, road geometry, lighting, objects, colors, dimensions, and crop.
- Collision contours live in `track_02.tmx`; checkpoints, grid, and the AI racing line live in
  `TrackLoader`.

## `tracks/track_02.tmx`

- Runtime Tiled map containing the manually authored road contours and solid collisions.
- Follow `track_02-collision-guide.md` when refining the collision geometry.
