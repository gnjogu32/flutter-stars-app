#!/bin/bash
# Automated Testing Verification Script
# Run this to verify your testing setup is complete

echo "🔍 Automated Testing Setup Verification"
echo "========================================"
echo ""

# Check Flutter
echo "✓ Checking Flutter installation..."
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n 1)
    echo "  ✅ Flutter installed: $FLUTTER_VERSION"
else
    echo "  ❌ Flutter not found. Install from https://flutter.dev"
    exit 1
fi

# Check Dart
echo "✓ Checking Dart installation..."
if command -v dart &> /dev/null; then
    DART_VERSION=$(dart --version)
    echo "  ✅ Dart installed: $DART_VERSION"
else
    echo "  ❌ Dart not found"
    exit 1
fi

# Check dependencies
echo "✓ Checking dependencies..."
if [ -f "pubspec.yaml" ]; then
    echo "  ✅ pubspec.yaml found"
else
    echo "  ❌ pubspec.yaml not found"
    exit 1
fi

# Check test files
echo "✓ Checking test files..."
if [ -f "test/widget_test.dart" ]; then
    echo "  ✅ test/widget_test.dart exists"
else
    echo "  ❌ test/widget_test.dart not found"
fi

if [ -f "integration_test/app_test.dart" ]; then
    echo "  ✅ integration_test/app_test.dart exists"
else
    echo "  ❌ integration_test/app_test.dart not found"
fi

# Check GitHub Actions workflows
echo "✓ Checking GitHub Actions workflows..."
WORKFLOWS=(
    ".github/workflows/automated-testing.yml"
    ".github/workflows/flutter-tests.yml"
    ".github/workflows/android-test.yml"
)

for workflow in "${WORKFLOWS[@]}"; do
    if [ -f "$workflow" ]; then
        echo "  ✅ $workflow exists"
    else
        echo "  ⚠️  $workflow not found"
    fi
done

# Check documentation
echo "✓ Checking documentation..."
DOCS=(
    "GITHUB_ACTIONS_TESTING_SETUP.md"
    "AUTOMATED_TESTING_CHECKLIST.md"
    "TEST_EXAMPLES.md"
    "TESTING_QUICK_REFERENCE.md"
)

for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        echo "  ✅ $doc exists"
    else
        echo "  ⚠️  $doc not found"
    fi
done

# Check analysis options
echo "✓ Checking analysis configuration..."
if [ -f "analysis_options.yaml" ]; then
    echo "  ✅ analysis_options.yaml exists"
else
    echo "  ⚠️  analysis_options.yaml not found"
fi

echo ""
echo "🧪 Running Local Tests..."
echo "========================="

# Get dependencies
echo "Installing dependencies..."
flutter pub get

# Run tests
echo ""
echo "Running tests..."
flutter test --verbose

TEST_EXIT=$?

if [ $TEST_EXIT -eq 0 ]; then
    echo ""
    echo "✅ All tests passed!"
else
    echo ""
    echo "❌ Some tests failed. Review output above."
fi

# Generate coverage
echo ""
echo "📊 Generating Coverage Report..."
echo "================================"
flutter test --coverage

if [ -f "coverage/lcov.info" ]; then
    echo "✅ Coverage report generated: coverage/lcov.info"
else
    echo "⚠️  Coverage report not found"
fi

echo ""
echo "✨ Verification Complete!"
echo "========================="
echo ""
echo "Next steps:"
echo "1. Push code to GitHub: git push origin main"
echo "2. Check Actions tab for workflow results"
echo "3. Monitor coverage on Codecov.io"
echo ""
echo "For more details, see:"
echo "  - GITHUB_ACTIONS_TESTING_SETUP.md"
echo "  - TESTING_QUICK_REFERENCE.md"
echo "  - TEST_EXAMPLES.md"
