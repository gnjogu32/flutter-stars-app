import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starpage/services/content_moderation_service.dart';

void main() {
  group('ContentModerationService Tests', () {
    final moderationService = ContentModerationService();

    test('Validates clean content as allowed', () {
      final result = moderationService.validateTextContent(
        'Welcome to Starpage! Enjoy sharing your creativity. 🌟',
      );
      expect(result.isAllowed, isTrue);
      expect(result.flaggedReason, isNull);
    });

    test('Flags offensive or harassment language', () {
      final result = moderationService.validateTextContent(
        'Go kill yourself right now',
      );
      expect(result.isAllowed, isFalse);
      expect(result.flaggedReason, contains('prohibited text'));
    });

    test('Flags crypto scam patterns', () {
      final result = moderationService.validateTextContent(
        'Get free crypto now, send btc to this address!',
      );
      expect(result.isAllowed, isFalse);
      expect(result.flaggedReason, isNotNull);
    });

    testWidgets('Report dialog renders reasons and submits selection', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ContentModerationService.showReportDialog(
                      context,
                      contentType: ModerationContentType.post,
                      targetId: 'post_123',
                      targetAuthorId: 'user_456',
                      targetAuthorName: 'Alice',
                    );
                  },
                  child: const Text('Report Post'),
                );
              },
            ),
          ),
        ),
      );

      // Open report dialog
      await tester.tap(find.text('Report Post'));
      await tester.pumpAndSettle();

      // Verify title and reasons
      expect(find.text('Report Post'), findsNWidgets(2));
      expect(find.text('Why are you reporting this?'), findsOneWidget);
      expect(find.text('Spam or misleading content'), findsOneWidget);
      expect(find.text('Harassment or bullying'), findsOneWidget);
      expect(find.text('Hate speech or discrimination'), findsOneWidget);
      expect(find.text('Nudity or sexually explicit material'), findsOneWidget);
      expect(find.text('Also block Alice'), findsOneWidget);

      // Select 'Harassment or bullying'
      await tester.tap(find.text('Harassment or bullying'));
      await tester.pumpAndSettle();

      // Enter details
      await tester.enterText(
        find.byType(TextField),
        'Offensive language in caption.',
      );
      await tester.pumpAndSettle();

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Why are you reporting this?'), findsNothing);
    });
  });
}
