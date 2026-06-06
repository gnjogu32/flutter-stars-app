import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'profile_screen.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String userId;
  final int initialTabIndex;

  const FollowersFollowingScreen({
    super.key,
    required this.userId,
    this.initialTabIndex = 0,
  });

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final user = await _userService.getUser(uid);
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: widget.initialTabIndex,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Network'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Followers'),
              Tab(text: 'Following'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UserList(
              userId: widget.userId,
              isFollowers: true,
              currentUserId: _auth.currentUser?.uid,
              currentUserFollowing: _currentUser?.following ?? [],
              onFollowStatusChanged: _loadCurrentUser,
            ),
            _UserList(
              userId: widget.userId,
              isFollowers: false,
              currentUserId: _auth.currentUser?.uid,
              currentUserFollowing: _currentUser?.following ?? [],
              onFollowStatusChanged: _loadCurrentUser,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserList extends StatefulWidget {
  final String userId;
  final bool isFollowers;
  final String? currentUserId;
  final List<String> currentUserFollowing;
  final VoidCallback onFollowStatusChanged;

  const _UserList({
    required this.userId,
    required this.isFollowers,
    this.currentUserId,
    required this.currentUserFollowing,
    required this.onFollowStatusChanged,
  });

  @override
  State<_UserList> createState() => _UserListState();
}

class _UserListState extends State<_UserList> {
  final UserService _userService = UserService();
  bool _isLoading = true;
  List<UserModel> _users = [];
  final Set<String> _loadingUserIds = {};

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.isFollowers) {
        _users = await _userService.getFollowers(widget.userId);
      } else {
        _users = await _userService.getFollowing(widget.userId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow(UserModel targetUser) async {
    if (widget.currentUserId == null) return;

    final isFollowing = widget.currentUserFollowing.contains(targetUser.uid);

    setState(() {
      _loadingUserIds.add(targetUser.uid);
    });

    try {
      if (isFollowing) {
        await _userService.unfollowUser(widget.currentUserId!, targetUser.uid);
      } else {
        await _userService.followUser(widget.currentUserId!, targetUser.uid);
      }
      widget.onFollowStatusChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingUserIds.remove(targetUser.uid);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return Center(
        child: Text(
          widget.isFollowers ? 'No followers yet.' : 'Not following anyone yet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final isFollowing = widget.currentUserFollowing.contains(user.uid);
        final isMe = widget.currentUserId == user.uid;
        final isUpdating = _loadingUserIds.contains(user.uid);

        return ListTile(
          leading: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: user.uid),
                ),
              );
            },
            child: CircleAvatar(
              backgroundImage: user.profileImageUrl != null
                  ? CachedNetworkImageProvider(user.profileImageUrl!)
                  : null,
              child: user.profileImageUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
          ),
          title: Text(user.displayName),
          subtitle: user.talent != null ? Text(user.talent!) : null,
          trailing: isMe
              ? null
              : SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: isUpdating ? null : () => _toggleFollow(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey[300])
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: isFollowing
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isFollowing ? 'Unfollow' : 'Follow'),
                  ),
                ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProfileScreen(userId: user.uid),
              ),
            );
          },
        );
      },
    );
  }
}
