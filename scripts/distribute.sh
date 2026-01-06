#!/bin/bash
# Distribution script for macOS/Linux
# Distributes Flutter app via Firebase App Distribution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
APP_ID="${1:-}"
TESTERS="${2:-}"
RELEASE_NOTES="${3:-New build distribution}"
APK_PATH="${4:-build/app/outputs/flutter-apk/app-release.apk}"

# Functions
print_status() {
    echo -e "${GREEN}>>> $1${NC}"
}

print_error() {
    echo -e "${RED}!!! $1${NC}"
    exit 1
}

print_warning() {
    echo -e "${YELLOW}>>> $1${NC}"
}

print_info() {
    echo -e "${CYAN}>>> $1${NC}"
}

# Main script
print_info "Firebase App Distribution Helper"
print_info "================================"
echo ""

# Check parameters
if [ -z "$APP_ID" ]; then
    print_error "APP_ID is required"
fi

if [ -z "$TESTERS" ]; then
    print_error "TESTERS is required (comma-separated emails)"
fi

# Check APK exists
if [ ! -f "$APK_PATH" ]; then
    print_error "APK not found at: $APK_PATH"
fi

print_status "APK found: $APK_PATH"
APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
print_status "APK size: $APK_SIZE"

# Check Firebase CLI
if ! command -v firebase &> /dev/null; then
    print_error "Firebase CLI not found. Install with: npm install -g firebase-tools"
fi

FIREBASE_VERSION=$(firebase --version)
print_status "Firebase CLI version: $FIREBASE_VERSION"

# Verify authentication
print_status "Checking Firebase authentication..."
if ! firebase projects:list &> /dev/null; then
    print_error "Not authenticated with Firebase. Run: firebase login"
fi

print_status "Authentication verified"

# Distribution
print_warning "Starting distribution..."
print_info "App ID: $APP_ID"
print_info "Testers: $TESTERS"
print_info "Release Notes: $RELEASE_NOTES"
echo ""

firebase appdistribution:distribute "$APK_PATH" \
    --app="$APP_ID" \
    --release-notes="$RELEASE_NOTES" \
    --testers="$TESTERS"

if [ $? -eq 0 ]; then
    print_status "Distribution successful!"
    print_status "Testers will receive invitation emails shortly."
    print_status "Check Firebase Console for distribution status."
else
    print_error "Distribution failed. Check Firebase CLI output above."
fi
