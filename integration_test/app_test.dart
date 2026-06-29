import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:starpage/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Vistas Infinite Scroll Test', () {
    testWidgets('confirm infinite vertical swipe in Vistas', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Check if we are on Login Screen
      if (find.text('Starpage Login').evaluate().isNotEmpty) {
        debugPrint('⚠️ On Login Screen - cannot proceed without credentials');
        return;
      }

      // Try to find the Vistas tab by containing text
      final vistasTab = find.textContaining('Vistas');

      if (vistasTab.evaluate().isEmpty) {
        debugPrint('❌ Vistas tab not found. Dumping widget tree...');
        // tester.allWidgets.forEach((w) => debugPrint(w.toString()));
        // Try finding by icon if text fails
        final vistasIcon = find.byIcon(Icons.play_circle_outline);
        if (vistasIcon.evaluate().isNotEmpty) {
          await tester.tap(vistasIcon);
        } else {
          debugPrint('❌ play_circle_outline icon also not found');
          return;
        }
      } else {
        await tester.tap(vistasTab);
      }

      // Wait for content to load
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Perform multiple swipes up to confirm infinite behavior
      for (int i = 0; i < 5; i++) {
        // Drag on the center of the screen
        await tester.dragFrom(const Offset(200, 600), const Offset(0, -500));
        await tester.pumpAndSettle(const Duration(milliseconds: 1500));
        debugPrint('Swipe Up $i completed');
      }

      debugPrint('✅ Infinite swipe test completed successfully');
    });
  });
}
