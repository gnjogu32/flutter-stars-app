import 'package:flutter/material.dart';

/// Reusable animation utilities for Starpage app
class AnimationUtils {
  // Scale animation for buttons
  static Widget scaleButtonAnimation({
    required Widget child,
    required VoidCallback onTap,
    Duration duration = const Duration(milliseconds: 200),
  }) {
    return _ScaleButtonAnimationWidget(
      onTap: onTap,
      duration: duration,
      child: child,
    );
  }

  // Fade animation for elements
  static Widget fadeInAnimation({
    required Widget child,
    Duration duration = const Duration(milliseconds: 500),
    int delayMilliseconds = 0,
  }) {
    return _FadeInAnimationWidget(
      duration: duration,
      delay: Duration(milliseconds: delayMilliseconds),
      child: child,
    );
  }

  // Slide animation from bottom
  static Widget slideUpAnimation({
    required Widget child,
    Duration duration = const Duration(milliseconds: 400),
    int delayMilliseconds = 0,
  }) {
    return _SlideUpAnimationWidget(
      duration: duration,
      delay: Duration(milliseconds: delayMilliseconds),
      child: child,
    );
  }

  // Staggered list animation
  static Widget staggeredListAnimation({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    Duration duration = const Duration(milliseconds: 400),
    int delayBetweenItems = 50,
  }) {
    return _StaggeredListAnimationWidget(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      duration: duration,
      delayBetweenItems: delayBetweenItems,
    );
  }
}

// Scale button animation widget
class _ScaleButtonAnimationWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Duration duration;

  const _ScaleButtonAnimationWidget({
    required this.child,
    required this.onTap,
    required this.duration,
  });

  @override
  State<_ScaleButtonAnimationWidget> createState() =>
      _ScaleButtonAnimationWidgetState();
}

class _ScaleButtonAnimationWidgetState
    extends State<_ScaleButtonAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

// Fade in animation widget
class _FadeInAnimationWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const _FadeInAnimationWidget({
    required this.child,
    required this.duration,
    required this.delay,
  });

  @override
  State<_FadeInAnimationWidget> createState() => _FadeInAnimationWidgetState();
}

class _FadeInAnimationWidgetState extends State<_FadeInAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: widget.child);
  }
}

// Slide up animation widget
class _SlideUpAnimationWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const _SlideUpAnimationWidget({
    required this.child,
    required this.duration,
    required this.delay,
  });

  @override
  State<_SlideUpAnimationWidget> createState() =>
      _SlideUpAnimationWidgetState();
}

class _SlideUpAnimationWidgetState extends State<_SlideUpAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
      child: FadeTransition(opacity: _controller, child: widget.child),
    );
  }
}

// Staggered list animation widget
class _StaggeredListAnimationWidget extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Duration duration;
  final int delayBetweenItems;

  const _StaggeredListAnimationWidget({
    required this.itemCount,
    required this.itemBuilder,
    required this.duration,
    required this.delayBetweenItems,
  });

  @override
  State<_StaggeredListAnimationWidget> createState() =>
      _StaggeredListAnimationWidgetState();
}

class _StaggeredListAnimationWidgetState
    extends State<_StaggeredListAnimationWidget> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.itemCount,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final delay = Duration(milliseconds: widget.delayBetweenItems * index);
        return _SlideUpAnimationWidget(
          duration: widget.duration,
          delay: delay,
          child: widget.itemBuilder(context, index),
        );
      },
    );
  }
}

// Custom page transition for navigation
class CustomPageTransition extends PageRouteBuilder {
  final Widget page;

  CustomPageTransition({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      );
}

// Shimmer loading effect
class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 - _controller.value * 2, 0),
              end: Alignment(1, 0),
              colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}
