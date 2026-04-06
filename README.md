# PassRoot Vault

PassRoot Vault is a local-first secure vault app built with Flutter.

## Release Signing

Release artifacts are intentionally blocked unless real signing is configured.
Debug signing fallback is disabled.

### Android - Signed AAB

Use one of the following:

1. `android/key.properties` (local machine)
2. Gradle properties (`android/gradle.properties` or `~/.gradle/gradle.properties`)
3. Environment variables (CI/CD)

You can start from `android/key.properties.example`.

`android/key.properties` example:

```properties
storeFile=C:\\keys\\passroot-release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=passroot
keyPassword=YOUR_KEY_PASSWORD
```

CI/CD environment variables:

```bash
ANDROID_KEYSTORE_PATH=/path/to/passroot-release.jks
# or
ANDROID_KEYSTORE_BASE64=<base64-of-keystore>
ANDROID_KEYSTORE_EXT=jks

ANDROID_KEYSTORE_PASSWORD=...
ANDROID_KEY_ALIAS=...
ANDROID_KEY_PASSWORD=...
```

Gradle properties alternative:

```properties
passroot.release.storeFile=/absolute/path/to/passroot-release.jks
passroot.release.storePassword=...
passroot.release.keyAlias=passroot
passroot.release.keyPassword=...
```

Build:

```powershell
flutter build appbundle --release
```

## Optional Firebase Build Behavior

`android/app/google-services.json` is optional by default for local/debug builds.
If the file is missing, build continues and Firebase-dependent features stay disabled at runtime.

To enforce strict Firebase config in CI, set:

```properties
passroot.firebase.required=true
```

or environment variable:

```bash
PASSROOT_FIREBASE_REQUIRED=true
```

### iOS - Archive/TestFlight

Use Xcode signing (Apple Developer Program required):

1. Copy `ios/Flutter/ReleaseSecrets.xcconfig.example` to `ios/Flutter/ReleaseSecrets.xcconfig`
2. Set `APP_DEVELOPMENT_TEAM`
3. Open `ios/Runner.xcworkspace` in Xcode and confirm Signing & Capabilities
4. Build/archive:

```bash
flutter build ios --release
```

Then archive with Xcode Organizer for TestFlight upload.

## Security Notes

- Vault data is stored encrypted on device.
- Vault encryption is tied to master password; PIN/biometric are optional quick-unlock layers.
- Encrypted backup/import is the recommended path.
- Plain JSON/CSV import is intentionally marked as advanced/high-risk.
- Google account connection is identity-only right now; automatic cloud sync is not provided.
