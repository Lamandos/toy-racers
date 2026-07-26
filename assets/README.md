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
