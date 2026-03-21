# PassRoot Vault

PassRoot Vault is a local-first secure vault app built with Flutter.

## Release Signing

Release artifacts are intentionally blocked unless real signing is configured.
Debug signing fallback is disabled.

### Android - Signed AAB

Use one of the following:

1. `android/key.properties` (local machine)
2. Environment variables (CI/CD)

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

Build:

```powershell
flutter build appbundle --release
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
- App lock is PIN-first by default.
- Encrypted backup/import is the recommended path.
- Plain JSON/CSV import is intentionally marked as advanced/high-risk.
