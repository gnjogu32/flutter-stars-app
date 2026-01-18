@echo off
REM Automated Testing Verification Script for Windows
REM Run this to verify your testing setup is complete

echo.
echo 🔍 Automated Testing Setup Verification
echo ========================================
echo.

REM Check Flutter
echo ✓ Checking Flutter installation...
flutter --version >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✅ Flutter installed
    flutter --version
) else (
    echo   ❌ Flutter not found. Install from https://flutter.dev
    exit /b 1
)

echo.

REM Check Dart
echo ✓ Checking Dart installation...
dart --version >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✅ Dart installed
    dart --version
) else (
    echo   ❌ Dart not found
    exit /b 1
)

echo.

REM Check dependencies
echo ✓ Checking dependencies...
if exist pubspec.yaml (
    echo   ✅ pubspec.yaml found
) else (
    echo   ❌ pubspec.yaml not found
    exit /b 1
)

echo.

REM Check test files
echo ✓ Checking test files...
if exist test\widget_test.dart (
    echo   ✅ test\widget_test.dart exists
) else (
    echo   ❌ test\widget_test.dart not found
)

if exist integration_test\app_test.dart (
    echo   ✅ integration_test\app_test.dart exists
) else (
    echo   ❌ integration_test\app_test.dart not found
)

echo.

REM Check GitHub Actions workflows
echo ✓ Checking GitHub Actions workflows...
if exist .github\workflows\automated-testing.yml (
    echo   ✅ .github\workflows\automated-testing.yml exists
) else (
    echo   ⚠️  .github\workflows\automated-testing.yml not found
)

if exist .github\workflows\flutter-tests.yml (
    echo   ✅ .github\workflows\flutter-tests.yml exists
) else (
    echo   ⚠️  .github\workflows\flutter-tests.yml not found
)

if exist .github\workflows\android-test.yml (
    echo   ✅ .github\workflows\android-test.yml exists
) else (
    echo   ⚠️  .github\workflows\android-test.yml not found
)

echo.

REM Check documentation
echo ✓ Checking documentation...
if exist GITHUB_ACTIONS_TESTING_SETUP.md (
    echo   ✅ GITHUB_ACTIONS_TESTING_SETUP.md exists
) else (
    echo   ⚠️  GITHUB_ACTIONS_TESTING_SETUP.md not found
)

if exist AUTOMATED_TESTING_CHECKLIST.md (
    echo   ✅ AUTOMATED_TESTING_CHECKLIST.md exists
) else (
    echo   ⚠️  AUTOMATED_TESTING_CHECKLIST.md not found
)

if exist TEST_EXAMPLES.md (
    echo   ✅ TEST_EXAMPLES.md exists
) else (
    echo   ⚠️  TEST_EXAMPLES.md not found
)

if exist TESTING_QUICK_REFERENCE.md (
    echo   ✅ TESTING_QUICK_REFERENCE.md exists
) else (
    echo   ⚠️  TESTING_QUICK_REFERENCE.md not found
)

echo.

REM Check analysis options
echo ✓ Checking analysis configuration...
if exist analysis_options.yaml (
    echo   ✅ analysis_options.yaml exists
) else (
    echo   ⚠️  analysis_options.yaml not found
)

echo.
echo 🧪 Running Local Tests...
echo =========================
echo.

REM Get dependencies
echo Installing dependencies...
call flutter pub get

echo.

REM Run tests
echo Running tests...
call flutter test --verbose

if %errorlevel% equ 0 (
    echo.
    echo ✅ All tests passed!
) else (
    echo.
    echo ❌ Some tests failed. Review output above.
)

echo.
echo 📊 Generating Coverage Report...
echo ================================
call flutter test --coverage

if exist coverage\lcov.info (
    echo ✅ Coverage report generated: coverage\lcov.info
) else (
    echo ⚠️  Coverage report not found
)

echo.
echo ✨ Verification Complete!
echo =========================
echo.
echo Next steps:
echo 1. Push code to GitHub: git push origin main
echo 2. Check Actions tab for workflow results
echo 3. Monitor coverage on Codecov.io
echo.
echo For more details, see:
echo   - GITHUB_ACTIONS_TESTING_SETUP.md
echo   - TESTING_QUICK_REFERENCE.md
echo   - TEST_EXAMPLES.md
echo.
pause
