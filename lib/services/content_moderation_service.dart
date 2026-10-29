import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

enum ModerationContentType { post, comment, user, message }

class ModerationResult {
  final bool isAllowed;
  final String? flaggedReason;
  final String sanitizedText;

  const ModerationResult({
    required this.isAllowed,
    this.flaggedReason,
    required this.sanitizedText,
  });
}

class ContentModerationService {
  static final ContentModerationService _instance =
      ContentModerationService._internal();
  factory ContentModerationService() => _instance;
  ContentModerationService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // Severe blocked keywords / terms pattern matching for automated content moderation
  static final List<RegExp> _blockedPatterns = [
    RegExp(r'\b(nigger|kike|chink|spic|faggot)\b', caseSensitive: false),
    RegExp(
      r'\b(kill\s+yourself|go\s+die|die\s+in\s+a\s+fire)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(free\s+crypto|send\s+btc\s+to|bitcoin\s+doubler)\b',
      caseSensitive: false,
    ),
  ];

  /// Perform automated text inspection before content publication
  ModerationResult validateTextContent(String text) {
    if (text.trim().isEmpty) {
      return ModerationResult(isAllowed: true, sanitizedText: text);
    }

    for (final pattern in _blockedPatterns) {
      if (pattern.hasMatch(text)) {
        return ModerationResult(
          isAllowed: false,
          flaggedReason:
              'Content contains prohibited text or harassment language.',
          sanitizedText: text,
        );
      }
    }

    return ModerationResult(isAllowed: true, sanitizedText: text);
  }

  /// Submit a formal content or user report ticket to Firestore
  Future<void> submitReport({
    required ModerationContentType contentType,
    required String targetId,
    required String targetAuthorId,
    required String reason,
    String? details,
  }) async {
    final reporterId = _auth.currentUser?.uid;
    if (reporterId == null) {
      throw StateError('Sign in before submitting a report.');
    }
    if (targetId.trim().isEmpty || targetAuthorId.trim().isEmpty) {
      throw ArgumentError('A report must identify its target and author.');
    }
    if (reason.trim().isEmpty || reason.length > 100) {
      throw ArgumentError('A valid report reason is required.');
    }
    final reportDetails = (details ?? '').trim();
    if (reportDetails.length > 1000) {
      throw ArgumentError('Report details must be 1,000 characters or fewer.');
    }

    final String reportId = _firestore.collection('reports').doc().id;

    await _firestore.collection('reports').doc(reportId).set({
      'reportId': reportId,
      'reporterId': reporterId,
      'contentType': contentType.name,
      'targetId': targetId.trim(),
      'targetAuthorId': targetAuthorId.trim(),
      'reason': reason,
      'details': reportDetails,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Displays standard report dialog with reason selection
  static Future<void> showReportDialog(
    BuildContext context, {
    required ModerationContentType contentType,
    required String targetId,
    required String targetAuthorId,
    String? targetAuthorName,
  }) async {
    String selectedReason = 'spam';
    final detailsController = TextEditingController();
    bool blockAuthor = false;

    final String titleText = switch (contentType) {
      ModerationContentType.post => 'Report Post',
      ModerationContentType.comment => 'Report Comment',
      ModerationContentType.user =>
        'Report User ${targetAuthorName != null ? "($targetAuthorName)" : ""}',
      ModerationContentType.message => 'Report Message',
    };

    final Map<String, String> reasonsMap = {
      'spam': 'Spam or misleading content',
      'harassment': 'Harassment or bullying',
      'hate_speech': 'Hate speech or discrimination',
      'explicit': 'Nudity or sexually explicit material',
      'violence': 'Violence or dangerous activity',
      'copyright': 'Intellectual property violation',
      'other': 'Other policy violation',
    };

    final String? currentUserId = () {
      try {
        return FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {
        return null;
      }
    }();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                titleText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Why are you reporting this?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...reasonsMap.entries.map((entry) {
                      final isSelected = entry.key == selectedReason;
                      return ListTile(
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 14),
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onTap: () {
                          setDialogState(() => selectedReason = entry.key);
                        },
                      );
                    }),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Additional details (optional)...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                    if (targetAuthorId.isNotEmpty &&
                        targetAuthorId != currentUserId) ...[
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: blockAuthor,
                        title: Text(
                          'Also block ${targetAuthorName ?? "this user"}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (val) {
                          setDialogState(() => blockAuthor = val ?? false);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('Submit Report'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && context.mounted) {
      try {
        await ContentModerationService().submitReport(
          contentType: contentType,
          targetId: targetId,
          targetAuthorId: targetAuthorId,
          reason: selectedReason,
          details: detailsController.text.trim(),
        );

        if (blockAuthor && targetAuthorId.isNotEmpty) {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          if (currentUserId != null) {
            await UserService().blockUser(currentUserId, targetAuthorId);
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                blockAuthor
                    ? 'Report submitted and user blocked. Thank you for keeping Starpage safe.'
                    : 'Report submitted. Thank you for keeping Starpage safe.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit report: $e')),
          );
        }
      }
    }
  }
}
