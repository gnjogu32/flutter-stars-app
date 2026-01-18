# GitHub Actions Automated Testing - Quick Reference

## 🚀 Quick Start (30 seconds)

1. **Push to GitHub**: `git push origin main`
2. **Check Actions tab**: Go to your GitHub repo > Actions
3. **View results**: Click the running workflow
4. **Done!** ✅ Tests run automatically

## 📊 Workflows Summary

| Workflow | Trigger | Duration | Purpose |
|----------|---------|----------|---------|
| **Automated Testing Suite** | Push/PR/Schedule | ~35 min | Main testing pipeline |
| **Flutter Tests & Linting** | Push/PR | ~20 min | Code analysis + tests |
| **Android Emulator Tests** | Push/PR/Daily | ~30 min | Android integration tests |

## 🎯 What Gets Tested

- ✅ **Unit Tests** - Test individual functions
- ✅ **Widget Tests** - Test UI components
- ✅ **Integration Tests** - End-to-end app flows
- ✅ **Code Analysis** - Lint & formatting
- ✅ **Build Test** - APK compilation
- ✅ **Coverage Report** - Code coverage tracking

## 📁 Test File Locations

```
test/
├── widget_test.dart              ← Widget tests
├── test_setup.dart               ← Test utilities
└── test_config.dart              ← Test configuration

integration_test/
└── app_test.dart                 ← Integration tests
```

## 🔧 Local Testing Commands

```bash
# Run all tests
flutter test

# With coverage report
flutter test --coverage

# Verbose output
flutter test --verbose

# Specific test file
flutter test test/widget_test.dart

# Run integration tests
flutter drive --target=integration_test/app_test.dart
```

## 📈 Viewing Results

### GitHub UI:
1. Repository → **Actions** tab
2. Select workflow run
3. Click job to see logs
4. Download artifacts

### Coverage (Codecov):
1. Visit https://codecov.io
2. Select your repository
3. View coverage trends

### PR Comments:
- Test summary auto-posts to PRs
- Shows pass/fail status

## 🚨 Common Issues & Fixes

| Issue | Solution |
|-------|----------|
| **Workflow not running** | Check Actions enabled in Settings |
| **Tests fail on CI, pass locally** | Update Flutter: `flutter upgrade` |
| **Coverage not uploading** | Verify Codecov has repo access |
| **Build fails** | Run `flutter analyze` locally |
| **Timeout errors** | Increase `timeout-minutes` in workflow |

## 📝 Test Naming Convention

```dart
// Good ✅
testWidgets('Button navigates to home when tapped', ...)
test('User email validation rejects invalid format', ...)

// Avoid ❌
testWidgets('test1', ...)
test('validate', ...)
```

## 🎨 Coverage Targets

- **Minimum**: 70%
- **Good**: 80%+
- **Excellent**: 90%+

View on Codecov dashboard or locally:
```bash
cat coverage/lcov.info
```

## 📚 Key Files

| File | Purpose |
|------|---------|
| `.github/workflows/automated-testing.yml` | Main test workflow |
| `.github/workflows/flutter-tests.yml` | Code analysis workflow |
| `analysis_options.yaml` | Lint rules |
| `pubspec.yaml` | Dependencies & config |
| `GITHUB_ACTIONS_TESTING_SETUP.md` | Detailed setup guide |
| `AUTOMATED_TESTING_CHECKLIST.md` | Setup checklist |
| `TEST_EXAMPLES.md` | Example tests |

## ✨ Pro Tips

1. **Branch Protection**: Enable status checks on `main` branch to prevent merging failing tests
2. **Draft PRs**: Push to separate branch first, create PR to validate
3. **Local First**: Always run `flutter test` before pushing
4. **Monitor Trends**: Check Codecov for coverage over time
5. **Cache**: GitHub caches dependencies (faster subsequent runs)

## 🔐 Security Notes

- No secrets needed for basic testing
- Public repos: Codecov auto-detection works
- Private repos: Add Codecov token to secrets
- Build artifacts kept 30 days

## 📞 Support Resources

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Flutter Testing](https://flutter.dev/docs/testing)
- [Codecov Help](https://docs.codecov.io)
- [Dart Analyzer](https://dart.dev/guides/language/analysis-options)

## ✅ Checklist

- [ ] Workflows created and visible in Actions tab
- [ ] First test run completed successfully
- [ ] PR comment automation working
- [ ] Coverage data uploading to Codecov
- [ ] All tests passing
- [ ] Branch protection rules configured

---

**Last Updated**: January 18, 2026
**Status**: ✅ Ready to use
