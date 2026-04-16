import 'package:flutter_test/flutter_test.dart';
import 'package:starpage/main.dart' as app;

/// Helper class for test setup and utilities
class TestSetup {
  /// Initialize the app for testing
  static Future<void> initializeApp(WidgetTester tester) async {
    await tester.pumpWidget(const app.MyApp());
    await tester.pumpAndSettle();
  }

  /// Wait for widget to appear
  static Future<void> waitForWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await tester.pumpAndSettle(timeout);
    expect(finder, findsOneWidget);
  }

  /// Tap a button and wait for animation
  static Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}
