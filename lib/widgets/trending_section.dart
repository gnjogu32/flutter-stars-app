import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/trending_service.dart';
import 'post_widget.dart';

class TrendingSection extends StatefulWidget {
  final String currentUserId;
  final bool autoPlayEnabled;
  final bool isTabVisible;
  final VoidCallback? onSeeAll;

  const TrendingSection({
    super.key,
    required this.currentUserId,
    this.autoPlayEnabled = true,
    this.isTabVisible = true,
    this.onSeeAll,
  });

  @override
  State<TrendingSection> createState() => _TrendingSectionState();
}

class _TrendingSectionState extends State<TrendingSection>
    with AutomaticKeepAliveClientMixin {
  final TrendingService _trendingService = TrendingService();
  late Future<List<PostModel>> _trendingPostsFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _trendingPostsFuture = _trendingService
        .getTrendingPosts(limit: 5)
        .then((result) => result.posts);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                        Navigator.of(context).pushNamed('/trending');
                      },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Text(
                      'See All',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
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
            if (snapshot.hasError) {
              debugPrint('Trending error: ${snapshot.error}');
            }

            final trendingPosts = snapshot.data ?? [];

            if (trendingPosts.isEmpty) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No trending posts yet'),
              );
            }

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
        return Opacity(opacity: value, child: child);
      },
      child: PostWidget(
        key: ValueKey('trending_${post.postId}'),
        post: post,
        currentUserId: widget.currentUserId,
        isTabVisible: widget.isTabVisible,
        autoPlayEnabled: widget.autoPlayEnabled,
      ),
    );
  }
}

class TrendingStreamSection extends StatefulWidget {
  final String currentUserId;
  final bool autoPlayEnabled;
  final bool isTabVisible;
  final VoidCallback? onSeeAll;

  const TrendingStreamSection({
    super.key,
    required this.currentUserId,
    this.autoPlayEnabled = true,
    this.isTabVisible = true,
    this.onSeeAll,
  });

  @override
  State<TrendingStreamSection> createState() => _TrendingStreamSectionState();
}

class _TrendingStreamSectionState extends State<TrendingStreamSection>
    with AutomaticKeepAliveClientMixin {
  final TrendingService _trendingService = TrendingService();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                        Navigator.of(context).pushNamed('/trending');
                      },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Text(
                      'See All',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
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
            if (snapshot.hasError) {
              debugPrint('Trending stream error: ${snapshot.error}');
            }

            final trendingPosts = snapshot.data ?? [];

            if (trendingPosts.isEmpty) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No trending posts yet'),
              );
            }

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
        return Opacity(opacity: value, child: child);
      },
      child: PostWidget(
        key: ValueKey('trending_${post.postId}'),
        post: post,
        currentUserId: widget.currentUserId,
        isTabVisible: widget.isTabVisible,
        autoPlayEnabled: widget.autoPlayEnabled,
      ),
    );
  }
}
