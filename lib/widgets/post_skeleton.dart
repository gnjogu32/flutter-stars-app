import 'package:flutter/material.dart';

/// Animated shimmer skeleton that matches the PostWidget card layout.
class PostSkeleton extends StatefulWidget {
  const PostSkeleton({super.key});

  @override
  State<PostSkeleton> createState() => _PostSkeletonState();
}

class _PostSkeletonState extends State<PostSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final base = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
        final highlight = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
        final color = Color.lerp(base, highlight, _animation.value)!;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: avatar + name lines
                Row(
                  children: [
                    _Bone(width: 44, height: 44, radius: 22, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Bone(
                            width: 120,
                            height: 13,
                            radius: 4,
                            color: color,
                          ),
                          const SizedBox(height: 6),
                          _Bone(width: 80, height: 10, radius: 4, color: color),
                        ],
                      ),
                    ),
                    _Bone(width: 50, height: 10, radius: 4, color: color),
                  ],
                ),
                const SizedBox(height: 14),
                // Content lines
                _Bone(
                  width: double.infinity,
                  height: 12,
                  radius: 4,
                  color: color,
                ),
                const SizedBox(height: 6),
                _Bone(
                  width: double.infinity,
                  height: 12,
                  radius: 4,
                  color: color,
                ),
                const SizedBox(height: 6),
                _Bone(width: 180, height: 12, radius: 4, color: color),
                const SizedBox(height: 14),
                // Fake media placeholder
                _Bone(
                  width: double.infinity,
                  height: 180,
                  radius: 8,
                  color: color,
                ),
                const SizedBox(height: 14),
                // Interaction row
                Row(
                  children: [
                    _Bone(width: 50, height: 20, radius: 4, color: color),
                    const SizedBox(width: 16),
                    _Bone(width: 50, height: 20, radius: 4, color: color),
                    const SizedBox(width: 16),
                    _Bone(width: 50, height: 20, radius: 4, color: color),
                    const SizedBox(width: 16),
                    _Bone(width: 50, height: 20, radius: 4, color: color),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Bone extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Color color;

  const _Bone({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A full-screen list of [PostSkeleton] cards used during initial feed load.
class PostFeedSkeleton extends StatelessWidget {
  final int count;
  const PostFeedSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => const PostSkeleton(),
    );
  }
}
