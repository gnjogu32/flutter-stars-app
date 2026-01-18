# Automated Testing Setup Checklist

## ✅ What's Already Done

- [x] Created main automated testing workflow (`automated-testing.yml`)
- [x] Existing test workflows configured (flutter-tests.yml, android-test.yml)
- [x] Unit test infrastructure in place
- [x] Integration test infrastructure in place
- [x] Test utilities created (test_setup.dart, test_config.dart)
- [x] Coverage reporting configured
- [x] Artifact archiving set up
- [x] PR comment automation ready

## 📋 Setup Checklist

### Step 1: Repository Configuration
- [ ] Go to GitHub repository Settings
- [ ] Navigate to "Actions" > "General"
- [ ] Ensure "Allow all actions and reusable workflows" is selected
- [ ] Go to "Secrets and variables" > "Actions"
- [ ] Verify no special secrets needed for basic testing

### Step 2: Enable Codecov (Optional but Recommended)
- [ ] Visit https://codecov.io
- [ ] Sign in with GitHub account
- [ ] Add/authorize this repository
- [ ] Enable coverage tracking
- [ ] Add codecov.yml to root (optional - auto-detection works)

### Step 3: Verify Git Configuration
- [ ] Ensure `main` and `develop` branches exist (or update workflow branches)
- [ ] Set branch protection rules:
  - [ ] Go to Settings > Branches
  - [ ] Click "Add rule"
  - [ ] Branch name pattern: `main`
  - [ ] Enable "Require status checks to pass before merging"
  - [ ] Select: "Unit & Widget Tests", "Code Analysis", "Build Test"

### Step 4: First Test Run
- [ ] Push code to repository: `git push origin main`
- [ ] Go to Actions tab in GitHub
- [ ] Watch "Automated Testing Suite" workflow run
- [ ] All jobs should complete successfully

### Step 5: Monitor Test Results
- [ ] Check job results
- [ ] Verify coverage report uploads to Codecov
- [ ] Download and inspect artifacts

## 🏃 Running Tests Locally

Before pushing, test locally:

```bash
# Install dependencies
flutter pub get

# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/widget_test.dart

# Run tests with verbose output
flutter test --verbose

# Run integration tests
flutter drive --target=integration_test/app_test.dart
```

## 📊 Understanding Test Results

### In GitHub Actions

1. **Test Summary**: Shows overall status (pass/fail/error)
2. **Job Logs**: Click job name to see detailed output
3. **Artifacts**: Download test results and APKs
4. **Coverage**: View on Codecov dashboard

### Coverage Reports

**Online**: Visit codecov.io to see:
- Overall coverage percentage
- File-by-file breakdown
- Trends over time
- Comparison with main branch

**Locally**: 
```bash
# Generate HTML coverage report
dart pub global activate coverage
dart pub global run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --out=coverage/lcov.info \
  --packages=.packages

# On Windows
# Use coverage\lcov.html in browser
```

## 🔧 Customization

### Change Test Trigger Events

Edit `.github/workflows/automated-testing.yml`:

```yaml
on:
  push:
    branches:
      - main
      - develop
      - 'release/**'  # Add release branches
  pull_request:
    branches:
      - main
```

### Adjust Flutter Version

In `automated-testing.yml`:
```yaml
env:
  FLUTTER_VERSION: '3.11.0'  # Change version
```

### Add Custom Test Directories

In `automated-testing.yml` code analysis:
```yaml
- name: Check code formatting
  run: dart format --set-exit-if-changed lib/ test/ integration_test/ custom_tests/
```

### Change Coverage Threshold

Create `codecov.yml` at repository root:
```yaml
coverage:
  precision: 2
  round: down
  range:
    - 70
    - 100
  status:
    project:
      default:
        target: 70%
        threshold: 5%
```

### Disable Specific Lints

Edit `analysis_options.yaml`:
```yaml
linter:
  rules:
    # Exclude rules
    - prefer_const_constructors: false
    - avoid_print: false
```

## 📈 Test Metrics to Track

- **Coverage %**: Aim for 70%+
- **Test Pass Rate**: Should be 100%
- **Build Time**: Monitor trends
- **Failure Rate**: Track over time

View on Codecov dashboard or GitHub insights.

## 🐛 Troubleshooting

### Workflow Not Running
- [ ] Check Actions tab is enabled in Settings
- [ ] Verify branch name matches workflow trigger (main/develop)
- [ ] Check for syntax errors: `yamllint .github/workflows/`

### Tests Fail on CI but Pass Locally
- [ ] Update Flutter: `flutter upgrade`
- [ ] Clean local cache: `flutter clean`
- [ ] Run: `flutter pub get && flutter test`
- [ ] Check Flutter version matches workflow

### Coverage Not Uploading
- [ ] Verify `coverage/lcov.info` exists after test runs
- [ ] Check Codecov has access to repository
- [ ] View workflow logs for errors
- [ ] For private repos, add Codecov token to secrets

### Build Test Fails
- [ ] Run locally: `flutter build apk --debug`
- [ ] Check `analysis_options.yaml` for strict settings
- [ ] Format code: `dart format lib/ test/`
- [ ] Analyze: `flutter analyze`

### Integration Tests Timeout
- [ ] May timeout on slow CI machines
- [ ] Check test logs for specific failures
- [ ] Consider increasing timeout:
  ```yaml
  timeout-minutes: 60  # Increase from 45
  ```

## 🔐 Security Considerations

- All workflows run on GitHub's infrastructure
- No secrets needed for basic testing
- Coverage uploads to Codecov (verify privacy settings)
- Build artifacts stored for 30 days (keep sensitive data out of code)

## 📚 Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter Testing Guide](https://flutter.dev/docs/testing)
- [Codecov Setup](https://docs.codecov.io/docs/quick-start)
- [Dart Analysis Options](https://dart.dev/guides/language/analysis-options)

## ✨ Next Steps

1. Run through the Setup Checklist above
2. Push code to trigger workflows
3. Monitor Actions tab for results
4. Adjust as needed based on feedback
5. Consider adding:
   - Performance testing
   - Security scanning
   - Custom test categories
   - Notification integrations

## 📝 Notes

- Workflows run in parallel for faster feedback
- Each test artifact retained for 30 days
- Pull requests get automatic test summary comments
- Failed tests prevent merging to main (if branch protection enabled)
