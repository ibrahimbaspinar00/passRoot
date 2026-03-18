# passroot

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Android Release Signing

`android/app/build.gradle.kts` now reads signing values from `android/key.properties`.
If this file does not exist, release builds fallback to debug signing.

Create keystore:

```powershell
keytool -genkey -v -keystore C:\keys\passroot-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias passroot
```

Create `android/key.properties`:

```properties
storeFile=C:\\keys\\passroot-release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=passroot
keyPassword=YOUR_KEY_PASSWORD
```

Build signed release:

```powershell
flutter build appbundle --release
```
