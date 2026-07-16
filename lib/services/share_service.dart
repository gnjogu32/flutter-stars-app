import 'package:flutter/services.dart';
import '../models/post_model.dart';
import '../utils/constants.dart';

class ShareService {
  /// Share post via native share dialog
  static Future<void> sharePost(PostModel post) async {
    final postUrl = AppConstants.postUrl(post.postId);
    final text = '''
Check out this post by ${post.authorName}${post.talent != null ? ' (${post.talent})' : ''}:

"${post.content}"

View on ${AppConstants.appName}: $postUrl''';

    // Fallback to clipboard since share_plus is removed
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Share post via WhatsApp
  static Future<void> shareViaWhatsApp(PostModel post) async {
    final postUrl = AppConstants.postUrl(post.postId);
    final text = '''
Check out this post by ${post.authorName}${post.talent != null ? ' (${post.talent})' : ''}:

"${post.content}"

View on ${AppConstants.appName}: $postUrl''';

    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Share post via Twitter/X
  static Future<void> shareViaTwitter(PostModel post) async {
    final postUrl = AppConstants.postUrl(post.postId);
    final text = 'Check out this post by ${post.authorName}: "${post.content}" on #${AppConstants.appName} ⭐ $postUrl';

    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Copy post to clipboard
  static Future<void> copyToClipboard(PostModel post) async {
    final postUrl = AppConstants.postUrl(post.postId);
    final text = '''
${post.authorName}${post.talent != null ? ' (${post.talent})' : ''}

${post.content}

View on ${AppConstants.appName}: $postUrl''';

    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Get share statistics
  static String getShareText(PostModel post, {String? customMessage}) {
    return customMessage ??
        '''
Check out this trending post by ${post.authorName}${post.talent != null ? ' (${post.talent})' : ''}:

"${post.content}"

❤️ ${post.likeCount} likes • 💬 ${post.commentCount} comments

Shared from Starpage ⭐''';
  }
}
