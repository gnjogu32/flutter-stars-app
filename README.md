# flutter_stars_app

A new Flutter project.

## Modernized Android Build Toolchain

This project has been upgraded to use the latest Android build tools and SDKs. See [MAINTENANCE_WORKFLOW.md](./MAINTENANCE_WORKFLOW.md) for detailed technical maintenance instructions.

- **Android Gradle Plugin (AGP):** 9.2.1
- **Kotlin:** 2.1.10
- **Gradle:** 9.4.1
- **Target/Compile SDK:** 36
- **JVM Target:** 17 (Forced)
- **NDK Version:** 28.2.13676358 (Forced)

### Compatibility Notes

To maintain compatibility with current Flutter plugins (such as Firebase, sqflite, etc.) which may not yet support the modern AGP 9.0+ DSL or built-in Kotlin support, the following flags are set in `android/gradle.properties`:

- `android.newDsl=false`: Disables the mandatory modern DSL to prevent `NullPointerException` in the Flutter Gradle Plugin.
- `android.builtInKotlin=false`: Disables AGP's built-in Kotlin support to allow explicit application of the `kotlin-android` plugin.
- `android.suppressUnsupportedCompileSdk=36`: Required to allow building with the preview SDK 36.

Additionally, the NDK version is strictly enforced to `28.2.13676358` in the root `android/build.gradle.kts` using reflection. This ensures that all 24+ subprojects (including native plugins like `integration_test`) use the exact same NDK version, avoiding "NDK version mismatch" errors during the build.

## Branding & UX Enhancements

This project has been updated with a complete branding suite and optimized discovery features:

- **Professional Branding**: Custom launcher icons and a high-performance native splash screen.
- **Automated Discovery**: Session-stable "Automatic Shuffle" for video content (Reels), ensuring diverse talent exposure.
- **Unified Interactions**: A standardized interaction model across all video playback modes (Feed, Reels, and Fullscreen).
- **Social Connectivity**: Real-time unread badges for messages/notifications and deep-linked notification navigation.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
