import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/trending_service.dart';
import '../screens/trending_screen.dart';
import 'post_widget.dart';

class TrendingSection extends StatefulWidget {
  final String currentUserId;
  final VoidCallback? onSeeAll;

  const TrendingSection({
    super.key,
    required this.currentUserId,
    this.onSeeAll,
  });

  @override
  State<TrendingSection> createState() => _TrendingSectionState();
}

class _TrendingSectionState extends State<TrendingSection> {
  final TrendingService _trendingService = TrendingService();
  late Future<List<PostModel>> _trendingPostsFuture;

  @override
  void initState() {
    super.initState();
    _trendingPostsFuture = _trendingService.getTrendingPosts(limit: 5);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.orange, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Trending Now',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap:
                      widget.onSeeAll ??
                      () {
                        Navigator.of(context).push(_createTrendingPageRoute());
                      },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Trending Posts
        FutureBuilder<List<PostModel>>(
          future: _trendingPostsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No trending posts yet'),
              );
            }

            final trendingPosts = snapshot.data!;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trendingPosts.length,
              itemBuilder: (context, index) {
                return _buildAnimatedTrendingPost(
                  index: index,
                  post: trendingPosts[index],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnimatedTrendingPost({
    required int index,
    required PostModel post,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: PostWidget(post: post, currentUserId: widget.currentUserId),
    );
  }

  Route _createTrendingPageRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const TrendingScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }
}

class TrendingStreamSection extends StatefulWidget {
  final String currentUserId;
  final VoidCallback? onSeeAll;

  const TrendingStreamSection({
    super.key,
    required this.currentUserId,
    this.onSeeAll,
  });

  @override
  State<TrendingStreamSection> createState() => _TrendingStreamSectionState();
}

class _TrendingStreamSectionState extends State<TrendingStreamSection> {
  final TrendingService _trendingService = TrendingService();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.orange, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Trending Now',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap:
                      widget.onSeeAll ??
                      () {
                        Navigator.of(context).push(_createTrendingPageRoute());
                      },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Trending Posts Stream
        StreamBuilder<List<PostModel>>(
          stream: _trendingService.getTrendingPostsStream(limit: 5),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No trending posts yet'),
              );
            }

            final trendingPosts = snapshot.data!;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trendingPosts.length,
              itemBuilder: (context, index) {
                return _buildAnimatedTrendingPost(
                  index: index,
                  post: trendingPosts[index],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnimatedTrendingPost({
    required int index,
    required PostModel post,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: PostWidget(post: post, currentUserId: widget.currentUserId),
    );
  }

  Route _createTrendingPageRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const TrendingScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }
}
