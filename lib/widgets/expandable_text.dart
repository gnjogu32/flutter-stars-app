import 'package:flutter/material.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int trimLines;
  final TextStyle? actionStyle;

  const ExpandableText(
    this.text, {
    super.key,
    this.style,
    this.trimLines = 3,
    this.actionStyle,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final defaultActionStyle = Theme.of(context).textTheme.labelMedium
        ?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: widget.style),
          textDirection: TextDirection.ltr,
          maxLines: widget.trimLines,
        )..layout(maxWidth: constraints.maxWidth);

        final hasOverflow = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: widget.style,
              maxLines: _expanded ? null : widget.trimLines,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            if (hasOverflow)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
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
}
