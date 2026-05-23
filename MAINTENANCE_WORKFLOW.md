# Maintenance & Build Workflow

This document outlines the technical specifics of the modernized build toolchain used in this project and how to maintain it.

## Current Toolchain State

- **AGP:** 9.2.1 (Experimental)
- **Kotlin:** 2.1.10
- **Gradle:** 9.4.1
- **Target/Compile SDK:** 36
- **JDK/JVM Target:** 17 (Strictly enforced)
- **NDK:** 28.2.13676358 (Strictly enforced)

## Core Build Logic

The project uses a highly customized root `android/build.gradle.kts` to bridge the gap between AGP 9.x assumptions and legacy Flutter plugins.

### 1. Forced Kotlin Plugin Application
Many plugins (e.g., `firebase_storage`, `file_picker`) detect AGP >= 9 and skip applying the `kotlin-android` plugin, assuming AGP's "Built-in Kotlin" will handle it. However, since we have `android.builtInKotlin=false` for broader compatibility, we must force the plugin application in the root build script:

```kotlin
allprojects {
    if (project.name != "android") {
        plugins.withId("com.android.library") {
            if (!project.plugins.hasPlugin("kotlin-android") && ...) {
                project.plugins.apply("kotlin-android")
            }
        }
    }
}
```

### 2. JVM 17 Enforcement
To prevent mismatches between Java and Kotlin compilation tasks, JVM 17 is enforced across all subprojects:

```kotlin
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
```

## Common Tasks

### Build Release APK
Use the standard Flutter command. The custom redirection ensures the artifact is placed in the root `build/` folder.
```powershell
flutter build apk --release
```

### Distribution to Testers
Ensure `JAVA_HOME` is set to the Android Studio JBR and run the Gradle task:
```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
cd android
.\gradlew :app:appDistributionUploadRelease
```

## VS Code Optimization

The `.vscode/settings.json` is configured to:
- Suppress "Incomplete Classpath" warnings from the Java Language Server.
- Point the Java runtime to the correct JBR (v17).
- Automatically import the `android/` sub-folder as a Gradle project root.

**If you see red underlines in native code that still builds successfully:**
Run the command `Java: Clean Language Server Workspace` from the Command Palette.
