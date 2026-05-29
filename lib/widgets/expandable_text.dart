import 'package:flutter/material.dart' as flutter;

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
  @override
  flutter.State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends flutter.State<ExpandableText> {
  bool _expanded = false;

  @override
  flutter.Widget build(flutter.BuildContext context) {
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
          text: flutter.TextSpan(text: text, style: widget.style),
          textDirection: flutter.TextDirection.ltr,
          maxLines: widget.trimLines,
        )..layout(maxWidth: constraints.maxWidth);

        final hasOverflow = textPainter.didExceedMaxLines;

        return flutter.Column(
          crossAxisAlignment: flutter.CrossAxisAlignment.start,
          children: [
            flutter.GestureDetector(
              onTap: widget.onTap,
              child: flutter.Text(
                text,
                style: widget.style,
                maxLines: _expanded ? null : widget.trimLines,
                overflow: _expanded
                    ? flutter.TextOverflow.visible
                    : flutter.TextOverflow.ellipsis,
              ),
            ),
            if (hasOverflow)
              flutter.GestureDetector(
                onTap: () {
                  if (widget.onTap != null) {
                    widget.onTap!();
                  } else {
                    setState(() => _expanded = !_expanded);
                  }
                },
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
}
