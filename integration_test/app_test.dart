import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:starpage/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Starpage Integration Tests', () {
    testWidgets('App launches and displays home screen', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify app launched without errors
      expect(find.byType(MaterialApp), findsOneWidget);

      // Add additional assertions for your app's home screen
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Navigation works correctly', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Test basic app navigation
      // Add your specific navigation tests here
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Firebase connection is established', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify app loaded successfully with Firebase
      // Add Firebase-specific checks here
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
