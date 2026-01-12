import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:starpage/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Starpage Integration Tests', () {
    setUpAll(() async {
      // Initialize app once for all tests
      app.main();
    });

    testWidgets('App launches and displays home screen', (
      WidgetTester tester,
    ) async {
      // Wait for app initialization
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app launched without errors
      expect(find.byType(MaterialApp), findsOneWidget);

      // Verify UI is responsive
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Material App is properly configured', (
      WidgetTester tester,
    ) async {
      // Verify Material Design is applied
      expect(find.byType(MaterialApp), findsOneWidget);

      // Find app title
      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
    });

    testWidgets('Authentication wrapper is rendered', (
      WidgetTester tester,
    ) async {
      // Wait for UI to settle
      await tester.pumpAndSettle();

      // Check if either login screen or main app is displayed
      final hasContent = find.byType(Scaffold).evaluate().isNotEmpty;
      expect(hasContent, true);
    });
  });
}
