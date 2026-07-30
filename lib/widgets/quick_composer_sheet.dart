import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../utils/mention_utils.dart';

class QuickComposerSheet extends StatefulWidget {
  const QuickComposerSheet({super.key});

  @override
  State<QuickComposerSheet> createState() => _QuickComposerSheetState();
}

class _QuickComposerSheetState extends State<QuickComposerSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final UserService _userService = UserService();
  final PostService _postService = PostService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  UserModel? _currentUser;
  bool _isLoadingUser = true;
  bool _isPosting = false;

  List<UserModel> _mentionableUsers = const [];
  List<UserModel> _filteredMentionUsers = const [];
  String? _activeMentionQuery;
  bool _isLoadingMentionUsers = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _controller.addListener(_handleMentionInputChanged);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _loadUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final user = await _userService.getUser(uid);
      if (mounted) setState(() { _currentUser = user; _isLoadingUser = false; });
    } else {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _createPost() async {
    final trimmedContent = _controller.text.trim();
    if (trimmedContent.isEmpty) return;
    setState(() => _isPosting = true);
    try {
      final user = _currentUser;
      if (user == null) throw Exception('User profile not found');
      await _postService.createPost(
        authorId: user.uid, authorName: user.displayName, authorUsername: user.username, authorImageUrl: user.profileImageUrl,
        content: trimmedContent, imageFiles: [], imageBytes: {}, talent: user.talent,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post shared successfully! ⭐')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _ensureMentionableUsersLoaded() async {
    if (_mentionableUsers.isNotEmpty || _isLoadingMentionUsers) return;
    _isLoadingMentionUsers = true;
    try {
      final users = await _userService.getAllUsers();
      if (!mounted) return;
      setState(() => _mentionableUsers = users);
    } finally {
      _isLoadingMentionUsers = false;
    }
  }

  Future<void> _handleMentionInputChanged() async {
    final query = MentionUtils.activeMentionQuery(_controller.text, _controller.selection);
    if (query == null) {
      if (_activeMentionQuery != null || _filteredMentionUsers.isNotEmpty) {
        setState(() { _activeMentionQuery = null; _filteredMentionUsers = const []; });
      }
      return;
    }
    await _ensureMentionableUsersLoaded();
    if (!mounted) return;
    final normalizedQuery = query.toLowerCase();
    final currentUserId = _auth.currentUser?.uid;
    final matchingUsers = _mentionableUsers.where((user) {
      if (user.uid == currentUserId) return false;
      final handle = user.username ?? MentionUtils.normalizeDisplayNameToHandle(user.displayName);
      return normalizedQuery.isEmpty || handle.startsWith(normalizedQuery) || user.displayName.toLowerCase().contains(normalizedQuery);
    }).take(5).toList();
    setState(() { _activeMentionQuery = query; _filteredMentionUsers = matchingUsers; });
  }

  void _insertMentionHandle(String handle) {
    _controller.value = MentionUtils.insertMention(text: _controller.text, selection: _controller.selection, handle: handle);
    setState(() { _activeMentionQuery = null; _filteredMentionUsers = const []; });
    _focusNode.requestFocus();
  }

  Widget _buildMentionSuggestions() {
    if (_activeMentionQuery == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final showFollowers = 'followers'.startsWith(_activeMentionQuery!.toLowerCase());
    if (!showFollowers && _filteredMentionUsers.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.dividerColor)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (showFollowers) ListTile(dense: true, leading: const Icon(Icons.campaign_outlined), title: const Text('@followers'), onTap: () => _insertMentionHandle('followers')),
        ..._filteredMentionUsers.map((user) {
          final handle = user.username ?? MentionUtils.normalizeDisplayNameToHandle(user.displayName);
          return ListTile(dense: true, leading: CircleAvatar(radius: 14, backgroundImage: user.profileImageUrl != null ? CachedNetworkImageProvider(user.profileImageUrl!) : null, child: user.profileImageUrl == null ? const Icon(Icons.person, size: 14) : null), title: Text(user.displayName, style: const TextStyle(fontSize: 12)), subtitle: Text('@$handle', style: const TextStyle(fontSize: 10)), onTap: () => _insertMentionHandle(handle));
        }),
      ]),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_handleMentionInputChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                if (_currentUser != null) CircleAvatar(radius: 18, backgroundImage: _currentUser!.profileImageUrl != null ? CachedNetworkImageProvider(_currentUser!.profileImageUrl!) : null, child: _currentUser!.profileImageUrl == null ? const Icon(Icons.person, size: 20) : null)
                else if (_isLoadingUser) const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2))
                else const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text(_currentUser?.displayName ?? 'Share your creativity...', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
              ]),
            ),
            
            _buildMentionSuggestions(),

            Material(
              elevation: 12,
              color: theme.colorScheme.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
                    decoration: BoxDecoration(color: theme.colorScheme.surface, border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller, focusNode: _focusNode, minLines: 1, maxLines: 8, style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(hintText: 'Share your creativity...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: ElevatedButton(
                            onPressed: _isPosting || _controller.text.trim().isEmpty ? null : _createPost,
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16), minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                            child: _isPosting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Share Now', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.image_outlined), onPressed: () { Navigator.pop(context); Navigator.of(context).pushNamed('/create-post', arguments: _controller.text); }),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Text('${_controller.text.length}/280', style: theme.textTheme.labelSmall?.copyWith(color: _controller.text.length > 280 ? Colors.red : Colors.grey)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
