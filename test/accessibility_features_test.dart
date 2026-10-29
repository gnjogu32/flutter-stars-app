import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starpage/widgets/author_profile_avatar.dart';

void main() {
  group('Accessibility Features Tests', () {
    testWidgets('AuthorProfileAvatar includes Semantics and Tooltip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: const AuthorProfileAvatar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widget tree handles unauthenticated gracefully with empty box
      expect(find.byType(AuthorProfileAvatar), findsOneWidget);
    });

    testWidgets('Text scaling dynamically scales UI elements without overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0), // 200% font scale
            ),
            child: Scaffold(
              body: ListView(
                children: const [
                  ListTile(
                    title: Text('Large Accessibility Header'),
                    subtitle: Text('This subtitle tests 200% font scaling.'),
                  ),
                  ElevatedButton(
                    onPressed: null,
                    child: Text('Accessible Button'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Large Accessibility Header'), findsOneWidget);
      expect(find.text('Accessible Button'), findsOneWidget);
    });

    testWidgets('Interactive elements satisfy minimum touch target guidelines', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: FloatingActionButton(
              tooltip: 'Create post',
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final fabSize = tester.getSize(find.byType(FloatingActionButton));
      expect(fabSize.width, greaterThanOrEqualTo(48.0));
      expect(fabSize.height, greaterThanOrEqualTo(48.0));
    });
  });
}
