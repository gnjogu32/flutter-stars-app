# Flutter APK Build & Firebase App Distribution Workflow

## Prerequisites
- Flutter and Dart SDK installed and in PATH
- Node.js and npm installed
- Firebase CLI installed globally (`npm install -g firebase-tools`)
- Firebase project and App Distribution set up
- `pubspec.yaml` dependencies up-to-date
- Remove any manual plugin registration lines from `GeneratedPluginRegistrant.java` for plugins like `firebase_storage`

## Workflow Steps

1. **Clean and Resolve Dependencies**
   ```powershell
   flutter clean
   flutter pub get
   ```
2. **Fix PATH for Firebase CLI (if needed)**
   ```powershell
   $env:Path += ";C:\Users\user\AppData\Roaming\npm"
   [Environment]::SetEnvironmentVariable('Path', $env:Path, [EnvironmentVariableTarget]::User)
   ```
3. **Build APK**
   ```powershell
   flutter build apk
   ```
4. **Distribute APK via Firebase App Distribution**
   ```powershell
   firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk --app <YOUR_FIREBASE_APP_ID> --groups "<YOUR_TESTER_GROUP>" --release-notes "Automated build upload via script."
   ```

## Automation Script Example

Create a PowerShell script `build_and_distribute.ps1`:

```powershell
flutter clean
flutter pub get
flutter build apk
$env:Path += ";C:\Users\user\AppData\Roaming\npm"
$APK_PATH = "build/app/outputs/flutter-apk/app-release.apk"
$APP_ID = "<YOUR_FIREBASE_APP_ID>"
$GROUPS = "<YOUR_TESTER_GROUP>"
$NOTES = "Automated build upload via script."
firebase appdistribution:distribute $APK_PATH --app $APP_ID --groups $GROUPS --release-notes $NOTES
```

## Troubleshooting
- If you see `firebase : The term 'firebase' is not recognized...`, ensure the npm global bin directory is in your PATH and restart your terminal.
- If you see plugin registration errors, remove manual plugin registration lines from `GeneratedPluginRegistrant.java`.
- For Kotlin version warnings, update your project to use a supported version as per Flutter's migration guide.

## References
- [Flutter Built-in Kotlin Migration Guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
- [Firebase App Distribution CLI Docs](https://firebase.google.com/docs/cli)
