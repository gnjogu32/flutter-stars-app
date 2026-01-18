# GitHub Actions Testing Automation Setup

This guide explains the automated testing workflows configured for this Flutter project.

## Quick Start

Once you push code or create a pull request, the testing workflows automatically run. No manual setup required after initial configuration.

## Workflows Overview

### 1. **Automated Testing Suite** (`automated-testing.yml`)

The main testing pipeline with 6 concurrent jobs:

#### Job: Unit & Widget Tests
- **Runs on**: Ubuntu (latest)
- **Duration**: ~15 minutes
- **What it does**:
  - Runs all unit and widget tests
  - Generates code coverage reports
  - Uploads coverage to Codecov
  - Stores test results as artifacts

**Coverage Report Access**:
- View online: https://codecov.io/gh/[your-username]/[repo-name]
- Download: Artifacts > unit-test-results > coverage/

#### Job: Integration Tests
- **Runs on**: Ubuntu (latest)
- **Duration**: ~20 minutes
- **What it does**:
  - Runs integration tests in headless mode
  - Tests app workflows end-to-end
  - Archives test results

#### Job: Code Analysis & Linting
- **Runs on**: Ubuntu (latest)
- **Duration**: ~10 minutes
- **What it does**:
  - Flutter analyze (finds issues)
  - Code formatting validation
  - Custom lint rules
  - Generates analysis reports

**Analysis Standards**:
- No fatal errors allowed
- Code must be properly formatted
- Follow Dart linting rules (defined in `analysis_options.yaml`)

#### Job: Build Test (Debug)
- **Runs on**: Ubuntu (latest)
- **Duration**: ~15 minutes
- **What it does**:
  - Builds debug APK
  - Verifies build artifacts
  - Stores APK for download

**Debug APK Download**:
- Available in: Artifacts > debug-apk

#### Job: Test Summary & Report
- **Runs on**: Ubuntu (latest)
- **Duration**: ~5 minutes
- **What it does**:
  - Aggregates all test results
  - Posts summary to pull requests
  - Creates artifacts for review

#### Job: Notify on Failures
- **Triggers**: Only if tests fail
- **What it does**:
  - Logs failure details
  - Provides action links

### 2. **Flutter Tests & Linting** (`flutter-tests.yml`)

Also runs on all pushes and PRs:
- Analyze & Lint (same as above)
- Unit & Widget Tests
- Web Build Test (verifies web platform builds)

### 3. **Android Emulator Tests** (`android-test.yml`)

Runs Android-specific tests:
- Integration tests on Android emulator
- Multiple API levels (28, 31, 33)
- Daily scheduled runs at 3 AM UTC
- Espresso unit tests

## Trigger Events

Tests automatically run on:

| Event | Branches | When |
|-------|----------|------|
| **Push** | main, develop, feature/* | Immediately |
| **Pull Request** | main, develop | When PR created/updated |
| **Schedule** | main | Daily at 2 AM UTC |

## Viewing Test Results

### From GitHub UI:
1. Go to repository > **Actions** tab
2. Select workflow run
3. View job logs and artifacts

### In Pull Requests:
- Test summary comment posted automatically
- Status checks show pass/fail
- Click "Details" for full logs

### Access Artifacts:
1. Click workflow run
2. Scroll to **Artifacts** section
3. Download desired artifacts

**Available Artifacts**:
- `unit-test-results` - Test & coverage files
- `integration-test-results` - Integration test output
- `analysis-report` - Code analysis results
- `debug-apk` - Compiled debug APK
- `test-summary` - Test summary markdown

## Configuration

### Flutter Version
Currently: `3.10.4`

To update:
```yaml
env:
  FLUTTER_VERSION: '3.10.5'  # Change version here
```

### Adding More Tests

Create test files in:
- `test/` - Unit & widget tests
- `integration_test/` - End-to-end tests

Example test file: `test/widgets/home_page_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:starpage/main.dart';

void main() {
  group('HomePage Widget Tests', () {
    testWidgets('HomePage renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      expect(find.byType(MyApp), findsOneWidget);
    });
  });
}
```

### Coverage Thresholds

To set minimum coverage requirements, modify workflow:
```yaml
- name: Check coverage threshold
  run: |
    COVERAGE=$(cat coverage/lcov.info | grep "^end_record" | wc -l)
    if [ $COVERAGE -lt 70 ]; then
      echo "Coverage below 70%"
      exit 1
    fi
```

### Codecov Integration

Coverage reports are automatically uploaded to [Codecov](https://codecov.io).

To view:
1. Visit https://codecov.io
2. Connect your GitHub account
3. Select this repository

## Troubleshooting

### Tests Fail Locally but Pass on CI
- Check Flutter version: `flutter --version`
- Ensure dependencies: `flutter pub get`
- Clear cache: `flutter clean && flutter pub get`

### Coverage Not Uploading
- Verify `coverage/lcov.info` exists
- Check Codecov token (usually automatic for public repos)
- View workflow logs for errors

### Build Tests Fail
- Check `analysis_options.yaml` for strict settings
- Run locally: `flutter analyze`
- Format code: `dart format lib/ test/`

### Integration Tests Timeout
- May be normal for slow CI machines
- Check individual test logs
- Consider increasing timeout in workflow

## Environment Variables & Secrets

### Required (Already set in workflows):
- `FLUTTER_VERSION` - Flutter SDK version

### Optional (Add to GitHub Secrets if needed):
- Custom API keys for services
- Firebase configuration (if not in pubspec.yaml)
- Notification webhooks

To add secrets:
1. Repository > Settings > Secrets and variables > Actions
2. Click "New repository secret"
3. Add secret name and value

## Performance Tips

1. **Parallel Execution**: All jobs run simultaneously (faster feedback)
2. **Caching**: Flutter dependencies cached between runs
3. **Artifacts**: Kept for 30 days (balance: storage vs. history)

## Next Steps

1. ✅ Workflows are configured
2. Push code to test them
3. Monitor results in Actions tab
4. Adjust as needed

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter Testing Guide](https://flutter.dev/docs/testing)
- [Codecov Documentation](https://docs.codecov.io/)
