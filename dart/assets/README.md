# Runtime assets

## `audio/*.wav`

- The UI cues and background loop were generated specifically for Toy Racers.
- Their deterministic source is `tools/generate_audio_assets.py`; it uses only Python's standard
  library and does not sample or derive from third-party recordings or music.
- The licensed CC0 pack built in `racing_audio/` was integrated into the runtime on 2026-07-30.
  The game uses one real engine loop with throttle-controlled volume, one brake loop, and the new
  tire, collision, gravel, grass, and countdown assets. Full provenance is in the repository-level
  `SOURCES.md`.

## `sprites/cars/*.png`

- Five player-selectable car drawings imported from the user-provided `Desktop/car models.png`
  on 2026-08-02.
- The runtime cutouts were refined with OpenAI image editing on 2026-08-02 to remove cast
  shadows, smooth the silhouettes, and align the green racer and orange truck with the other
  cars while preserving the supplied designs.
- `tools/ProcessCarModelSheet.java` deterministically separates the drawings from their light
  checkerboard background and fits them to transparent `64 × 128` runtime canvases.
- The source sheet contains no visible vehicle branding; the user is responsible for its
  provenance and permission to use it.

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
