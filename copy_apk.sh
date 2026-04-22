#!/usr/bin/env bash
# Script to copy the generated APK to a standard location after build

APK_SRC1="android/app/build/outputs/flutter-apk/app-release.apk"
APK_SRC2="android/app/build/outputs/apk/release/app-release.apk"
APK_DST="build/app-release-latest.apk"

if [ -f "$APK_SRC1" ]; then
  cp "$APK_SRC1" "$APK_DST"
  echo "Copied $APK_SRC1 to $APK_DST"
elif [ -f "$APK_SRC2" ]; then
  cp "$APK_SRC2" "$APK_DST"
  echo "Copied $APK_SRC2 to $APK_DST"
else
  echo "No APK found to copy."
  exit 1
fi
