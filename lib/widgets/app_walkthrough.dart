import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppWalkthrough {
  AppWalkthrough._();

  static const _storageKey = 'has_seen_app_walkthrough_v1';
  static const _storage = FlutterSecureStorage();

  static const _steps = <_WalkthroughStep>[
    _WalkthroughStep(
      eyebrow: 'YOUR CREATOR COMMUNITY',
      title: 'Welcome to Starpage',
      description:
          'Discover creative work, meet talented people, and share what you love.',
      icon: Icons.auto_awesome_rounded,
      colors: [Color(0xFF7C4DFF), Color(0xFF4C6FFF)],
      actionLabel: 'Explore Home',
      tabIndex: 0,
    ),
    _WalkthroughStep(
      eyebrow: 'WATCH & DISCOVER',
      title: 'Short videos, your way',
      description:
          'Browse Vistas for a full-screen stream of short videos from the community.',
      icon: Icons.play_circle_fill_rounded,
      colors: [Color(0xFFFF5B7F), Color(0xFFFF8A52)],
      actionLabel: 'Explore Vistas',
      tabIndex: 1,
    ),
    _WalkthroughStep(
      eyebrow: 'FIND YOUR NEXT FAVORITE',
      title: 'Explore creators and talents',
      description:
          'Search for people, hashtags, and topics, or browse creative talent categories.',
      icon: Icons.explore_rounded,
      colors: [Color(0xFF00A89D), Color(0xFF42C98A)],
      actionLabel: 'Open Discover',
      tabIndex: 2,
    ),
    _WalkthroughStep(
      eyebrow: 'MAKE SOMETHING YOURS',
      title: 'Share a post',
      description:
          'Tap the + button to publish a video, photo, or text post. Choose whether it is public or for followers only.',
      icon: Icons.add_a_photo_rounded,
      colors: [Color(0xFF4069E5), Color(0xFF37A4E8)],
      actionLabel: 'Create a post',
      tabIndex: -1,
    ),
    _WalkthroughStep(
      eyebrow: 'STAY CONNECTED',
      title: 'Join the conversation',
      description:
          'Follow creators, like and comment on posts, and use Messages and Notifications to keep up with activity.',
      icon: Icons.forum_rounded,
      colors: [Color(0xFF9B59B6), Color(0xFFE45D91)],
      actionLabel: 'Start exploring',
      tabIndex: 0,
    ),
  ];

  /// Shows the tour only once on this installation. It can be reopened from Settings.
  static Future<void> showIfNeeded(
    BuildContext context, {
    required ValueChanged<int> onSelectTab,
    required VoidCallback onCreatePost,
  }) async {
    try {
      if (await _storage.read(key: _storageKey) == 'true') return;
    } catch (_) {
      // Still let the user see the tour if secure storage is temporarily unavailable.
    }
    if (!context.mounted) return;
    await show(context, onSelectTab: onSelectTab, onCreatePost: onCreatePost);
  }

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<int> onSelectTab,
    required VoidCallback onCreatePost,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _WalkthroughDialog(
        onSelectTab: onSelectTab,
        onCreatePost: onCreatePost,
      ),
    );
  }

  static Future<void> _markSeen() async {
    try {
      await _storage.write(key: _storageKey, value: 'true');
    } catch (_) {
      // Completing or skipping the tour should never block app use.
    }
  }
}

class _WalkthroughStep {
  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final String actionLabel;
  final int tabIndex;

  const _WalkthroughStep({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
    required this.actionLabel,
    required this.tabIndex,
  });
}

class _WalkthroughDialog extends StatefulWidget {
  final ValueChanged<int> onSelectTab;
  final VoidCallback onCreatePost;

  const _WalkthroughDialog({
    required this.onSelectTab,
    required this.onCreatePost,
  });

  @override
  State<_WalkthroughDialog> createState() => _WalkthroughDialogState();
}

class _WalkthroughDialogState extends State<_WalkthroughDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLeaving = false;

  void _finish({int? destination}) {
    if (_isLeaving) return;
    _isLeaving = true;
    AppWalkthrough._markSeen();
    if (!mounted) return;
    Navigator.of(context).pop();
    if (destination != null) {
      if (destination == -1) {
        widget.onCreatePost();
      } else {
        widget.onSelectTab(destination);
      }
    }
  }

  void _next() {
    final step = AppWalkthrough._steps[_currentPage];
    if (_currentPage == AppWalkthrough._steps.length - 1) {
      _finish(destination: step.tabIndex);
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == AppWalkthrough._steps.length - 1;
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: size.height * 0.86,
          minHeight: 500,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'STARPAGE TOUR',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _finish(),
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: AppWalkthrough._steps.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) =>
                      _buildPage(context, AppWalkthrough._steps[index], index),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(AppWalkthrough._steps.length, (index) {
                  final active = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: active ? 24 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                      ),
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 56),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(
                      isLastPage
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(isLastPage ? 'Start exploring' : 'Next'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, _WalkthroughStep step, int index) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                constraints:
                    const BoxConstraints(maxWidth: 140, maxHeight: 140),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: step.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: step.colors.first.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(step.icon, size: 64, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'STEP ${index + 1} OF ${AppWalkthrough._steps.length}  •  ${step.eyebrow}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (index < AppWalkthrough._steps.length - 1) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => _finish(destination: step.tabIndex),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(step.actionLabel),
                    ),
                  ],
                  if (step.tabIndex == -1) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Use the + button at the bottom of the app.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
