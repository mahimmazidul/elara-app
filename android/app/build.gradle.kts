import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material is read from android/key.properties, which is
// gitignored and written by CI from repository secrets. The raw keystore is
// never committed; only the decoded .jks from a secret exists, and only on the
// machine that builds the release.
//
// When the file is absent (a fresh clone, a debug-only build) the release build
// type falls back to the debug key so `flutter run --release` still works. A
// release produced without the file is therefore NOT distributable — the CI
// release workflow always writes the file first, and fails if the secret is
// missing.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.mahimmazidul.elara"
    // Pinned rather than taken from Flutter's default (36): the notification
    // plugin and the androidx.core it pulls in both compile against SDK 37, and
    // the AAR metadata check fails the release build against anything lower.
    // Compiling against a newer SDK is backward compatible; minSdk still decides
    // which devices can install the app.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 23 relies on Java 8+ APIs that are not
        // present on older Android versions; core library desugaring is required
        // for the plugin to build at all, not only for scheduled notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mahimmazidul.elara"
        // The spec asked for 21, but it cannot build: Flutter 3.47's default
        // minimum is 24, and flutter_local_notifications 23.0.0 declares
        // minSdk 24 itself, so the manifest merge would fail with
        // "minSdkVersion 21 cannot be smaller than version 24".
        minSdk = 24
        targetSdk = 34
        // Required alongside desugaring once the method count grows past the
        // single-dex limit on API 21-23 devices.
        multiDexEnabled = true
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile")!!)
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                // No key.properties: keep release builds runnable locally. CI
                // always provides the file, so shipped artifacts are real.
                signingConfigs.getByName("debug")
            }
            // Shrinking is left off deliberately: this release is the first
            // signed one and R8 rules for the notification plugin's
            // reflectively loaded receivers are not worth the risk yet.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
