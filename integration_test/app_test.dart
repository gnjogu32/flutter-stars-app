import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:starpage/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('verify app starts and shows home screen', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify that the app starts by checking for the 'Starpage' title in the AppBar
      expect(find.text('Starpage'), findsOneWidget);
    });
   group('navigation test', () {
    testWidgets('tap on reels tab', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Tap on the Reels tab (index 1)
      await tester.tap(find.text('Reels'));
      await tester.pumpAndSettle();

      // Verify we switched tabs (Reels screen has black background usually)
      // Since it's a stream, it might show a loader.
    });
  });
  });
}
