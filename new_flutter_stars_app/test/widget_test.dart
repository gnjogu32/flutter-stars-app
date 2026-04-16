import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('Basic widget test - MaterialApp creation', (
      WidgetTester tester,
    ) async {
      // Create a simple MaterialApp to test
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Test')),
            body: const Center(child: Text('Test Body')),
          ),
        ),
      );

      // Verify MaterialApp was created
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);
      expect(find.text('Test Body'), findsOneWidget);
    });

    testWidgets('Scaffold contains body widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Hello'),
                  SizedBox(height: 16),
                  Text('World'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('World'), findsOneWidget);
    });

    testWidgets('Button click triggers action', (WidgetTester tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => tapCount++,
                child: const Text('Tap Me'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tap Me'), findsOneWidget);
      expect(tapCount, 0);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(tapCount, 1);
    });
  });
}
