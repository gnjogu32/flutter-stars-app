import 'package:flutter/material.dart';

class MentionUtils {
  MentionUtils._();

  static final RegExp _activeMentionPattern = RegExp(
    r'(^|\s)@([A-Za-z0-9._-]*)$',
    caseSensitive: false,
  );

  static String normalizeDisplayNameToHandle(String displayName) {
    return displayName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '');
  }

  static String? activeMentionQuery(String text, TextSelection selection) {
    final cursorOffset = selection.baseOffset;
    if (cursorOffset < 0 || cursorOffset > text.length) return null;

    final prefix = text.substring(0, cursorOffset);
    final match = _activeMentionPattern.firstMatch(prefix);
    if (match == null) return null;

    return match.group(2) ?? '';
  }

  static TextEditingValue insertMention({
    required String text,
    required TextSelection selection,
    required String handle,
  }) {
    final cursorOffset = selection.baseOffset;
    final prefix = text.substring(0, cursorOffset.clamp(0, text.length));
    final match = _activeMentionPattern.firstMatch(prefix);

    if (match == null) {
      return TextEditingValue(
        text: '$text@$handle ',
        selection: TextSelection.collapsed(
          offset: text.length + handle.length + 2,
        ),
      );
    }

    final leadingBoundaryLength = (match.group(1) ?? '').length;
    final mentionStart = match.start + leadingBoundaryLength;
    final replacement = '@$handle ';
    final updatedText = text.replaceRange(
      mentionStart,
      cursorOffset,
      replacement,
    );
    final updatedOffset = mentionStart + replacement.length;

    return TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: updatedOffset),
    );
  }
}
