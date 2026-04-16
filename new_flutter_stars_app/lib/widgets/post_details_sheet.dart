import 'package:flutter/material.dart';
import '../models/post_model.dart';
import 'expandable_text.dart';

class PostDetailsSheet extends StatelessWidget {
  final PostModel post;
  final ScrollController? scrollController;
  const PostDetailsSheet({
    super.key,
    required this.post,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                if (post.repostCaption != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Original post by [${post.originalAuthorName ?? 'Unknown'}]',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        ExpandableText(
                          post.content,
                          style: Theme.of(context).textTheme.bodySmall,
                          trimLines: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your caption:',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExpandableText(
                    post.repostCaption!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    trimLines: 5,
                  ),
                ] else ...[
                  ExpandableText(
                    post.content,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 16),
                    trimLines: 10,
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border, size: 28),
                        const SizedBox(width: 8),
                        Text('Like'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.comment_outlined, size: 28),
                        const SizedBox(width: 8),
                        Text('Comment'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.repeat, size: 28),
                        const SizedBox(width: 8),
                        Text('Repost'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share_outlined, size: 28),
                        const SizedBox(width: 8),
                        Text('Share'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
