import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../widgets/post_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'profile_screen.dart';

class ActivityManagementScreen extends StatefulWidget {
  final int initialTabIndex;
  const ActivityManagementScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ActivityManagementScreen> createState() =>
      _ActivityManagementScreenState();
}

class _ActivityManagementScreenState extends State<ActivityManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserService _userService = UserService();
  final PostService _postService = PostService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Activity'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Liked'),
            Tab(text: 'Saved'),
            Tab(text: 'Muted Stars'),
            Tab(text: 'Muted Posts'),
            Tab(text: 'Blocked'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLikedTab(),
          _buildSavedTab(),
          _buildMutedAuthorsTab(),
          _buildMutedPostsTab(),
          _buildBlockedTab(),
        ],
      ),
    );
  }

  Widget _buildLikedTab() {
    return FutureBuilder<List<PostModel>>(
      future: _postService.getLikedPosts(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return const Center(child: Text('No liked posts yet.'));
        }
        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) =>
              PostWidget(post: posts[index], currentUserId: _currentUserId),
        );
      },
    );
  }

  Widget _buildSavedTab() {
    return FutureBuilder<UserModel?>(
      future: _userService.getUser(_currentUserId),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final savedIds = userSnap.data?.savedPosts ?? [];
        if (savedIds.isEmpty) {
          return const Center(child: Text('No saved posts yet.'));
        }

        return FutureBuilder<List<PostModel>>(
          future: _postService.getMutedPosts(savedIds), // Reuse fetching logic
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final posts = snapshot.data ?? [];
            return ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) =>
                  PostWidget(post: posts[index], currentUserId: _currentUserId),
            );
          },
        );
      },
    );
  }

  Widget _buildMutedAuthorsTab() {
    return FutureBuilder<List<UserModel>>(
      future: _userService.getMutedAuthors(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('No muted stars.'));
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: user.profileImageUrl != null
                    ? CachedNetworkImageProvider(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(user.displayName),
              subtitle: Text(user.talent ?? 'Talent not specified'),
              trailing: TextButton(
                onPressed: () async {
                  await _userService.unmuteAuthor(_currentUserId, user.uid);
                  setState(() {});
                },
                child: const Text('Unmute'),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: user.uid),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMutedPostsTab() {
    return FutureBuilder<UserModel?>(
      future: _userService.getUser(_currentUserId),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final mutedIds = userSnap.data?.mutedPosts ?? [];
        if (mutedIds.isEmpty) {
          return const Center(child: Text('No muted posts.'));
        }

        return FutureBuilder<List<PostModel>>(
          future: _postService.getMutedPosts(mutedIds),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final posts = snapshot.data ?? [];
            return ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: Text(
                    post.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('By ${post.authorName}'),
                  trailing: TextButton(
                    onPressed: () async {
                      await _userService.unmutePost(
                        _currentUserId,
                        post.postId,
                      );
                      setState(() {});
                    },
                    child: const Text('Unmute'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBlockedTab() {
    return FutureBuilder<List<UserModel>>(
      future: _userService.getBlockedUsers(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('No blocked stars.'));
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: user.profileImageUrl != null
                    ? CachedNetworkImageProvider(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(user.displayName),
              trailing: TextButton(
                onPressed: () async {
                  await _userService.unblockUser(_currentUserId, user.uid);
                  setState(() {});
                },
                child: const Text('Unblock'),
              ),
            );
          },
        );
      },
    );
  }
}
