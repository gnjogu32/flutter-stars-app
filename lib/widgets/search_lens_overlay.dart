import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../screens/hashtag_feed_screen.dart';
import '../screens/main_app.dart';
import '../screens/profile_screen.dart';
import '../services/user_service.dart';

/// Full-screen search lens suggestion sheet accessible across all app screens.
class SearchLensOverlay extends StatefulWidget {
  final String initialQuery;
  const SearchLensOverlay({super.key, this.initialQuery = ''});

  static Future<void> show(BuildContext context, {String initialQuery = ''}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchLensOverlay(initialQuery: initialQuery),
    );
  }

  @override
  State<SearchLensOverlay> createState() => _SearchLensOverlayState();
}

class _SearchLensOverlayState extends State<SearchLensOverlay> {
  late final TextEditingController _searchController;
  final FocusNode _focusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();

  String _query = '';
  List<UserModel> _userResults = [];
  List<PostModel> _postResults = [];
  bool _isSearching = false;

  final List<String> _suggestedTags = [
    '#everyone',
    '#naturebeauty',
    '#socialmedia',
    '#Creativity',
    '#Gospel',
    '#Shorts',
    '#Trending',
  ];

  final List<String> _suggestedTalents = [
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
    _searchController = TextEditingController(text: widget.initialQuery);
    _query = widget.initialQuery;
    if (_query.isNotEmpty) {
      _performSearch(_query);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String searchText) async {
    final trimmed = searchText.trim().toLowerCase();
    setState(() {
      _query = searchText;
      _isSearching = trimmed.isNotEmpty;
    });

    if (trimmed.isEmpty) {
      setState(() {
        _userResults = [];
        _postResults = [];
        _isSearching = false;
      });
      return;
    }

    try {
      final users = await _userService.searchUsers(searchText.trim());

      final postsSnapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(40)
          .get();

      final posts = postsSnapshot.docs
          .map((doc) => PostModel.fromFirestoreDoc(doc))
          .where((post) {
            final cleanSearch = trimmed.replaceAll('#', '');
            final matchesContent = post.content.toLowerCase().contains(trimmed);
            final matchesHashtag = post.hashtags.any(
              (tag) => tag.toLowerCase().contains(cleanSearch),
            );
            final matchesTalent = (post.talent ?? '')
                .toLowerCase()
                .contains(cleanSearch);
            final matchesAuthor = post.authorName
                .toLowerCase()
                .contains(trimmed);
            return matchesContent ||
                matchesHashtag ||
                matchesTalent ||
                matchesAuthor;
          })
          .toList();

      if (mounted) {
        setState(() {
          _userResults = users;
          _postResults = posts;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF12141A) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Top Handle Bar
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Search Lens Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E212A)
                          : const Color(0xFFF2F3F8),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      autofocus: true,
                      onChanged: _performSearch,
                      decoration: InputDecoration(
                        hintText: 'Search stars, #tags, or categories...',
                        border: InputBorder.none,
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.blueAccent,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  _performSearch('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search Body
          Expanded(
            child: _isSearching
                ? _buildSearchResults()
                : _buildSuggestionsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        // Trending Hashtag Lens Suggestions
        const Text(
          'Trending Lens Suggestions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestedTags.map((tag) {
            return ActionChip(
              avatar: const Icon(
                Icons.center_focus_strong,
                size: 16,
                color: Colors.blueAccent,
              ),
              label: Text(tag),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => HashtagFeedScreen(hashtag: tag),
                  ),
                );
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Talent Category Lens Suggestions
        const Text(
          'Talent Category Lens',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestedTalents.map((talent) {
            return ActionChip(
              avatar: const Icon(
                Icons.star_outline,
                size: 16,
                color: Colors.amber,
              ),
              label: Text(talent),
              onPressed: () {
                Navigator.of(context).pop();
                MainApp.of(context)?.setSelectedIndex(2);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_userResults.isEmpty && _postResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No matching creators or posts found.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        // Users Section
        if (_userResults.isNotEmpty) ...[
          const Text(
            'Creators',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ..._userResults.map((user) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: user.profileImageUrl != null
                    ? CachedNetworkImageProvider(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null
                    ? Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : '?',
                      )
                    : null,
              ),
              title: Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                (user.talent ?? '').isNotEmpty
                    ? '${user.talent} • @${user.username}'
                    : '@${user.username}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: user.uid),
                  ),
                );
              },
            );
          }),
          const Divider(),
        ],

        // Posts Section
        if (_postResults.isNotEmpty) ...[
          const Text(
            'Posts & Content',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ..._postResults.map((post) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: post.imageUrls.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: post.imageUrls.first,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.article_outlined, size: 24),
              ),
              title: Text(
                post.content.isNotEmpty ? post.content : 'Media Post',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                'By ${post.authorName} • ${post.talent ?? "General"}',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: post.authorId),
                  ),
                );
              },
            );
          }),
        ],
      ],
    );
  }
}
