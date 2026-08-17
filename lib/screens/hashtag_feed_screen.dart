import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../widgets/post_widget.dart';
import '../utils/animation_utils.dart';

class HashtagFeedScreen extends StatefulWidget {
  final String hashtag;

  const HashtagFeedScreen({super.key, required this.hashtag});

  @override
  State<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends State<HashtagFeedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  final List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _loadPosts();
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
      _loadPosts();
    }
  }

  Future<void> _loadPosts() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tag = widget.hashtag.toLowerCase().replaceAll('#', '');
      Query query = _firestore
          .collection('posts')
          .where('hashtags', arrayContains: tag)
          .orderBy('createdAt', descending: true)
          .limit(15);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      final fetchedPosts = snapshot.docs
          .map((doc) => PostModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _posts.addAll(fetchedPosts);
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _isLoading = false;
          _hasMore = fetchedPosts.length >= 15;
        });
      }
    } catch (e) {
      debugPrint('Error loading hashtag posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid ?? 'guest';

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(currentUserId).get(),
      builder: (context, userSnapshot) {
        final List<String> following;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          following = List<String>.from(userData['following'] ?? []);
        } else {
          following = [];
        }

        final filteredPosts = _posts.where((post) {
          if (post.visibility == 'followers') {
            final isAuthor = post.authorId == currentUserId;
            final isFollowing = following.contains(post.authorId);
            return isAuthor || isFollowing;
          }
          return true;
        }).toList();

        return Scaffold(
          appBar: AppBar(title: Text('#${widget.hashtag}'), centerTitle: true),
          body: filteredPosts.isEmpty && _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredPosts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tag, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No posts with #${widget.hashtag} yet',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _posts.clear();
                      _hasMore = true;
                      _lastDocument = null;
                    });
                    await _loadPosts();
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: filteredPosts.length + (_hasMore ? 1 : 0),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemBuilder: (context, index) {
                      if (index == filteredPosts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final post = filteredPosts[index];
                      return KeyedSubtree(
                        key: ValueKey(post.postId),
                        child: index < 15
                            ? AnimationUtils.slideUpAnimation(
                                duration: const Duration(milliseconds: 300),
                                delayMilliseconds: index < 10 ? index * 30 : 0,
                                child: PostWidget(
                                  post: post,
                                  currentUserId: currentUserId,
                                ),
                              )
                            : PostWidget(
                                post: post,
                                currentUserId: currentUserId,
                              ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
