import java.util.Base64

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

fun dartDefine(name: String): String? {
    val encodedDefines = providers.gradleProperty("dart-defines").orNull
        ?.split(',')
        ?.filter { it.isNotBlank() }
        ?: return null
    return encodedDefines.firstNotNullOfOrNull { encoded ->
        runCatching {
            String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
        }.getOrNull()?.let { decoded ->
            val separatorIndex = decoded.indexOf('=')
            if (separatorIndex <= 0) {
                null
            } else {
                val key = decoded.substring(0, separatorIndex)
                val value = decoded.substring(separatorIndex + 1)
                if (key == name && value.isNotBlank()) value else null
            }
        }
    }
}

android {
    namespace = "com.kafeproje.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.kafeproje.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Google Maps SDK reads this from AndroidManifest metadata, so keep it
        // in sync with Flutter's --dart-define path as well as CI env vars.
        val googleMapsApiKey =
            dartDefine("GOOGLE_MAPS_API_KEY")
                ?: System.getenv("GOOGLE_MAPS_API_KEY")
                ?: "YOUR_GOOGLE_MAPS_API_KEY"
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*",
                "META-INF/*.kotlin_module",
            )
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
