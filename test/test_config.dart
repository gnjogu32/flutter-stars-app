/// Test configuration and best practices
///
/// Run tests with:
/// - `flutter test` - run all tests
/// - `flutter test --coverage` - with coverage report
/// - `flutter test test/widgets/` - specific directory
/// - `flutter test --verbose` - with detailed output

const String testFlutterVersion = '3.10.4';
const String testAndroidMinSdk = '21';
const String testAndroidTargetSdk = '33';

// Coverage thresholds
const double minCodeCoverage = 70.0;
const double minFunctionCoverage = 75.0;

// Timeout configurations
const Duration unitTestTimeout = Duration(seconds: 30);
const Duration integrationTestTimeout = Duration(seconds: 60);
const Duration widgetTestTimeout = Duration(seconds: 10);
