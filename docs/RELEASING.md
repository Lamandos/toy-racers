# Android release process

GitHub builds and attaches a signed Android APK whenever a release whose tag starts with `v` is published.
The tag without the leading `v` must equal `versionName` in `android/build.gradle`.

## One-time signing setup

Create a dedicated upload key outside the repository:

```sh
keytool -genkeypair -v -keystore toy-racers-release.jks -alias toy-racers \
  -keyalg RSA -keysize 2048 -validity 10000
```

Store these repository Actions secrets:

- `RELEASE_KEYSTORE_BASE64`: base64-encoded contents of the keystore
- `RELEASE_KEYSTORE_PASSWORD`: keystore password
- `RELEASE_KEY_ALIAS`: key alias, for example `toy-racers`
- `RELEASE_KEY_PASSWORD`: key password

Keystores (`*.jks` and `*.keystore`) and local environment files are ignored by Git. Keep an encrypted backup of the
keystore and its credentials outside the repository; losing them prevents compatible updates to the Android app.

## Publish a version

1. Set `versionCode` and `versionName` in `android/build.gradle`.
2. Merge the version and workflow changes into `main`.
3. Create a tag such as `v0.1.0` on that commit and publish a GitHub Release for it.
4. Wait for the `Android release` workflow and test the APK attached to the Release on an Android device or emulator.

For a local signed build, export `TOY_RACERS_KEYSTORE_PATH`, `TOY_RACERS_KEYSTORE_PASSWORD`,
`TOY_RACERS_KEY_ALIAS`, and `TOY_RACERS_KEY_PASSWORD`, then run `./gradlew android:assembleRelease`.
