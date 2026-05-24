import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'post_details_sheet.dart';
import '../screens/profile_screen.dart';

class SearchOverlay extends StatefulWidget {
  final VoidCallback onClose;
  const SearchOverlay({super.key, required this.onClose});

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  TabController? _tabController;
  List<PostModel> _postResults = [];
  List<UserModel> _userResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _postResults = [];
        _userResults = [];
      });
      return;
    }
    _search(query);
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    // Search posts by content or authorName
    final postSnap = await FirebaseFirestore.instance
        .collection('posts')
        .where('content', isGreaterThanOrEqualTo: query)
        .where('content', isLessThan: '${query}z')
        .limit(20)
        .get();
    final posts = postSnap.docs
        .map((d) => PostModel.fromJson(d.data()))
        .toList();
    // Search users by displayName
    final users = await UserService().searchUsers(query);
    setState(() {
      _postResults = posts;
      _userResults = users;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? Colors.black.withValues(alpha: 0.85)
          : Colors.black.withAlpha((0.7 * 255).toInt()),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search posts or people...',
                        hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                        prefixIcon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.black54),
                        filled: true,
                        fillColor: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Posts'),
                Tab(text: 'People'),
              ],
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.white,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : TabBarView(
                      controller: _tabController,
                      children: [_buildPostsResults(), _buildUsersResults()],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsResults() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.white; // Keep white for overlay results

    if (_controller.text.isEmpty) {
      return const Center(child: Text('Type to search posts', style: TextStyle(color: Colors.white70)));
    }
    if (_postResults.isEmpty) {
      return const Center(child: Text('No posts found', style: TextStyle(color: Colors.white70)));
    }
    return ListView.builder(
      itemCount: _postResults.length,
      itemBuilder: (context, i) {
        final post = _postResults[i];
        return ListTile(
          title: Text(
            post.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text('by ${post.authorName}', style: const TextStyle(color: Colors.white70)),
          onTap: () {
            // Show post details as a modal bottom sheet (like feed)
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => DraggableScrollableSheet(
                expand: false,
                minChildSize: 0.3,
                maxChildSize: 0.85,
                builder: (context, scrollController) => PostDetailsSheet(
                  post: post,
                  scrollController: scrollController,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersResults() {
    if (_controller.text.isEmpty) {
      return const Center(child: Text('Type to search people', style: TextStyle(color: Colors.white70)));
    }
    if (_userResults.isEmpty) {
      return const Center(child: Text('No people found', style: TextStyle(color: Colors.white70)));
    }
    return ListView.builder(
      itemCount: _userResults.length,
      itemBuilder: (context, i) {
        final user = _userResults[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
                user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                ? NetworkImage(user.profileImageUrl!)
                : null,
            child:
                (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(user.displayName, style: const TextStyle(color: Colors.white)),
          subtitle: Text(user.talent ?? '', style: const TextStyle(color: Colors.white70)),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: user.uid),
              ),
            );
          },
        );
      },
    );
  }
}
