import 'package:share_plus/share_plus.dart';
import '../models/post_model.dart';

class ShareService {
  /// Share post via native share dialog
  static Future<void> sharePost(PostModel post) async {
    final text =
        '''
Check out this post by ${post.authorName}${post.talent != null ? ' (${post.talent})' : ''}:

"${post.content}"

Shared from Starpage ⭐''';

    await Share.share(text);
  }

  /// Share post via WhatsApp
  static Future<void> shareViaWhatsApp(PostModel post) async {
    final text =
        '''
Check out this post by ${post.authorName}${post.talent != null ? ' (${post.talent})' : ''}:

"${post.content}"

Shared from Starpage ⭐''';

    try {
      await Share.share(text);
    } catch (e) {
      throw Exception('Failed to share via WhatsApp: $e');
    }
  }

  /// Share post via Twitter/X
  static Future<void> shareViaTwitter(PostModel post) async {
    final text =
        'Check out this post by ${post.authorName}: "${post.content}" #Starpage ⭐';
    
    try {
      await Share.share(text);
    } catch (e) {
      throw Exception('Failed to share via Twitter: $e');
    }
  }

  /// Copy post to clipboard
  static Future<void> copyToClipboard(PostModel post) async {
    final text =
        '''
${post.authorName}${post.talent != null ? ' (${post.talent})' : ''}

${post.content}

Shared from Starpage ⭐''';

    await Share.share(text);
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
