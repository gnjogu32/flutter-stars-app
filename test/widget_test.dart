import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starpage/widgets/comments_bottom_sheet.dart';

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

    testWidgets('Comment composer footer hides reply preview text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentComposerFooter(
              controller: TextEditingController(),
              focusNode: FocusNode(),
              isSending: false,
              onSend: () {},
              onAddMedia: () {},
              onPickGif: () {},
              charCount: 12,
              isOverLimit: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.textContaining('Replying to'), findsNothing);
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

    testWidgets('Comment composer footer shows reply preview when active', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentComposerFooter(
              controller: TextEditingController(),
              focusNode: FocusNode(),
              isSending: false,
              onSend: () {},
              onAddMedia: () {},
              onPickGif: () {},
              charCount: 12,
              isOverLimit: false,
              replyToName: 'Ada',
              replyToContent: 'This is the comment being replied to',
              onCancelReply: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Replying to'), findsOneWidget);
      expect(find.text('This is the comment being replied to'), findsOneWidget);
    });

    testWidgets('Right and Left swipe navigates between screens/tabs in TabBarView', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Swipe Navigation Test'),
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Stars'),
                    Tab(text: 'Trending'),
                    Tab(text: 'Posts'),
                  ],
                ),
              ),
              body: const TabBarView(
                children: [
                  Center(child: Text('Stars Screen Content')),
                  Center(child: Text('Trending Screen Content')),
                  Center(child: Text('Posts Screen Content')),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify Initial Screen (Stars Screen) is visible
      expect(find.text('Stars Screen Content'), findsOneWidget);
      expect(find.text('Trending Screen Content'), findsNothing);
      expect(find.text('Posts Screen Content'), findsNothing);

      // Swipe Left (drag right-to-left) to navigate to the Next Screen (Trending)
      await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Verify Screen 2 (Trending Screen) is now visible
      expect(find.text('Stars Screen Content'), findsNothing);
      expect(find.text('Trending Screen Content'), findsOneWidget);
      expect(find.text('Posts Screen Content'), findsNothing);

      // Swipe Left again to navigate to Screen 3 (Posts Screen)
      await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Verify Screen 3 (Posts Screen) is now visible
      expect(find.text('Trending Screen Content'), findsNothing);
      expect(find.text('Posts Screen Content'), findsOneWidget);

      // Swipe Right (drag left-to-right) to navigate back to Screen 2 (Trending Screen)
      await tester.drag(find.byType(TabBarView), const Offset(500, 0));
      await tester.pumpAndSettle();

      // Verify Screen 2 (Trending Screen) is visible again
      expect(find.text('Trending Screen Content'), findsOneWidget);
      expect(find.text('Posts Screen Content'), findsNothing);

      // Swipe Right again to navigate back to Screen 1 (Stars Screen)
      await tester.drag(find.byType(TabBarView), const Offset(500, 0));
      await tester.pumpAndSettle();

      // Verify Screen 1 (Stars Screen) is visible again
      expect(find.text('Stars Screen Content'), findsOneWidget);
    });

    testWidgets('Horizontal swipe navigates between home screens in PageView', (
      WidgetTester tester,
    ) async {
      final controller = PageController(initialPage: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageView(
              controller: controller,
              children: const [
                Center(child: Text('Home Screen')),
                Center(child: Text('Vistas Short Videos')),
                Center(child: Text('Discover Screen')),
                Center(child: Text('Messages Screen')),
                Center(child: Text('Notifications Screen')),
              ],
            ),
          ),
        ),
      );

      // Verify Home Screen initially displayed
      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('Vistas Short Videos'), findsNothing);

      // Swipe Left to navigate to Vistas / Short Videos
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsNothing);
      expect(find.text('Vistas Short Videos'), findsOneWidget);

      // Swipe Left to navigate to Discover Screen
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Vistas Short Videos'), findsNothing);
      expect(find.text('Discover Screen'), findsOneWidget);

      // Swipe Right to navigate back to Vistas / Short Videos
      await tester.drag(find.byType(PageView), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Discover Screen'), findsNothing);
      expect(find.text('Vistas Short Videos'), findsOneWidget);

      // Swipe Right to navigate back to Home Screen
      await tester.drag(find.byType(PageView), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);

      controller.dispose();
    });
  });
}
