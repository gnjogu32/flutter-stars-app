import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../utils/animation_utils.dart';
import '../widgets/post_widget.dart';
import 'chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  bool _isFollowing = false;
  bool _isLoadingFollow = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    if (_auth.currentUser?.uid == null) return;
    try {
      final currentUser = await _userService.getUser(_auth.currentUser!.uid);
      if (currentUser != null) {
        setState(() {
          _isFollowing = currentUser.following.contains(widget.userId);
        });
      }
    } catch (e) {
      print('Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow(UserModel user) async {
    if (_auth.currentUser?.uid == null) return;

    setState(() {
      _isLoadingFollow = true;
    });

    try {
      if (_isFollowing) {
        await _userService.unfollowUser(_auth.currentUser!.uid, widget.userId);
      } else {
        await _userService.followUser(_auth.currentUser!.uid, widget.userId);
      }

      setState(() {
        _isFollowing = !_isFollowing;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() {
        _isLoadingFollow = false;
      });
    }
  }

  void _navigateToChat(UserModel user) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final conversationId = _generateConversationId(currentUserId, user.uid);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversationId,
          otherUserId: user.uid,
          otherUserName: user.displayName,
          otherUserImageUrl: user.profileImageUrl,
        ),
      ),
    );
  }

  String _generateConversationId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.userId == _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        elevation: 0,
        actions: isOwnProfile
            ? [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    _showLogoutDialog(context);
                  },
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('users').doc(widget.userId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('User not found'));
            }

            final user = UserModel.fromJson(
              snapshot.data!.data() as Map<String, dynamic>,
            );

            return Column(
              children: [
                // Profile Header
                _buildProfileHeader(user, isOwnProfile),
                const Divider(),
                // User Posts
                _buildUserPosts(user.uid),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user, bool isOwnProfile) {
    return AnimationUtils.slideUpAnimation(
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Image
            AnimatedScale(
              duration: const Duration(milliseconds: 300),
              scale: 1.0,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: user.profileImageUrl != null
                    ? NetworkImage(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              user.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            // Talent
            if (user.talent != null)
              Text(
                user.talent!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            // Bio
            if (user.bio != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  user.bio!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 16),
            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat('Posts', user.followers.length),
                _buildStat('Followers', user.followerCount),
                _buildStat('Following', user.followingCount),
              ],
            ),
            const SizedBox(height: 16),
            // Edit Profile / Follow Button & Message Button
            if (isOwnProfile)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/edit-profile');
                  },
                  child: const Text('Edit Profile'),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoadingFollow
                          ? null
                          : () => _toggleFollow(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing
                            ? Colors.grey[300]
                            : Theme.of(context).colorScheme.primary,
                      ),
                      child: _isLoadingFollow
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isFollowing ? 'Following' : 'Follow',
                              style: TextStyle(
                                color: _isFollowing
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateToChat(user),
                      icon: const Icon(Icons.mail),
                      label: const Text('Message'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, int count) {
    return Column(
      children: [
        Text(count.toString(), style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildUserPosts(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No posts yet',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final posts = snapshot.data!.docs
            .map(
              (doc) => PostModel.fromJson(doc.data() as Map<String, dynamic>),
            )
            .toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return PostWidget(
              post: posts[index],
              currentUserId: _auth.currentUser?.uid ?? '',
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              AuthService().logout();
              Navigator.pop(context);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
