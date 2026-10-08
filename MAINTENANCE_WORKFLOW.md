# Maintenance & Build Workflow

This document outlines the technical specifics of the modernized build toolchain used in this project and how to maintain it.

## Current Toolchain State

- **AGP:** 8.11.1
- **Kotlin Gradle Plugin:** 2.3.0
- **Gradle:** 8.14.3
- **Target/Compile SDK:** 36
- **JDK/JVM Target:** 17 (Strictly enforced)
- **NDK:** 28.2.13676358 (Strictly enforced)

## Core Build Logic

The Android project currently uses Groovy Gradle files: plugin versions are in `android/settings.gradle`, the wrapper version is in `android/gradle/wrapper/gradle-wrapper.properties`, and app settings are in `android/app/build.gradle`.

Flutter 3.44 runs with `android.builtInKotlin=false`; the app and some Flutter plugins still apply the Kotlin Gradle Plugin. Do not enable AGP 9 built-in Kotlin until Flutter and all Android plugins in the dependency graph have completed the migration. Java and Kotlin compilation target JVM 17.

The Play Store workflow can override the default version code with `-PplayStoreVersionCode=<code>`; ordinary local builds continue to use the fallback in `android/app/build.gradle`.

## Common Tasks

### Verify the Android release bundle

Use JDK 17 and run the Android Gradle task directly. The resulting bundle is written to `android/app/build/outputs/bundle/release/app-release.aab`.

```powershell
$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
cd android
.\gradlew.bat app:bundleRelease
```

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
