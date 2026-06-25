import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  late TabController _tabController;
  String _selectedCategory = 'All';

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String talent) {
    if (_selectedCategory == talent) {
      return;
    }

    setState(() {
      _selectedCategory = talent;
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
                _TrendingListView(
                  key: PageStorageKey('trending_today_$_selectedCategory'),
                  type: _TrendingType.today,
                  talent: _selectedCategory,
                ),
                // This Week's Trending
                _TrendingListView(
                  key: const PageStorageKey('trending_week'),
                  type: _TrendingType.week,
                ),
                // Top Liked
                _TrendingListView(
                  key: const PageStorageKey('trending_top_liked'),
                  type: _TrendingType.topLiked,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TrendingType { today, week, topLiked }

class _TrendingListView extends StatefulWidget {
  final _TrendingType type;
  final String? talent;

  const _TrendingListView({super.key, required this.type, this.talent});

  @override
  State<_TrendingListView> createState() => _TrendingListViewState();
}

class _TrendingListViewState extends State<_TrendingListView>
    with AutomaticKeepAliveClientMixin {
  final TrendingService _trendingService = TrendingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  final List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      List<PostModel> fetchedPosts = [];
      DocumentSnapshot? newLastDoc;
      const int limit = 15;

      switch (widget.type) {
        case _TrendingType.today:
          if (widget.talent == null || widget.talent == 'All') {
            final result = await _trendingService.getTrendingPosts(
              limit: limit,
              lastDocument: _lastDocument,
            );
            fetchedPosts = result.posts;
            newLastDoc = result.lastDoc;
          } else {
            final result = await _trendingService.getTrendingPostsByTalent(
              talent: widget.talent!,
              limit: limit,
              lastDocument: _lastDocument,
            );
            fetchedPosts = result.posts;
            newLastDoc = result.lastDoc;
          }
          break;
        case _TrendingType.week:
          final result = await _trendingService.getTrendingPosts(
            limit: limit,
            lastDocument: _lastDocument,
          );
          fetchedPosts = result.posts;
          newLastDoc = result.lastDoc;
          break;
        case _TrendingType.topLiked:
          final result = await _trendingService.getTopPostsByLikes(
            limit: limit,
            lastDocument: _lastDocument,
          );
          fetchedPosts = result.posts;
          newLastDoc = result.lastDoc;
          break;
      }

      if (mounted) {
        setState(() {
          _posts.addAll(fetchedPosts);
          _lastDocument = newLastDoc;
          _isLoading = false;
          _hasMore = fetchedPosts.length >= limit;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_posts.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_posts.isEmpty) {
      return const Center(child: Text('No trending posts found'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _posts.clear();
          _hasMore = true;
          _lastDocument = null;
        });
        await _loadMore();
      },
      child: ListView.builder(
        controller: _scrollController,
        // ignore: deprecated_member_use
        cacheExtent: 1500.0, // Increased to remove blank screen while scrolling
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final post = _posts[index];

          Widget child;
          if (widget.type == _TrendingType.topLiked) {
            child = _buildRankedPostWidget(index: index, post: post);
          } else {
            child = PostWidget(
              post: post,
              currentUserId: _auth.currentUser?.uid ?? '',
            );
          }

          return KeyedSubtree(
            key: ValueKey(post.postId),
            child: index < 15 // Only animate the first visible batch
                ? AnimationUtils.slideUpAnimation(
                    duration: const Duration(milliseconds: 300),
                    delayMilliseconds: index < 10 ? index * 30 : 0,
                    child: child,
                  )
                : child,
          );
        },
      ),
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
              scale: const AlwaysStoppedAnimation(1.2),
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
