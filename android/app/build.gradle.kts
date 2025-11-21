plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.bg_service"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true // Correct property for Kotlin DSL
    }

    kotlinOptions {
        // Remove jvmTarget here to avoid mismatch; use JVM toolchain below
    }

    kotlin {
        jvmToolchain {
            languageVersion.set(JavaLanguageVersion.of(17))
        }
    }

    defaultConfig {
        applicationId = "com.example.bg_service"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing config for release build
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Use desugar_jdk_libs version 2.1.4 for compatibility with flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // other dependencies...
}
