import java.util.Properties
import java.util.Base64
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun signingValue(propertyKey: String, envKey: String): String? {
    val fromProperties = keystoreProperties.getProperty(propertyKey)?.trim()
    if (!fromProperties.isNullOrEmpty()) {
        return fromProperties
    }
    val fromEnv = System.getenv(envKey)?.trim()
    return if (fromEnv.isNullOrEmpty()) null else fromEnv
}

fun resolveReleaseStoreFile(): File? {
    val configuredPath = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
    if (!configuredPath.isNullOrEmpty()) {
        val fromPath = file(configuredPath)
        if (!fromPath.exists()) {
            throw GradleException(
                "Configured keystore file was not found: $configuredPath"
            )
        }
        return fromPath
    }

    val base64Keystore = System.getenv("ANDROID_KEYSTORE_BASE64")?.trim()
    if (base64Keystore.isNullOrEmpty()) {
        return null
    }

    val extension = System.getenv("ANDROID_KEYSTORE_EXT")?.trim()
        ?.ifEmpty { "jks" } ?: "jks"
    val outputDir = rootProject.layout.buildDirectory
        .dir("ci-signing")
        .get()
        .asFile
    val outputFile = File(outputDir, "release.$extension")
    outputDir.mkdirs()

    return try {
        outputFile.writeBytes(Base64.getDecoder().decode(base64Keystore))
        outputFile
    } catch (_: IllegalArgumentException) {
        throw GradleException(
            "ANDROID_KEYSTORE_BASE64 is not a valid base64 string."
        )
    }
}

val releaseStoreFile = resolveReleaseStoreFile()
val releaseStorePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
val hasReleaseSigning =
    releaseStoreFile != null &&
    releaseStorePassword != null &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

android {
    namespace = "app.passroot.vault"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "app.passroot.vault"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else if (releaseBuildRequested) {
                throw GradleException(
                    "Release signing is not configured. Provide android/key.properties or set env vars: " +
                        "ANDROID_KEYSTORE_PATH (or ANDROID_KEYSTORE_BASE64), " +
                        "ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
