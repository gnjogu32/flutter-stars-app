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
            val keystoreProperties = Properties()
            val keystorePropertiesFile = File(project.projectDir.parentFile, "key.properties")
            if (keystorePropertiesFile.exists()) {
                keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
            }

            keyAlias = project.findProperty("keyAlias") as String? ?: keystoreProperties.getProperty("keyAlias")
            keyPassword = project.findProperty("keyPassword") as String? ?: keystoreProperties.getProperty("keyPassword")
            storePassword = project.findProperty("storePassword") as String? ?: keystoreProperties.getProperty("storePassword")
            val storeFilePath = project.findProperty("storeFile") as String? ?: keystoreProperties.getProperty("storeFile")
            if (!storeFilePath.isNullOrBlank()) {
                storeFile = if (File(storeFilePath).isAbsolute) File(storeFilePath) else File(project.projectDir.parentFile, storeFilePath)
            }
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
                appId = "1:246255479274:android:177b790682bb5b59862a93"
                artifactPath = "${rootProject.projectDir.parentFile.path}/build/app/outputs/apk/release/app-release.apk"
                groups = "alpha"
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
