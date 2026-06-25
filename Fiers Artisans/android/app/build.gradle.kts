plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.fiersartisans.fiers_artisans"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    val releaseKeystorePath = System.getenv("FIERS_RELEASE_KEYSTORE")
    val releaseKeystorePassword = System.getenv("FIERS_RELEASE_KEYSTORE_PASSWORD")
    val releaseKeyAlias = System.getenv("FIERS_RELEASE_KEY_ALIAS")
    val releaseKeyPassword = System.getenv("FIERS_RELEASE_KEY_PASSWORD")
    val releaseSigningReady = listOf(
        releaseKeystorePath,
        releaseKeystorePassword,
        releaseKeyAlias,
        releaseKeyPassword,
    ).all { !it.isNullOrBlank() }
    val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
        taskName.contains("Release", ignoreCase = true) ||
            taskName == "assemble" ||
            taskName.endsWith(":assemble") ||
            taskName == "build" ||
            taskName.endsWith(":build")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fiersartisans.fiers_artisans"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningReady) {
                signingConfig = signingConfigs.getByName("release")
            } else if (releaseTaskRequested) {
                throw org.gradle.api.GradleException(
                    "Release signing requires FIERS_RELEASE_KEYSTORE, " +
                        "FIERS_RELEASE_KEYSTORE_PASSWORD, FIERS_RELEASE_KEY_ALIAS, " +
                        "and FIERS_RELEASE_KEY_PASSWORD. Debug signing is never used for release.",
                )
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
