import java.util.Properties
import org.gradle.api.JavaVersion
import org.gradle.api.tasks.Exec
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.appdistribution")
}

android {
    ndkVersion = "28.2.13676358"
    namespace = "com.starpage.app"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.starpage.app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }

    signingConfigs {
        create("release") {
            storeFile = file("release-keystore.jks")
            storePassword = "@starpageflutterstarsapplication2026#!?"
            keyAlias = "release"
            keyPassword = "@starpageflutterstarsapplication2026#!?"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            
            // Using configure to avoid import issues with the firebaseAppDistribution extension
            extensions.configure<com.google.firebase.appdistribution.gradle.AppDistributionExtension>("firebaseAppDistribution") {
                appId = "1:1071477545934:android:8725890938b29f9c738e4a"
                groups = "testers"
            }
        }
    }
}

tasks.withType<KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation(platform("com.google.firebase:firebase-bom:34.13.0"))
    implementation("com.google.firebase:firebase-analytics")
}

tasks.register<Exec>("testFlutter") {
    val properties = Properties()
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { 
            properties.load(it) 
        }
    }
    val flutterSdkPath = properties.getProperty("flutter.sdk")
    val flutterExecutable = if (flutterSdkPath != null) {
        file("$flutterSdkPath/bin/flutter.bat").absolutePath
    } else {
        "flutter"
    }

    commandLine("cmd", "/c", flutterExecutable, "--version")
}

flutter {
    source = "../.."
}
