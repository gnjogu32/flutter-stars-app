import 'package:flutter/material.dart';

/// Shows a login / sign-up prompt bottom-sheet when the user tries to perform
/// an action that requires authentication.
///
/// Returns `true` if the user successfully authenticated after the prompt,
/// `false` otherwise. Most callers can ignore the return value — they simply
/// bail out when the user is not logged in.
class AuthGuard {
  AuthGuard._();

  /// Show the prompt and return whether the navigator was used (login/signup
  /// route pushed).  Callers should re-check `FirebaseAuth.instance.currentUser`
  /// after awaiting this if they want to retry the action.
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _LoginPromptSheet(),
    );
    return result == true;
  }

  /// Convenience: returns `true` if the user IS logged in (no prompt needed),
  /// `false` after showing the prompt (action should be aborted).
  ///
  /// Usage:
  /// ```dart
  /// if (!await AuthGuard.check(context, currentUserId)) return;
  /// ```
  static Future<bool> check(BuildContext context, String currentUserId) async {
    if (currentUserId.isNotEmpty) return true;
    await show(context);
    return false;
  }
}

class _LoginPromptSheet extends StatelessWidget {
  const _LoginPromptSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          CircleAvatar(
            radius: 32,
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.star_rounded, size: 36, color: cs.primary),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Join Starpage',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Log in or create an account to like, comment, follow and more.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 28),

          // Log in button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
                Navigator.of(context, rootNavigator: true).pushNamed('/login');
              },
              child: const Text('Log In'),
            ),
          ),
          const SizedBox(height: 12),

          // Sign up button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context, true);
                Navigator.of(context, rootNavigator: true).pushNamed('/signup');
              },
              child: const Text('Create Account'),
            ),
          ),
          const SizedBox(height: 8),

          // Dismiss
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Maybe later',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
