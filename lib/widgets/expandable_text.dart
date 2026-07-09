import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/material.dart';
import '../screens/hashtag_feed_screen.dart';
import '../screens/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpandableText extends flutter.StatefulWidget {
  final String text;
  final flutter.TextStyle? style;
  final int trimLines;
  final flutter.TextStyle? actionStyle;
  final flutter.VoidCallback? onTap;

  const ExpandableText(
    this.text, {
    super.key,
    this.style,
    this.trimLines = 3,
    this.actionStyle,
    this.onTap,
  });

  @override
  flutter.State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends flutter.State<ExpandableText> {
  bool _expanded = false;

  @override
  flutter.Widget build(BuildContext context) {
    final text = widget.text.trim();
    if (text.isEmpty) {
      return const flutter.SizedBox.shrink();
    }

    final defaultActionStyle = flutter.Theme.of(context).textTheme.labelMedium
        ?.copyWith(
          color: flutter.Theme.of(context).colorScheme.primary,
          fontWeight: flutter.FontWeight.w600,
        );

    return flutter.LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = flutter.TextPainter(
          text: _buildTextSpan(text, widget.style, context),
          textDirection: flutter.TextDirection.ltr,
          maxLines: widget.trimLines,
        )..layout(maxWidth: constraints.maxWidth);

        final hasOverflow = textPainter.didExceedMaxLines;

        return flutter.Column(
          crossAxisAlignment: flutter.CrossAxisAlignment.start,
          children: [
            flutter.GestureDetector(
              onTap: widget.onTap,
              child: flutter.RichText(
                text: _buildTextSpan(text, widget.style, context, isExpanded: _expanded),
                maxLines: _expanded ? null : widget.trimLines,
                overflow: _expanded
                    ? flutter.TextOverflow.visible
                    : flutter.TextOverflow.ellipsis,
              ),
            ),
            if (hasOverflow)
              flutter.GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                behavior: flutter.HitTestBehavior.opaque,
                child: flutter.Padding(
                  padding: const flutter.EdgeInsets.only(top: 4),
                  child: flutter.Text(
                    _expanded ? 'See less' : 'See more',
                    style: widget.actionStyle ?? defaultActionStyle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  TextSpan _buildTextSpan(String text, TextStyle? style, BuildContext context, {bool isExpanded = false}) {
    final List<TextSpan> spans = [];
    final theme = Theme.of(context);
    final linkStyle = style?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
    ) ?? TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold);

    final RegExp combinedRegex = RegExp(r'(@\w+|#\w+)');
    int lastMatchEnd = 0;

    combinedRegex.allMatches(text).forEach((match) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }

      final String matchText = match.group(0)!;
      final bool isHashtag = matchText.startsWith('#');

      spans.add(TextSpan(
        text: matchText,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (isHashtag) {
              final tag = matchText.substring(1);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => HashtagFeedScreen(hashtag: tag),
                ),
              );
            } else {
              // Mention
              final username = matchText.substring(1).toLowerCase();
              _navigateToProfileByUsername(context, username);
            }
          },
      ));

      lastMatchEnd = match.end;
    });

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: style,
      ));
    }

    return TextSpan(children: spans);
  }

  Future<void> _navigateToProfileByUsername(BuildContext context, String username) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final userId = snap.docs.first.id;
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: userId),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User @$username not found')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
