import java.util.Properties
import java.util.Base64
import org.gradle.api.GradleException
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun stringOrNull(value: String?): String? {
    val normalized = value?.trim()
    return if (normalized.isNullOrEmpty()) null else normalized
}

fun booleanFlag(value: String?, defaultValue: Boolean): Boolean {
    val normalized = value?.trim()?.lowercase()
    return when (normalized) {
        "1", "true", "yes", "on" -> true
        "0", "false", "no", "off" -> false
        null, "" -> defaultValue
        else -> defaultValue
    }
}

fun gradlePropOrNull(name: String): String? = stringOrNull(providers.gradleProperty(name).orNull)
fun envOrNull(name: String): String? = stringOrNull(System.getenv(name))

val firebaseRequired = booleanFlag(
    value = gradlePropOrNull("passroot.firebase.required") ?: envOrNull("PASSROOT_FIREBASE_REQUIRED"),
    defaultValue = false,
)
val hasGoogleServicesConfig = file("google-services.json").exists()
if (hasGoogleServicesConfig) {
    apply(plugin = "com.google.gms.google-services")
    logger.lifecycle("google-services.json detected; Firebase Gradle plugin enabled.")
} else if (firebaseRequired) {
    throw GradleException(
        "Firebase is marked as required but android/app/google-services.json is missing. " +
            "Add the file or set passroot.firebase.required=false (or PASSROOT_FIREBASE_REQUIRED=false) " +
            "for builds where Firebase is optional."
    )
} else {
    logger.lifecycle(
        "google-services.json not found under android/app; Firebase config dependent features will stay disabled."
    )
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
} else {
    logger.lifecycle(
        "android/key.properties not found. Release signing will use Gradle properties or environment variables."
    )
}

fun signingValue(propertyKey: String, envKey: String, gradleKey: String): String? {
    val fromProperties = stringOrNull(keystoreProperties.getProperty(propertyKey))
    if (fromProperties != null) {
        return fromProperties
    }
    val fromGradle = gradlePropOrNull(gradleKey)
    if (fromGradle != null) {
        return fromGradle
    }
    return envOrNull(envKey)
}

fun resolveReleaseStoreFile(): File? {
    val configuredPath = signingValue("storeFile", "ANDROID_KEYSTORE_PATH", "passroot.release.storeFile")
    if (configuredPath != null) {
        val fromPath = if (File(configuredPath).isAbsolute) {
            File(configuredPath)
        } else {
            rootProject.file(configuredPath)
        }
        if (!fromPath.exists()) {
            throw GradleException(
                "Configured keystore file was not found: $configuredPath"
            )
        }
        return fromPath
    }

    val base64Keystore =
        gradlePropOrNull("passroot.release.keystoreBase64") ?: envOrNull("ANDROID_KEYSTORE_BASE64")
    if (base64Keystore == null) {
        return null
    }

    val extension = gradlePropOrNull("passroot.release.keystoreExt")
        ?: envOrNull("ANDROID_KEYSTORE_EXT")
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
val releaseStorePassword =
    signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD", "passroot.release.storePassword")
val releaseKeyAlias =
    signingValue("keyAlias", "ANDROID_KEY_ALIAS", "passroot.release.keyAlias")
val releaseKeyPassword =
    signingValue("keyPassword", "ANDROID_KEY_PASSWORD", "passroot.release.keyPassword")
val missingSigningInputs = mutableListOf<String>()
if (releaseStoreFile == null) {
    missingSigningInputs.add("storeFile (key.properties) / passroot.release.storeFile / ANDROID_KEYSTORE_PATH / ANDROID_KEYSTORE_BASE64")
}
if (releaseStorePassword == null) {
    missingSigningInputs.add("storePassword (key.properties) / passroot.release.storePassword / ANDROID_KEYSTORE_PASSWORD")
}
if (releaseKeyAlias == null) {
    missingSigningInputs.add("keyAlias (key.properties) / passroot.release.keyAlias / ANDROID_KEY_ALIAS")
}
if (releaseKeyPassword == null) {
    missingSigningInputs.add("keyPassword (key.properties) / passroot.release.keyPassword / ANDROID_KEY_PASSWORD")
}
val hasReleaseSigning =
    missingSigningInputs.isEmpty()
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

android {
    namespace = "app.passroot.vault"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.passroot.vault"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("boolean", "PASSROOT_FIREBASE_CONFIGURED", hasGoogleServicesConfig.toString())
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
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }

        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else if (releaseBuildRequested) {
                throw GradleException(
                    "Release signing is not configured.\n" +
                        "Missing inputs:\n - ${missingSigningInputs.joinToString("\n - ")}\n\n" +
                        "Configure one of these:\n" +
                        "1) android/key.properties (recommended for local builds)\n" +
                        "2) Gradle properties (passroot.release.*)\n" +
                        "3) Environment variables (ANDROID_KEYSTORE_PATH or ANDROID_KEYSTORE_BASE64, " +
                        "ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD)."
                )
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
