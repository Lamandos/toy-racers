# Flutter audio smoke tests and manual acceptance

Audio is a presentation concern. It observes the Dart `RaceSession` through
the Flame adapter but never changes simulation state, scenarios, trace schema,
comparator tolerances, or behavioral golden masters. In particular, a passing
audio check is not evidence for physics, collision, checkpoint, lap, AI, or
results correctness.

## Automated smoke test

Run the deterministic, output-device-free checks with:

```sh
cd dart
flutter test test/audio_smoke_test.dart
```

The recording backend checks these integration decisions without playing a
WAV file:

- menu music initialization and the reference default music level (0.55);
- native preloading and the browser policy that skips preload;
- browser playback deferred until a pointer or keyboard activation;
- UI button, countdown, checkpoint, off-road, collision, and finish events;
- five long-lived loops, race mixing, pause/resume muting, and the 0.8-second
  results fade;
- master, music, and SFX volume scaling and invalid-value rejection.

## Manual acceptance checklist

Use a host with an audible output device. The in-memory volume settings reset
when the application process restarts, matching the reference implementation's
current lack of persistence.

- [ ] On Android, iOS, Linux, macOS, or Windows, launch the app and confirm the
  looping menu music starts at the menu. Navigate between menu, car selection,
  and track selection: the same music continues without a second concurrent
  track.
- [ ] In **Settings**, change Master, Music, and SFX independently with the
  minus/plus controls. Music reacts immediately; later UI and race effects use
  the new SFX level. Return with **Back** and confirm the values are retained
  for this app session.
- [ ] Activate menu, car, track, pause, results, and volume controls with both
  pointer/touch and keyboard Enter/Space. Every actionable control should emit
  the click effect at the configured SFX volume (except controls activated
  while race audio is deliberately paused).
- [ ] Start a race. Menu music continues; one countdown cue plays when the
  three-light countdown begins and the `GO` cue plays on the transition to
  racing. Engine, brake, drift, gravel, and grass loops do not create duplicate
  voices after retrying a race.
- [ ] Accelerate, brake at speed, drift, drive from road to parquet/tile, and
  drive on grass. Confirm engine pitch/volume follows speed and throttle,
  braking and drift respond to driving, grass/gravel loops follow the surface,
  and a gravel-entry hit plays once per entry.
- [ ] Make light, medium, and heavy impacts. Confirm the matching collision
  family plays and rapid contacts cycle its bundled variants rather than always
  replaying one file.
- [ ] Pause a racing game with Escape, HUD, and touch control. Music and all
  race loops mute; simulation does not advance. Resume and confirm music
  returns and loops are mixed from the current car state. Background and resume
  the app once to confirm lifecycle pause does not leave a persistent loop.
- [ ] Finish a race. The finish cue plays once, race loops fade over about
  0.8 seconds, and the results overlay appears only after that fade. Restarting
  must reset the fade and keep a single set of loops.
- [ ] On web, load the page without interacting: absence of autoplay is
  expected. The first Play, Settings, or other semantic button activation must
  unlock audio without an uncaught browser-policy error. Verify the rest of the
  checklist after that gesture; web deliberately skips Flame Audio preload
  because audioplayers does not support it there.
- [ ] On a host with no audio device (such as headless CI), the game remains
  playable and tests remain green; unavailable playback is non-fatal.
