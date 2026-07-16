import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/post_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../utils/mention_utils.dart';
import '../models/user_model.dart';
import '../widgets/keyboard_prompt_banner.dart';

class CreatePostScreen extends StatefulWidget {
  final String? initialContent;
  const CreatePostScreen({super.key, this.initialContent});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late final TextEditingController _contentController;
  final FocusNode _contentFocusNode = FocusNode();
  final _imagePicker = ImagePicker();
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;

  final List<XFile> _selectedImages = [];
  final Map<String, Uint8List> _imageBytes = {}; // Store bytes immediately
  XFile? _selectedVideo;
  String? _selectedTalent;
  bool _isLoading = false;
  String? _errorMessage;
  List<UserModel> _mentionableUsers = const [];
  List<UserModel> _filteredMentionUsers = const [];
  String? _activeMentionQuery;
  bool _isLoadingMentionUsers = false;

  final List<String> talents = [
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
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
    _contentController.addListener(_handleMentionInputChanged);
    _contentFocusNode.addListener(_handleComposerFocusChanged);
  }

  @override
  void dispose() {
    _contentController.removeListener(_handleMentionInputChanged);
    _contentFocusNode.removeListener(_handleComposerFocusChanged);
    _contentFocusNode.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _handleComposerFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _ensureMentionableUsersLoaded() async {
    if (_mentionableUsers.isNotEmpty || _isLoadingMentionUsers) return;

    _isLoadingMentionUsers = true;
    try {
      final users = await _userService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _mentionableUsers = users;
      });
    } finally {
      _isLoadingMentionUsers = false;
    }
  }

  Future<void> _handleMentionInputChanged() async {
    final query = MentionUtils.activeMentionQuery(
      _contentController.text,
      _contentController.selection,
    );

    if (query == null) {
      if (_activeMentionQuery != null || _filteredMentionUsers.isNotEmpty) {
        setState(() {
          _activeMentionQuery = null;
          _filteredMentionUsers = const [];
        });
      }
      return;
    }

    await _ensureMentionableUsersLoaded();
    if (!mounted) return;

    final normalizedQuery = query.toLowerCase();
    final currentUserId = _authService.currentUser?.uid;
    final matchingUsers = _mentionableUsers
        .where((user) {
          if (user.uid == currentUserId) return false;
          final handle =
              user.username ??
              MentionUtils.normalizeDisplayNameToHandle(user.displayName);
          return normalizedQuery.isEmpty ||
              handle.startsWith(normalizedQuery) ||
              user.displayName.toLowerCase().contains(normalizedQuery);
        })
        .take(6)
        .toList();

    setState(() {
      _activeMentionQuery = query;
      _filteredMentionUsers = matchingUsers;
    });
  }

  void _insertMentionHandle(String handle) {
    final nextValue = MentionUtils.insertMention(
      text: _contentController.text,
      selection: _contentController.selection,
      handle: handle,
    );

    _contentController.value = nextValue;
    setState(() {
      _activeMentionQuery = null;
      _filteredMentionUsers = const [];
    });
  }

  Widget _buildMentionSuggestions(BuildContext context) {
    if (_activeMentionQuery == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final showFollowers = 'followers'.startsWith(
      _activeMentionQuery!.toLowerCase(),
    );
    final hasSuggestions = showFollowers || _filteredMentionUsers.isNotEmpty;

    if (!hasSuggestions) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showFollowers)
            ListTile(
              dense: true,
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('@followers'),
              subtitle: const Text('Notify all of your followers'),
              onTap: () => _insertMentionHandle('followers'),
            ),
          ..._filteredMentionUsers.map((user) {
            final handle =
                user.username ??
                MentionUtils.normalizeDisplayNameToHandle(user.displayName);
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundImage: user.profileImageUrl != null
                    ? CachedNetworkImageProvider(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              title: Text(user.displayName),
              subtitle: Text('@$handle'),
              onTap: () => _insertMentionHandle(handle),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.image,
      );

      if (result != null && result.files.isNotEmpty) {
        final Map<String, Uint8List> newBytes = {};
        final List<XFile> pickedFiles = [];

        for (final file in result.files) {
          final path = file.path;
          if (path == null) continue;
          if (_imageBytes.containsKey(path)) continue; // avoid duplicates

          final xFile = XFile(path);
          pickedFiles.add(xFile);
          
          final bytes = await xFile.readAsBytes();
          newBytes[path] = bytes;
        }

        setState(() {
          _selectedImages.addAll(pickedFiles);
          _imageBytes.addAll(newBytes);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking images: $e';
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      final imagePath = _selectedImages[index].path;
      _imageBytes.remove(imagePath); // Remove cached bytes
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _pickVideo() async {
    try {
      final file = await fp.FilePicker.pickFile(
        type: fp.FileType.video,
      );
      if (file != null && file.path != null) {
        setState(() {
          _selectedVideo = XFile(file.path!);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking video: $e';
      });
    }
  }

  Widget _buildRemoveButton() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white24
            : Colors.black54,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(4),
      child: const Icon(Icons.close, color: Colors.white, size: 16),
    );
  }

  Future<void> _createPost() async {
    // Validation
    if (_contentController.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _selectedVideo == null) {
      setState(() {
        _errorMessage = 'Please add content, image, or video to your post';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check authentication
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to create a post');
      }

      // Get user data
      var userData = await _userService.getUser(currentUser.uid);
      if (userData == null) {
        // Try to create a default profile if it doesn't exist
        try {
          final defaultUser = UserModel(
            uid: currentUser.uid,
            email: currentUser.email ?? '',
            displayName: currentUser.displayName ?? 'User',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _firebaseFirestore
              .collection('users')
              .doc(currentUser.uid)
              .set(defaultUser.toJson());

          userData = defaultUser;
        } catch (e) {
          throw Exception(
            'Your user profile could not be found. Please log out and log in again to sync your profile.',
          );
        }
      }

      // Validate content
      final trimmedContent = _contentController.text.trim();
      if (trimmedContent.isEmpty &&
          _selectedImages.isEmpty &&
          _selectedVideo == null) {
        throw Exception('Post must have content, images, or video');
      }

      // Create post with better error handling
      await _postService.createPost(
        authorId: currentUser.uid,
        authorName: userData.displayName,
        authorUsername: userData.username,
        authorImageUrl: userData.profileImageUrl,
        content: trimmedContent,
        imageFiles: List.from(_selectedImages),
        imageBytes: Map.from(_imageBytes),
        talent: _selectedTalent,
        videoFile: _selectedVideo,
      );

      // Clear form and show success
      if (mounted) {
        _contentController.clear();
        setState(() {
          _selectedImages.clear();
          _imageBytes.clear();
          _selectedVideo = null;
          _selectedTalent = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully! 🎉'),
            duration: Duration(seconds: 2),
          ),
        );

        // Return to home screen
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      String errorMessage = 'Error creating post';

      // Provide user-friendly error messages
      if (e.toString().contains('Failed to upload image')) {
        errorMessage = '$e - Check your internet connection';
      } else if (e.toString().contains('Failed to save post')) {
        errorMessage = 'Could not save post - check permissions';
      } else if (e.toString().contains('not authenticated')) {
        errorMessage = 'Please log in again to create a post';
      } else if (e.toString().contains('profile not found')) {
        errorMessage = 'Please complete your profile first';
      } else {
        errorMessage = e.toString();
      }

      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final hasKeyboard = bottomInset > 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('New Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: FilledButton(
                onPressed: _isLoading ? null : _createPost,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(80, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author row with Avatar
                  FutureBuilder<UserModel?>(
                    future: _userService.getUser(_authService.currentUser?.uid ?? ''),
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: user?.profileImageUrl != null
                                ? CachedNetworkImageProvider(user!.profileImageUrl!)
                                : null,
                            child: user?.profileImageUrl == null
                                ? const Icon(Icons.person, size: 28)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName ?? 'Your Name',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_selectedTalent != null)
                                  Text(
                                    _selectedTalent!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else
                                  Text(
                                    'Choose a talent category',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Content text field - Borderless for "Composer" feel
                  TextField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    maxLines: null, // Auto-expanding
                    autofocus: widget.initialContent == null,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: 'Share your creativity...',
                      hintStyle: TextStyle(fontSize: 18, color: Colors.grey),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  _buildMentionSuggestions(context),
                  const SizedBox(height: 16),

                  // Selected media preview
                  if (_selectedImages.isNotEmpty || _selectedVideo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length + (_selectedVideo != null ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_selectedVideo != null && index == 0) {
                              return _buildVideoPreview();
                            }
                            final imageIndex = _selectedVideo != null ? index - 1 : index;
                            return _buildImagePreview(imageIndex);
                          },
                        ),
                      ),
                    ),
                  // Error message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Composer Toolbar - Always pinned to keyboard or bottom
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
            ),
            padding: EdgeInsets.only(bottom: bottomInset > 0 ? 0 : MediaQuery.paddingOf(context).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hasKeyboard) const KeyboardPromptBanner(visible: true, text: 'Finalize your masterpiece.'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.image_outlined, color: theme.colorScheme.primary),
                        onPressed: _pickImage,
                        tooltip: 'Add Images',
                      ),
                      IconButton(
                        icon: Icon(Icons.videocam_outlined, color: theme.colorScheme.primary),
                        onPressed: _pickVideo,
                        tooltip: 'Add Video',
                      ),
                      IconButton(
                        icon: Icon(Icons.star_outline, color: theme.colorScheme.primary),
                        onPressed: _showTalentPicker,
                        tooltip: 'Set Talent',
                      ),
                      const Spacer(),
                      Text(
                        '${_contentController.text.length}/280',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _contentController.text.length > 280 ? Colors.red : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Stack(
        children: [
          Container(
            width: 140,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Center(
              child: Icon(Icons.videocam, color: Colors.white, size: 48),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _selectedVideo = null),
              child: _buildRemoveButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: kIsWeb
                ? Image.network(_selectedImages[index].path, width: 140, height: 160, fit: BoxFit.cover)
                : Image.file(File(_selectedImages[index].path), width: 140, height: 160, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: _buildRemoveButton(),
            ),
          ),
        ],
      ),
    );
  }

  void _showTalentPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Talent Category', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: ListView.builder(
                itemCount: talents.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(talents[index]),
                  trailing: _selectedTalent == talents[index] ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () {
                    setState(() => _selectedTalent = talents[index]);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
