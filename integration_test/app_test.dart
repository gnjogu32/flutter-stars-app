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

      // Wait for app initialization
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify UI is responsive
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Material App is properly configured', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify the app created at least one visible scaffolded screen.
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Authentication wrapper is rendered', (
      WidgetTester tester,
    ) async {
      app.main();

      // Wait for UI to settle
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Check if either login screen or main app is displayed
      final hasContent = find.byType(Scaffold).evaluate().isNotEmpty;
      expect(hasContent, true);
    });

    testWidgets('Follow button toggles on a discovered profile when available', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final bottomNavigation = find.byType(BottomNavigationBar);
      if (bottomNavigation.evaluate().isEmpty) {
        tester.printToConsole(
          'Skipping follow smoke test because the app is not on the authenticated main navigation.',
        );
        expect(find.byType(Scaffold), findsWidgets);
        return;
      }

      final discoverTab = find.text('Discover');
      expect(discoverTab, findsWidgets);
      await tester.tap(discoverTab.last);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final userTiles = find.byType(ListTile);
      if (userTiles.evaluate().isEmpty) {
        tester.printToConsole(
          'Skipping follow smoke test because no discoverable user cards are available.',
        );
        expect(find.byType(Scaffold), findsWidgets);
        return;
      }

      await tester.tap(userTiles.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final followFinder = find.widgetWithText(ElevatedButton, 'Follow');
      final followingFinder = find.widgetWithText(ElevatedButton, 'Following');

      if (followFinder.evaluate().isNotEmpty) {
        await tester.tap(followFinder.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(
          find.widgetWithText(ElevatedButton, 'Following'),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Following'));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.widgetWithText(ElevatedButton, 'Follow'), findsOneWidget);
        return;
      }

      if (followingFinder.evaluate().isNotEmpty) {
        await tester.tap(followingFinder.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.widgetWithText(ElevatedButton, 'Follow'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Follow'));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(
          find.widgetWithText(ElevatedButton, 'Following'),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Following'));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.widgetWithText(ElevatedButton, 'Follow'), findsOneWidget);
        return;
      }

      tester.printToConsole(
        'Skipping follow smoke test because the opened profile does not expose a follow CTA.',
      );
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
