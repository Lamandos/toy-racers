# UI smoke tests

`./gradlew lwjgl3:uiSmokeTest` is the secondary UI verification layer. It starts the real desktop libGDX
application with a fixed-size window and sends pointer events to the active Scene2D stage.
Audio is disabled so the run does not require an output device.

The runner covers these stable, user-visible paths:

- main menu → track selection;
- track selection → car selection;
- car selection → start race;
- race pause and resume;
- results → retry and results → main menu.

Each target control has a semantic Scene2D actor name. The runner locates that visible control and sends normal
pointer down/up events at its centre; it does not invoke screen callbacks directly. A fixed `RaceResult` fixture
opens the results screen after the pause flow. This deliberately avoids treating a UI smoke check as a way to create
or validate a gameplay finish.

The task is part of `quickQualityCheck` and `qualityCheck`. It requires an OpenGL display server. GitHub Actions
runs the quality gate under `xvfb-run --auto-servernum`; use the same wrapper for headless Linux development.

## Screenshot goldens

No screenshot golden is currently a required check. Pixel output from libGDX can vary across GPU drivers, OpenGL
implementations, fonts, and window systems, and the project has not yet established a deterministic rendering
environment for stable baselines. If that environment is introduced later, main-menu, race-HUD, and results images
may be added as separate visual-regression goldens.

Screenshot equality can prove only that a rendered frame matches its approved visual baseline. It must never be
used as evidence that car physics, collision response, checkpoint progression, laps, AI, or race outcomes are
correct; those remain covered by deterministic core tests and behavioral compatibility scenarios.
