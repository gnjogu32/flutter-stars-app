import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/post_model.dart';
import '../utils/constants.dart';

class ShareService {
  static String _postShareText(PostModel post) {
    final postUrl = AppConstants.postUrl(post.postId);
    return '''
Check out this post by ${post.authorName}${post.talent != null ? ' (${post.talent})' : ''}:

"${post.content}"

View on ${AppConstants.appName}: $postUrl''';
  }

  static Future<void> _shareText(String text, {String? subject}) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  /// Share post via native OS share dialog
  static Future<void> sharePost(PostModel post) async {
    await _shareText(
      _postShareText(post),
      subject: 'Post by ${post.authorName} on ${AppConstants.appName}',
    );
  }

  /// Open WhatsApp's share composer, falling back to the native share sheet.
  static Future<void> shareViaWhatsApp(PostModel post) async {
    final text = _postShareText(post);
    try {
      final uri = Uri.https('wa.me', '/', {'text': text});
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Fall through to the system share sheet if WhatsApp cannot be opened.
    }
    await _shareText(text);
  }

  /// Open X's post composer, falling back to the native share sheet.
  static Future<void> shareViaTwitter(PostModel post) async {
    final postUrl = AppConstants.postUrl(post.postId);
    final text =
        'Check out this post by ${post.authorName}: "${post.content}" on #${AppConstants.appName} ⭐ $postUrl';

    try {
      final uri = Uri.https('twitter.com', '/intent/tweet', {'text': text});
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Fall through to the system share sheet if X cannot be opened.
    }
    await _shareText(text);
  }

  /// Copy post link and summary to clipboard
  static Future<void> copyToClipboard(PostModel post) async {
    final postUrl = AppConstants.postUrl(post.postId);
    final text =
        '''
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
