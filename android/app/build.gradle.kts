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

    // BuildConfig.DEBUG is used to gate the verification channel: the
    // channel that lets the Android verification ask the app to post a
    // notification, so the small icon can be seen in the status bar. It has
    // to exist only in a debug build, and BuildConfig has to be generated
    // for that to be possible. AGP 8 stopped generating it by default.
    buildFeatures {
        buildConfig = true
    }
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

        // FLAG_SECURE keeps this app out of the recents thumbnail, out of
        // screen recordings and out of `adb screencap`, because every screen is
        // a health record. That also blinds the screenshot pipeline in
        // tool/android_ui/, which captures the app with `adb exec-out
        // screencap`. The screenshot run builds with
        //   flutter build apk --debug --android-project-arg=elaraScreenshots=true
        // and this field is the only way to ask for a window that can be
        // captured. It defaults to false, so an unflagged build cannot be
        // screenshotted.
        buildConfigField(
            "boolean",
            "ALLOW_SCREEN_CAPTURE",
            project.hasProperty("elaraScreenshots").toString(),
        )

        // The spec asked for 21, but it cannot build: Flutter 3.47's default
        // minimum is 24, and flutter_local_notifications 23.0.0 declares
        // minSdk 24 itself, so the manifest merge would fail with
        // "minSdkVersion 21 cannot be smaller than version 24".
        minSdk = 24
        // Google Play refused every new app and every update below Android 16
        // (API 36) from 31 August 2026, so 34 was a build that could only ever
        // be sideloaded. Raising it turns on per-app language, predictive back,
        // enforced edge-to-edge (which this app already draws) and, importantly
        // here, stricter exact-alarm and foreground-service rules — which is
        // why the reminder scheduling has to be re-tested on a real API 36
        // device rather than assumed to survive the number change.
        targetSdk = 36
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
                // Play Protect verifies the signature scheme an APK carries.
                // Ship all three so a sideloaded install verifies on every
                // device that can install it: V1 for older installers, V2 for
                // Nougat+, V3 for P+.
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
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

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// This release ships no baseline profile, so nothing produces an ART profile
// to compile: disable those tasks by name before any plugin adds them, so a
// later AGP version cannot silently reintroduce them.
tasks.configureEach {
  if (name.startsWith("compile") && name.endsWith("ArtProfile")) enabled = false
}

configurations.configureEach {
  // AndroidX pulls ProfileInstaller in only to install baseline profiles at
  // startup. None are shipped, so exclude it everywhere Play Protect would
  // otherwise enumerate it.
  exclude(group = "androidx.profileinstaller", module = "profileinstaller")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
