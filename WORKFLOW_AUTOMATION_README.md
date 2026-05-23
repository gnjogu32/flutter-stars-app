# Permanent Flutter APK Build & Firebase App Distribution Workflow

This workflow is now validated and automated for your project. Use the following files and steps for future releases:

## 1. Workflow Documentation
See `WORKFLOW_AUTOMATION.md` for a step-by-step guide, troubleshooting, and references.

## 2. Automation Script
Use `build_and_distribute.ps1` to clean, build, and distribute your APK to Firebase testers. The script ensures PATH is set for the Firebase CLI and provides clear output for each step.

## 3. Maintenance
- Keep your dependencies up-to-date (`flutter pub upgrade`)
- Update `$APP_ID` and `$TESTER_GROUP` in the script as needed
- Remove any manual plugin registration lines from `GeneratedPluginRegistrant.java` if you add new plugins
- Upgrade your Kotlin version soon to avoid future build failures

---

This workflow is now saved and ready for permanent use in your project.
