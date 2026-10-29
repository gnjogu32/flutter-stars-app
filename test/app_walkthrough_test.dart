import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starpage/widgets/app_walkthrough.dart';

void main() {
  group('AppWalkthrough Tests', () {
    testWidgets('Walkthrough displays initial step correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppWalkthrough.show(
                      context,
                      onSelectTab: (_) {},
                      onCreatePost: () {},
                    );
                  },
                  child: const Text('Show Walkthrough'),
                );
              },
            ),
          ),
        ),
      );

      // Open walkthrough
      await tester.tap(find.text('Show Walkthrough'));
      await tester.pumpAndSettle();

      // Verify Header and Step 1 content
      expect(find.text('STARPAGE TOUR'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Welcome to Starpage'), findsOneWidget);
      expect(
        find.text(
          'Discover creative work, meet talented people, and share what you love.',
        ),
        findsOneWidget,
      );
      expect(find.text('Explore Home'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('Navigating through all steps with Next button', (
      WidgetTester tester,
    ) async {
      int selectedTab = -999;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppWalkthrough.show(
                      context,
                      onSelectTab: (index) => selectedTab = index,
                      onCreatePost: () {},
                    );
                  },
                  child: const Text('Show Walkthrough'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Walkthrough'));
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Short videos, your way'), findsOneWidget);
      expect(find.text('Explore Vistas'), findsOneWidget);

      // Step 2 -> Step 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Explore creators and talents'), findsOneWidget);
      expect(find.text('Open Discover'), findsOneWidget);

      // Step 3 -> Step 4
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Share a post'), findsOneWidget);

      // Step 4 -> Step 5
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Join the conversation'), findsOneWidget);
      expect(find.text('Start exploring'), findsOneWidget);

      // Finish walkthrough on final step
      await tester.tap(find.text('Start exploring'));
      await tester.pumpAndSettle();

      // Tab 0 should be selected on completion of step 5
      expect(selectedTab, 0);
      // Dialog should be dismissed
      expect(find.text('STARPAGE TOUR'), findsNothing);
    });

    testWidgets('Back button navigates to previous step', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppWalkthrough.show(
                      context,
                      onSelectTab: (_) {},
                      onCreatePost: () {},
                    );
                  },
                  child: const Text('Show Walkthrough'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Walkthrough'));
      await tester.pumpAndSettle();

      // Go to Step 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Short videos, your way'), findsOneWidget);

      // Press Back
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Starpage'), findsOneWidget);
    });

    testWidgets('Action button in step triggers direct tab navigation', (
      WidgetTester tester,
    ) async {
      int selectedTab = -999;
      bool createPostCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppWalkthrough.show(
                      context,
                      onSelectTab: (index) => selectedTab = index,
                      onCreatePost: () => createPostCalled = true,
                    );
                  },
                  child: const Text('Show Walkthrough'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Walkthrough'));
      await tester.pumpAndSettle();

      // Go to Step 2 ("Explore Vistas")
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Tap 'Explore Vistas'
      await tester.ensureVisible(find.text('Explore Vistas'));
      await tester.tap(find.text('Explore Vistas'));
      await tester.pumpAndSettle();

      expect(selectedTab, 1);
      expect(createPostCalled, isFalse);
      expect(find.text('STARPAGE TOUR'), findsNothing);
    });

    testWidgets('Create post action in step 4 triggers onCreatePost', (
      WidgetTester tester,
    ) async {
      int selectedTab = -999;
      bool createPostCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppWalkthrough.show(
                      context,
                      onSelectTab: (index) => selectedTab = index,
                      onCreatePost: () => createPostCalled = true,
                    );
                  },
                  child: const Text('Show Walkthrough'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Walkthrough'));
      await tester.pumpAndSettle();

      // Go to Step 4 ("Create a post")
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Share a post'), findsOneWidget);

      // Tap 'Create a post'
      await tester.ensureVisible(find.text('Create a post'));
      await tester.tap(find.text('Create a post'));
      await tester.pumpAndSettle();

      expect(createPostCalled, isTrue);
      expect(selectedTab, -999);
      expect(find.text('STARPAGE TOUR'), findsNothing);
    });

    testWidgets('Skip button dismisses walkthrough without action', (
      WidgetTester tester,
    ) async {
      int selectedTab = -999;
      bool createPostCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppWalkthrough.show(
                      context,
                      onSelectTab: (index) => selectedTab = index,
                      onCreatePost: () => createPostCalled = true,
                    );
                  },
                  child: const Text('Show Walkthrough'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Walkthrough'));
      await tester.pumpAndSettle();

      // Tap Skip
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('STARPAGE TOUR'), findsNothing);
      expect(selectedTab, -999);
      expect(createPostCalled, isFalse);
    });
  });
}
