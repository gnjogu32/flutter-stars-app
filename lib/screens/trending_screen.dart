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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                  final talent = talents[index];
                  final isSelected = _selectedCategory == talent;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: FilterChip(
                      label: Text(talent),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = talent;
                        });
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: Colors.orange,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
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
                  future: _selectedCategory == 'All'
                      ? _trendingService.getTrendingPosts(limit: 50)
                      : _trendingService.getTrendingPostsByTalent(
                          talent: _selectedCategory,
                          limit: 50,
                        ),
                ),
                // This Week's Trending
                _buildTrendingListByTalent(),
                // Top Liked
                _buildTopLikedList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingList({required Future<List<PostModel>> future}) {
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

        final posts = snapshot.data!;

        return ListView.builder(
          itemCount: posts.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            return AnimationUtils.slideUpAnimation(
              duration: const Duration(milliseconds: 400),
              delayMilliseconds: index * 50,
              child: PostWidget(
                post: posts[index],
                currentUserId: _auth.currentUser?.uid ?? '',
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrendingListByTalent() {
    return FutureBuilder<List<PostModel>>(
      future: _trendingService.getTrendingPosts(limit: 50),
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

        final posts = snapshot.data!;

        return ListView.builder(
          itemCount: posts.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            return AnimationUtils.slideUpAnimation(
              duration: const Duration(milliseconds: 400),
              delayMilliseconds: index * 50,
              child: PostWidget(
                post: posts[index],
                currentUserId: _auth.currentUser?.uid ?? '',
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopLikedList() {
    return FutureBuilder<List<PostModel>>(
      future: _trendingService.getTopPostsByLikes(limit: 50),
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
          itemCount: posts.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            return AnimationUtils.slideUpAnimation(
              duration: const Duration(milliseconds: 400),
              delayMilliseconds: index * 50,
              child: _buildRankedPostWidget(index: index, post: posts[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildRankedPostWidget({required int index, required PostModel post}) {
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
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '#${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
