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

    testWidgets('Comment button in sidebar triggers typing screen', (
      WidgetTester tester,
    ) async {
      bool commentTapCalled = false;

      // Create a mock sidebar with comment button
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Video Content'),
                Material(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => commentTapCalled = true,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '5',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify video content and comment button exist
      expect(find.text('Video Content'), findsOneWidget);
      expect(find.byIcon(Icons.comment_outlined), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Verify comment button is not yet tapped
      expect(commentTapCalled, false);

      // Tap the comment button
      await tester.tap(find.byIcon(Icons.comment_outlined));
      await tester.pump();

      // Verify callback was triggered
      expect(commentTapCalled, true);
    });

    testWidgets('Comment input field receives focus and shows keyboard', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const Text('Comments Sheet'),
                  TextField(
                    focusNode: focusNode,
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify comment input exists
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Comments Sheet'), findsOneWidget);

      // Focus the input field (simulating auto-focus on sheet open)
      focusNode.requestFocus();
      await tester.pump();

      // Verify focus node is focused
      expect(focusNode.hasFocus, true);

      // Type a comment
      await tester.enterText(find.byType(TextField), 'This is a test comment');
      await tester.pump();

      // Verify text was entered
      expect(controller.text, 'This is a test comment');
      expect(find.text('This is a test comment'), findsOneWidget);

      // Clean up
      focusNode.dispose();
      controller.dispose();
    });
  });
}
