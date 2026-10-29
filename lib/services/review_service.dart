import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _keyActionCount = 'review_action_count';
  static const String _keyLastPromptTime = 'review_last_prompt_time';
  static const String _keyHasRated = 'review_has_rated';

  /// Increment action count when user performs a positive engagement (e.g. creating post, liking)
  Future<void> incrementActionCount() async {
    try {
      final String? countStr = await _storage.read(key: _keyActionCount);
      final int count = (int.tryParse(countStr ?? '0') ?? 0) + 1;
      await _storage.write(key: _keyActionCount, value: count.toString());
    } catch (_) {}
  }

  /// Check if eligible to automatically prompt for a review
  Future<bool> shouldPromptForReview() async {
    try {
      final String? hasRated = await _storage.read(key: _keyHasRated);
      if (hasRated == 'true') return false;

      final String? countStr = await _storage.read(key: _keyActionCount);
      final int count = int.tryParse(countStr ?? '0') ?? 0;
      if (count < 3) return false;

      final String? lastPromptStr = await _storage.read(key: _keyLastPromptTime);
      if (lastPromptStr != null) {
        final DateTime lastPrompt = DateTime.tryParse(lastPromptStr) ?? DateTime(2000);
        final Duration diff = DateTime.now().difference(lastPrompt);
        if (diff.inDays < 14) return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Trigger review prompt if conditions are met
  Future<void> promptReviewIfEligible(BuildContext context) async {
    final bool eligible = await shouldPromptForReview();
    if (eligible && context.mounted) {
      await showRatingDialog(context);
    }
  }

  /// Open native store listing directly
  Future<void> openStoreListing() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.openStoreListing(
          appStoreId: '1234567890', // Replace with iOS App Store ID when assigned
        );
      }
    } catch (e) {
      debugPrint('Error opening store listing: $e');
    }
  }

  /// Display custom Starpage Rating Dialog
  Future<void> showRatingDialog(BuildContext context) async {
    await _storage.write(
      key: _keyLastPromptTime,
      value: DateTime.now().toIso8601String(),
    );

    if (!context.mounted) return;

    int selectedStars = 0;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Column(
                children: [
                  Image.asset('assets/icon.png', height: 60, width: 60),
                  const SizedBox(height: 12),
                  const Text(
                    'Enjoying Starpage?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tap a star to rate your experience!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starRating = index + 1;
                      return IconButton(
                        iconSize: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        icon: Icon(
                          starRating <= selectedStars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: starRating <= selectedStars
                              ? Colors.amber
                              : Colors.grey.shade400,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedStars = starRating;
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                if (selectedStars == 0) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Not Now'),
                  ),
                ] else ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(dialogCtx);
                      if (selectedStars >= 4) {
                        // High rating -> prompt native review or store page
                        await _handlePositiveRating(context);
                      } else {
                        // Feedback rating -> collect user feedback
                        await _handleFeedbackRating(context, selectedStars);
                      }
                    },
                    child: Text(
                      selectedStars >= 4 ? 'Rate on Store' : 'Send Feedback',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  /// Handle positive rating (4-5 stars)
  Future<void> _handlePositiveRating(BuildContext context) async {
    await _storage.write(key: _keyHasRated, value: 'true');

    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      } else {
        await _inAppReview.openStoreListing();
      }
    } catch (_) {
      await openStoreListing();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for supporting Starpage! 🌟'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Handle constructive feedback rating (1-3 stars)
  Future<void> _handleFeedbackRating(
    BuildContext context,
    int rating,
  ) async {
    if (!context.mounted) return;

    final feedbackController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help Us Improve'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'We are sorry to hear that. What can we do to make Starpage better for you?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your feedback...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = feedbackController.text.trim();
              if (text.isNotEmpty) {
                try {
                  final userId = _auth.currentUser?.uid;
                  await _firestore.collection('feedback').add({
                    'userId': userId,
                    'rating': rating,
                    'feedback': text,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } catch (_) {}
              }

              await _storage.write(key: _keyHasRated, value: 'true');

              if (ctx.mounted) {
                Navigator.pop(ctx);
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Thank you for your feedback! We appreciate your help.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
