import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Load keystore properties if present (check app/key.properties then ../key.properties)
    val keystorePropertiesFile = file("key.properties").let { if (it.exists()) it else file("../key.properties") }
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }
    namespace = "com.example.my_app"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion = flutter.ndkVersion  // Commented out - NDK not required for this app

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
        freeCompilerArgs = listOf("-Xno-param-assertions", "-Xno-call-assertions", "-Xno-receiver-assertions")
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.my_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                // Resolve storeFile relative to app/ first, then fall back to parent android/ folder
                val storeFileProp = keystoreProperties.getProperty("storeFile")
                val candidate = file(storeFileProp)
                storeFile = if (candidate.exists()) candidate else file("../" + storeFileProp)
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Use release signing config if provided, otherwise fall back to debug signing.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            // Disable code shrinking temporarily to avoid R8/Metaspace OOM during build
            // (can be re-enabled once build environment memory issues are resolved)
            isMinifyEnabled = false
            isShrinkResources = false
            // Keep proguard files configured in case minification is re-enabled
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }

    // Reduce lint workload during CI/local builds to avoid running heavy lint analysis
    // which previously caused Metaspace OOM in the lint task.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}
