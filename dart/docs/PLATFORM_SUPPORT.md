# Platform support verification

This report records the platform verification performed on 2026-09-01 for
TASK-026. Commands were run from `dart/` unless a command says otherwise.

`PASS` means the named build or automated behavior completed successfully on
the stated runtime. `PARTIAL` means only the listed evidence passed. `BLOCKED`
means the required host, toolchain, or responsive device was unavailable. A
shared Flutter test is evidence for the Dart presentation boundary, but is not
treated as a native-device test or proof that sound reached a speaker.

## Support matrix

| Platform | Build | Input | Audio | Tested |
| --- | --- | --- | --- | --- |
| Android | **PASS**: debug and release APKs | **PARTIAL**: touch adapters and overlay pass automated tests; the device-level touch run was blocked when the headless emulator stopped servicing ADB | **PARTIAL**: controller, asset, mix, pause, and resume tests pass; audible emulator/device output was not verified | Build on macOS; install, launch, resumed activity, fullscreen task, and sensor-landscape rotation on Pixel 9 Pro API 35 |
| iOS | **BLOCKED**: simulator debug build did not reach Xcode | **PARTIAL**: shared touch tests pass; no iOS runtime test | **PARTIAL**: shared controller/lifecycle tests pass; no iOS backend or audible-output test | Checked-in target inspected on macOS; full Xcode and CocoaPods unavailable |
| Web | **PASS**: release dart2js build and Wasm dry run | **PASS**: keyboard and touch adapters in Chrome; responsive widget layouts at 800x600 and 640x360 | **PARTIAL**: browser gesture/deferred-playback/no-preload policy passes in Chrome with a recording backend; audible browser output was not verified | Chrome 152 headless; fixed-step behavior passes at simulated 30, 60, and 120 FPS |
| Windows | **BLOCKED**: Flutter requires a Windows host | **PARTIAL**: shared keyboard tests pass; no Windows runtime test | **PARTIAL**: shared controller tests pass; no Windows backend or audible-output test | Generated runner inspected only; resize and fullscreen were not run |
| macOS | **BLOCKED**: full Xcode is missing | **PARTIAL**: shared keyboard tests pass; no macOS app runtime test | **PARTIAL**: shared controller tests pass; no macOS backend or audible-output test | macOS 26.6.2 host, but only Command Line Tools are selected |
| Linux | **BLOCKED**: Flutter requires a Linux host | **PARTIAL**: shared keyboard tests pass; no Linux runtime test | **PARTIAL**: shared controller tests pass; no Linux backend or audible-output test | Generated GTK runner inspected only |

This verification does **not** establish all six targets as release-ready. The
successful build targets in this environment are Android and web. The open
platform-specific gaps are listed below instead of being counted as passing.

## Continuous integration build matrix

GitHub Actions runs the `dart-builds` matrix on native hosted runners for each
target: Android and web on Ubuntu, Linux on Ubuntu with the GTK build
dependencies, Windows on Windows, and macOS plus an unsigned,
simulator-compatible iOS build on macOS. This removes the local-host limitation
from compile verification without turning a successful build into a runtime
claim.

Every matrix job writes the following boundary to its workflow summary so it is
visible with the result: Android builds are debug APK compile checks; web and
desktop builds do not exercise deployed or interactive applications; and the
iOS build is unsigned and simulator-compatible rather than a physical-device
or signing verification. Device installation, touch/keyboard behavior,
lifecycle behavior, resize behavior, and audible output remain covered by the
targeted automated tests and the native-host/manual work recorded below.

## Verification host and toolchains

- Host: Intel macOS 26.6.2, build 25G83, Darwin 25.6.0, `x86_64`.
- Flutter: 3.47.1 stable, framework revision `6655482ec0`, engine revision
  `5d53178869`.
- Dart: 3.13.1 stable (`macos_x64`); DevTools 2.60.0.
- Chrome: 152.0.7977.65.
- Java: OpenJDK 25.0.2.
- Android SDK: 36.0.0; Build Tools 36.0.0; Android Gradle Plugin 9.1.0;
  Kotlin plugin 2.4.0; Gradle 9.3.1.
- Android native tools: NDK 28.2.13676358 (r28c), CMake
  3.22.1-g37088a8, ADB 1.0.41 / 37.0.1-15733141, emulator 37.1.11.0.
- Android runtime: Pixel 9 Pro AVD, Android API 35, Google Play `x86_64`
  system image.
- Apple tools: Apple clang 21.0.0 is available from Command Line Tools.
  `xcode-select -p` returns `/Library/Developer/CommandLineTools`; full Xcode
  and CocoaPods are absent.
- Windows toolchain: not available on this macOS host.
- Linux toolchain: not available on this macOS host. Host `cmake` is absent;
  the CMake version above is the Android SDK copy.

The inventory commands were:

```sh
flutter --version
dart --version
flutter doctor -v
flutter devices
flutter emulators
java -version
xcode-select -p
xcodebuild -version
pod --version
clang --version
```

Locked dependencies were restored successfully with:

```sh
flutter pub get --enforce-lockfile
```

`flutter doctor -v` also reports that Android command-line tools are missing
and cannot determine the global license status. Gradle nevertheless accepted
the required component licenses and completed both APK builds. The first build
found an incomplete 161-byte NDK installation stub; it was moved to
`/private/tmp/toy-racers-incomplete-ndk-28.2.13676358`, after which Gradle
installed the complete pinned NDK, SDK Platform 36 revision 2, and CMake.

## Shared automated behavior evidence

The native Flutter test runtime passed 50 input, audio, lifecycle, responsive
layout, Flame adapter, and fixed-timestep tests:

```sh
flutter test test/player_input_adapter_test.dart \
  test/flame_game_adapter_test.dart \
  test/audio_smoke_test.dart \
  test/application_test.dart
```

Focused AI seed tests also pass. These include the regression for folding
signed 64-bit seed words without a JavaScript-inexact integer literal:

```sh
flutter analyze --fatal-infos \
  lib/simulation/ai/reference_ai_driver.dart test/ai_driver_test.dart
flutter test test/ai_driver_test.dart
flutter test --platform chrome test/ai_driver_test.dart
```

The following isolated Chrome runs pass and provide the web-specific evidence
used in the matrix:

```sh
flutter test --platform chrome test/player_input_adapter_test.dart

flutter test --platform chrome test/flame_game_adapter_test.dart \
  --name 'keyboard|touch|fixed timestep|identical tick inputs|bounded frame spike|pause drops'

flutter test --platform chrome test/audio_smoke_test.dart
flutter test --platform chrome test/application_test.dart
```

Results were respectively 4/4, 11/11, 15/15, and 6/6. Relevant assertions
cover:

- `WASD`/arrow driving, Escape pause, and `R` restart;
- simultaneous touch steering and pedals plus touch pause/restart callbacks;
- browser playback deferred until a semantic user gesture and browser preload
  disabled;
- ordered audio lifecycle pause/resume transitions;
- keyboard menu activation and layouts at 800x600 and 640x360;
- identical simulation results from 30, 60, and 120 FPS render deltas, bounded
  frame-spike input ordering, and discarded accumulated time across pause.

One broader browser command is not a pass:

```sh
flutter test --platform chrome \
  test/player_input_adapter_test.dart \
  test/flame_game_adapter_test.dart \
  test/audio_smoke_test.dart \
  test/application_test.dart
```

It passed 27 tests and then hung in `loads the bundled default session into a
Flame GameWidget`. It was interrupted after 2 minutes 28 seconds; the two later
test files lost their browser connection. The isolated behavior suites above
were used so this test-harness hang could not be mistaken for a pass.

## Android

### Build

Both requested APK commands pass:

```sh
flutter build apk --debug
flutter build apk --release
```

- Debug: `build/app/outputs/flutter-apk/app-debug.apk` (approximately 164 MiB).
- Release: `build/app/outputs/flutter-apk/app-release.apk` (61.1 MB as reported
  by Flutter).
- The release build uses the debug signing key configured in
  `android/app/build.gradle.kts`; it is a release-mode verification artifact,
  not a production-signed distribution APK.

### Runtime evidence and gaps

The emulator was started headlessly and the APK was installed and launched
with:

```sh
/Users/maksimandronov/Library/Android/sdk/emulator/emulator \
  -avd Pixel_9_Pro_API_35 -no-window -no-audio \
  -no-snapshot-load -no-boot-anim
/Users/maksimandronov/Library/Android/sdk/platform-tools/adb wait-for-device
/Users/maksimandronov/Library/Android/sdk/platform-tools/adb install -r \
  build/app/outputs/flutter-apk/app-debug.apk
/Users/maksimandronov/Library/Android/sdk/platform-tools/adb shell am start -W \
  -n com.example.toy_racers/.MainActivity
/Users/maksimandronov/Library/Android/sdk/platform-tools/adb shell \
  dumpsys activity activities
/Users/maksimandronov/Library/Android/sdk/platform-tools/adb shell \
  dumpsys window displays
```

Android reported the activity as top-resumed and visible in a fullscreen task.
Its configuration was `land`, bounds `2856x1280`,
`mDisplayRotation=ROTATION_90`, with orientation source
`SCREEN_ORIENTATION_SENSOR_LANDSCAPE`. This agrees with both the Flutter
landscape preference and Android `sensorLandscape` manifest declaration.

After launch, the headless AVD consumed approximately four CPU cores and
stopped completing ADB shell commands. Screenshot/accessibility capture, touch
injection, Home/background, resume, and audio-session inspection could not be
completed. Therefore touch and lifecycle are supported by passing shared tests,
but are not marked as Android runtime passes. The emulator was also launched
with `-no-audio`, so no audible-output claim is made. Repeat those checks on a
responsive emulator or physical device with an audio output before release.

## iOS

The simulator-compatible unsigned attempt was:

```sh
flutter build ios --simulator --debug
```

It failed with `Application not configured for iOS` before Xcode compilation.
The checked-in `.metadata` and `ios/` project do list iOS, but this host selects
Command Line Tools instead of full Xcode. `xcodebuild -version` reports that
full Xcode is required, `flutter doctor -v` calls the Xcode installation
incomplete, and CocoaPods is not installed.

No iOS simulator/device could be launched. Touch, audio backend behavior, and
OS lifecycle pause/resume therefore remain unverified on iOS; only the shared
Flutter touch/audio/lifecycle tests pass.

## Web

The final production build passes:

```sh
flutter build web --release
```

It produces `build/web` (approximately 55 MiB). Flutter also reports a
successful Wasm dry run. An initial dart2js attempt found a real portability
bug: `0xffffffffffffffff` in the AI seed fold was not exactly representable as
a JavaScript integer. The fold now uses `BigInt`, and both native and Chrome
regression tests pass before the successful final build.

Keyboard input, responsive widget layout, browser audio restrictions, and
fixed-step independence from the browser render cadence pass in Chrome 152 via
the isolated commands above. Limitations:

- resize verification changes the Flutter test surface to 800x600 and 640x360;
  an interactive drag of a deployed browser window was not performed;
- audio verification uses a recording backend, so real browser decoding and
  audible output remain manual checks;
- the full browser `GameWidget` test has the documented hang even though the
  release build and isolated tests pass.

## Windows

The exact build attempt was:

```sh
flutter build windows --release
```

Flutter rejected it with `"build windows" only supported on Windows hosts.`
The shared keyboard and audio-controller tests pass, but there is no Windows
build, runtime, backend-output, or resize result from this host.

The generated runner creates a resizable `WS_OVERLAPPEDWINDOW` and resizes the
Flutter child on `WM_SIZE`, but source inspection is not a runtime pass. No
application-specific fullscreen toggle is implemented; maximize is not being
treated as fullscreen. Windows resize and fullscreen behavior must be tested
on Windows, and a fullscreen requirement needs a separate product decision or
implementation if true borderless fullscreen is expected.

## macOS

The exact build attempt was:

```sh
flutter build macos --release
```

It failed when `xcrun` could not find `xcodebuild` because full Xcode is not
installed. The shared keyboard and audio-controller tests pass, but no macOS
app bundle, keyboard runtime, Darwin audio backend, or audible output was
verified.

## Linux

The exact build attempt was:

```sh
flutter build linux --release
```

Flutter rejected it with `"build linux" only supported on Linux hosts.` The
shared keyboard and audio-controller tests pass, but there is no Linux build,
GTK runtime, Linux audio backend, or audible-output result from this host.

## Required follow-up matrix

Run these checks on their native hosts before changing a `BLOCKED` or
`PARTIAL` cell to `PASS`:

- Android: repeat touch driving, OS background/resume during a race, and
  audible menu/race/pause audio on a responsive emulator or physical device.
- iOS: install full Xcode and CocoaPods, run the simulator build, then verify
  touch, audio, and background/resume in an iOS simulator/device.
- Web: manually resize a served release build and verify decoded audio after
  the first user gesture; investigate the full `GameWidget` Chrome-test hang.
- Windows: build on Windows with the supported Visual Studio toolchain, then
  verify keyboard, audible audio, resize, and the intended fullscreen behavior.
- macOS: select a complete Xcode installation, build, and verify keyboard and
  audible audio.
- Linux: build on a Linux host with Flutter desktop prerequisites, then verify
  keyboard and audible audio under the supported display/audio stack.

The detailed manual audio sequence is maintained in
`../../docs/AUDIO_SMOKE_TESTS.md`.

## Final repository gates

The final source and documentation were checked with:

```sh
# From dart/
flutter analyze --fatal-infos
flutter test

# From the repository root
./gradlew qualityCheck
./gradlew test
./gradlew lwjgl3:run
./gradlew android:assembleDebug
```

Analysis passed with no issues, `flutter test` passed all 229 tests,
`qualityCheck`, Gradle `test`, and the legacy Android debug assembly passed.
`lwjgl3:run` launched the interactive legacy desktop game without console
errors and was then interrupted; it is not recorded as a completed automated
test.
