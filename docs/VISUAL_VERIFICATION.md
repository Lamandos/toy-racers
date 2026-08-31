# Dart visual verification

Behavioral compatibility verifies the pure Dart simulation against the Kotlin
golden traces. It deliberately does not inspect pixels, camera framing, sprite
orientation, scene layering, or Flutter UI composition.

`dart/test/visual/visual_verification_test.dart` is the separate Flutter
presentation check. It renders a fixed 800×600 test canvas, captures an
in-memory screenshot frame for each state, and verifies
gameplay-relevant composition through semantic controls and layout bounds.

Run it from `dart/` with:

```sh
flutter test test/visual/visual_verification_test.dart
```

The check captures these reviewable screenshots:

- main menu
- track selection
- car selection
- race start
- active race
- pause
- results

It does not compare screenshot bytes to committed files or persist a raster
baseline. GPU drivers, font rasterizers,
Flutter engines, and libGDX/OpenGL differ across supported platforms, so a
pixel-perfect Kotlin-to-Flutter baseline would be unstable. Instead, the test
requires the authored track and car images, race HUD/state overlays, pause and
results actions, selected race data, and the expected screen hierarchy. This
makes the screenshots a focused rendering/composition gate while deterministic
gameplay remains solely covered by the compatibility scenarios.
