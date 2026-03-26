import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../utils/auth_guard.dart';
import 'profile_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _selectedTalentFilter = 'All';

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
    _searchFocusNode.addListener(_handleFocusChanged);
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleFocusChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Talents'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search talented stars...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          // Talent Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: talents.map((talent) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(talent),
                    selected: _selectedTalentFilter == talent,
                    onSelected: (selected) {
                      setState(() {
                        _selectedTalentFilter = talent;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Users List
          Expanded(child: _buildUsersList()),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    Query query = _firestore.collection('users');

    // Apply talent filter
    if (_selectedTalentFilter != 'All') {
      query = query.where('talent', isEqualTo: _selectedTalentFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No talented stars found in this category.'),
          );
        }

        var users = snapshot.data!.docs
            .map((doc) => UserModel.fromFirestoreDoc(doc))
            .toList();

        // Apply search filter
        if (_searchController.text.isNotEmpty) {
          users = users
              .where(
                (user) => user.displayName.toLowerCase().contains(
                  _searchController.text.toLowerCase(),
                ),
              )
              .toList();
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildUserCard(user);
          },
        );
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    return _UserCard(user: user);
  }
}

// ── Per-user card with inline follow state ─────────────────────────────────
class _UserCard extends StatefulWidget {
  final UserModel user;
  const _UserCard({required this.user});

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  final _auth = FirebaseAuth.instance;
  final _userService = UserService();
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFollowState();
  }

  Future<void> _checkFollowState() async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null || currentUid == widget.user.uid) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      if (doc.exists && mounted) {
        final following = List<String>.from(
          (doc.data()! as Map)['following'] ?? [],
        );
        setState(() => _isFollowing = following.contains(widget.user.uid));
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final currentUid = _auth.currentUser?.uid;
    if (_isFollowLoading) return;
    if (currentUid == null) {
      await AuthGuard.show(context);
      return;
    }
    setState(() => _isFollowLoading = true);
    try {
      if (_isFollowing) {
        await _userService.unfollowUser(currentUid, widget.user.uid);
      } else {
        await _userService.followUser(currentUid, widget.user.uid);
      }
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          _isFollowLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid;
    final isOwnProfile = currentUid == widget.user.uid;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: widget.user.profileImageUrl != null
              ? NetworkImage(widget.user.profileImageUrl!)
              : null,
          child: widget.user.profileImageUrl == null
              ? const Icon(Icons.person)
              : null,
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                widget.user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isOwnProfile) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 26,
                child: OutlinedButton(
                  onPressed: _isFollowLoading ? null : _toggleFollow,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: _isFollowing
                          ? Colors.grey.shade400
                          : Theme.of(context).colorScheme.primary,
                    ),
                    foregroundColor: _isFollowing ? Colors.grey.shade600 : null,
                  ),
                  child: _isFollowLoading
                      ? SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : Text(_isFollowing ? 'Following' : 'Follow'),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.user.talent != null) Text(widget.user.talent!),
            if (widget.user.bio != null) Text(widget.user.bio!),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProfileScreen(userId: widget.user.uid),
              ),
            );
          },
          child: const Text('View'),
        ),
      ),
    );
  }
}
