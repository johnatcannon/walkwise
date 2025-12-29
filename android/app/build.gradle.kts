import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    println("✅ Loaded key.properties from: ${keystorePropertiesFile.absolutePath}")
} else {
    println("⚠️ key.properties not found at: ${keystorePropertiesFile.absolutePath}")
}

android {
    namespace = "com.gowalkwise.walkwise"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.gowalkwise.walkwise"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26  // Required by health package
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists() && keystoreProperties.isNotEmpty()) {
            create("release") {
                val storeFileValue = keystoreProperties["storeFile"] as String
                val keystoreFile = file(storeFileValue)
                println("🔑 Release signing config:")
                println("   Key alias: ${keystoreProperties["keyAlias"]}")
                println("   Store file: ${keystoreProperties["storeFile"]}")
                println("   Keystore exists: ${keystoreFile.exists()}")
                println("   Keystore path: ${keystoreFile.absolutePath}")
                
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreFile
                storePassword = keystoreProperties["storePassword"] as String
            }
        } else {
            println("⚠️ Release signing config NOT created - using debug signing")
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists() && signingConfigs.findByName("release") != null) {
                signingConfig = signingConfigs.getByName("release")
                println("✅ Release build using release signing config")
            } else {
                signingConfig = signingConfigs.getByName("debug")
                println("⚠️ Release build using DEBUG signing config (fallback)")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
