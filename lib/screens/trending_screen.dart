import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../services/trending_service.dart';
import '../utils/animation_utils.dart';
import '../widgets/post_widget.dart';

class TrendingScreen extends StatefulWidget {
  final String? talentFilter;

  const TrendingScreen({super.key, this.talentFilter});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen>
    with SingleTickerProviderStateMixin {
  final TrendingService _trendingService = TrendingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;
  String _selectedCategory = 'All';
  late Future<List<PostModel>> _todayFuture;
  late Future<List<PostModel>> _weekFuture;
  late Future<List<PostModel>> _topLikedFuture;

  final List<String> talents = [
    'All',
    'Art',
    'Music',
    'Writing',
    'Dance',
    'Photography',
    'Fashion',
    'Comedy',
    'Acting',
    'Sports',
    'Gaming',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedCategory = widget.talentFilter ?? 'All';
    _todayFuture = _loadTodayTrending(_selectedCategory);
    _weekFuture = _trendingService.getTrendingPosts(limit: 50);
    _topLikedFuture = _trendingService.getTopPostsByLikes(limit: 50);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<PostModel>> _loadTodayTrending(String category) {
    if (category == 'All') {
      return _trendingService.getTrendingPosts(limit: 50);
    }

    return _trendingService.getTrendingPostsByTalent(
      talent: category,
      limit: 50,
    );
  }

  void _onCategorySelected(String talent) {
    if (_selectedCategory == talent) {
      return;
    }

    setState(() {
      _selectedCategory = talent;
      _todayFuture = _loadTodayTrending(talent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trending Posts'),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'This Week'),
            Tab(text: 'Top Liked'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Category Filter
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                itemCount: talents.length,
                itemBuilder: (context, index) {
                  final theme = Theme.of(context);
                  final talent = talents[index];
                  final isSelected = _selectedCategory == talent;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: FilterChip(
                      label: Text(talent),
                      selected: isSelected,
                      onSelected: (_) => _onCategorySelected(talent),
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      selectedColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Today's Trending
                _buildTrendingList(
                  future: _todayFuture,
                  listStorageKey: 'trending_today_$_selectedCategory',
                ),
                // This Week's Trending
                _buildTrendingListByTalent(listStorageKey: 'trending_week'),
                // Top Liked
                _buildTopLikedList(listStorageKey: 'trending_top_liked'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingList({
    required Future<List<PostModel>> future,
    required String listStorageKey,
  }) {
    return FutureBuilder<List<PostModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No trending posts found'));
        }

        return _buildPostList(
          posts: snapshot.data!,
          listStorageKey: listStorageKey,
        );
      },
    );
  }

  Widget _buildTrendingListByTalent({required String listStorageKey}) {
    return FutureBuilder<List<PostModel>>(
      future: _weekFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No trending posts this week'));
        }

        return _buildPostList(
          posts: snapshot.data!,
          listStorageKey: listStorageKey,
        );
      },
    );
  }

  Widget _buildTopLikedList({required String listStorageKey}) {
    return FutureBuilder<List<PostModel>>(
      future: _topLikedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No posts found'));
        }

        final posts = snapshot.data!;

        return ListView.builder(
          // ignore: deprecated_member_use
          cacheExtent: 600.0,
          key: PageStorageKey<String>(listStorageKey),
          itemCount: posts.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            return KeyedSubtree(
              key: ValueKey(posts[index].postId),
              child: AnimationUtils.slideUpAnimation(
                duration: const Duration(milliseconds: 400),
                delayMilliseconds: index * 50,
                child: _buildRankedPostWidget(index: index, post: posts[index]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostList({
    required List<PostModel> posts,
    required String listStorageKey,
  }) {
    return ListView.builder(
      // ignore: deprecated_member_use
      cacheExtent: 600.0,
      key: PageStorageKey<String>(listStorageKey),
      itemCount: posts.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return KeyedSubtree(
          key: ValueKey(posts[index].postId),
          child: AnimationUtils.slideUpAnimation(
            duration: const Duration(milliseconds: 400),
            delayMilliseconds: index * 50,
            child: PostWidget(
              post: posts[index],
              currentUserId: _auth.currentUser?.uid ?? '',
            ),
          ),
        );
      },
    );
  }

  Widget _buildRankedPostWidget({required int index, required PostModel post}) {
    final theme = Theme.of(context);
    final isTopThree = index < 3;
    final medalEmoji = switch (index) {
      0 => '🥇',
      1 => '🥈',
      2 => '🥉',
      _ => null,
    };

    return Stack(
      children: [
        PostWidget(post: post, currentUserId: _auth.currentUser?.uid ?? ''),
        if (isTopThree)
          Positioned(
            top: 12,
            right: 12,
            child: ScaleTransition(
              scale: AlwaysStoppedAnimation(1.2),
              child: Text(medalEmoji!, style: const TextStyle(fontSize: 24)),
            ),
          )
        else
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '#${index + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
