import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:video_player/video_player.dart';
import '../services/post_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../utils/mention_utils.dart';
import '../models/user_model.dart';

class CreatePostScreen extends StatefulWidget {
  final String? initialContent;
  const CreatePostScreen({super.key, this.initialContent});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late final TextEditingController _contentController;
  final FocusNode _contentFocusNode = FocusNode();
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  final List<XFile> _selectedImages = [];
  final Map<String, Uint8List> _imageBytes = {};
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

  UserModel? _currentUserData;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
    _contentController.addListener(_handleMentionInputChanged);
    _contentFocusNode.addListener(_handleComposerFocusChanged);
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      final user = await _userService.getUser(uid);
      if (mounted) {
        setState(() {
          _currentUserData = user;
        });
      }
    }
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
    if (mounted) setState(() {});
  }

  Future<void> _ensureMentionableUsersLoaded() async {
    if (_mentionableUsers.isNotEmpty || _isLoadingMentionUsers) return;
    _isLoadingMentionUsers = true;
    try {
      final users = await _userService.getAllUsers();
      if (mounted) setState(() => _mentionableUsers = users);
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
    _contentController.value = MentionUtils.insertMention(
      text: _contentController.text,
      selection: _contentController.selection,
      handle: handle,
    );
    setState(() {
      _activeMentionQuery = null;
      _filteredMentionUsers = const [];
    });
    _contentFocusNode.requestFocus();
  }

  Widget _buildMentionSuggestions() {
    if (_activeMentionQuery == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final showFollowers =
        'followers'.startsWith(_activeMentionQuery!.toLowerCase());

    if (!showFollowers && _filteredMentionUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          if (showFollowers)
            ListTile(
              dense: true,
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('@followers'),
              onTap: () => _insertMentionHandle('followers'),
            ),
          ..._filteredMentionUsers.map((user) {
            final handle =
                user.username ??
                MentionUtils.normalizeDisplayNameToHandle(user.displayName);
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundImage: user.profileImageUrl != null
                    ? CachedNetworkImageProvider(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null
                    ? const Icon(Icons.person, size: 14)
                    : null,
              ),
              title: Text(
                user.displayName,
                style: const TextStyle(fontSize: 12),
              ),
              subtitle: Text('@$handle', style: const TextStyle(fontSize: 10)),
              onTap: () => _insertMentionHandle(handle),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final result = await FilePicker.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
        if (result != null && result.files.isNotEmpty) {
          final Map<String, Uint8List> newBytes = {};
          final List<XFile> pickedFiles = [];
          for (final file in result.files) {
            if (file.path == null) continue;
            if (_imageBytes.containsKey(file.path)) continue;
            final xFile = XFile(file.path!);
            pickedFiles.add(xFile);
            newBytes[file.path!] = await xFile.readAsBytes();
          }
          setState(() {
            _selectedImages.addAll(pickedFiles);
            _imageBytes.addAll(newBytes);
          });
        }
      } else {
        final picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: source);
        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImages.add(image);
            _imageBytes[image.path] = bytes;
          });
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error picking images: $e');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final result = await FilePicker.pickFiles(type: FileType.video);
        if (result != null && result.files.single.path != null) {
          setState(() {
            _selectedVideo = XFile(result.files.single.path!);
            _errorMessage = null;
          });
        }
      } else {
        final picker = ImagePicker();
        final XFile? video = await picker.pickVideo(source: source);
        if (video != null) {
          setState(() {
            _selectedVideo = video;
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error picking video: $e');
    }
  }

  void _showVideoFullScreenPreview() {
    if (_selectedVideo == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _LocalVideoPreviewScreen(
          file: File(_selectedVideo!.path),
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      final path = _selectedImages[index].path;
      _selectedImages.removeAt(index);
      _imageBytes.remove(path);
    });
  }

  void _removeVideo() {
    setState(() {
      _selectedVideo = null;
    });
  }

  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _selectedVideo == null) {
      setState(
        () =>
            _errorMessage = 'Please add content, image, or video to your post',
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to create a post');
      }
      final userData = await _userService.getUser(currentUser.uid);
      if (userData == null) {
        throw Exception('Your profile info was not found.');
      }
      await _postService.createPost(
        authorId: currentUser.uid,
        authorName: userData.displayName,
        authorUsername: userData.username,
        authorImageUrl: userData.profileImageUrl,
        content: _contentController.text.trim(),
        imageFiles: List.from(_selectedImages),
        imageBytes: Map.from(_imageBytes),
        talent: _selectedTalent,
        videoFile: _selectedVideo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully! 🎉')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMediaReview() {
    if (_selectedImages.isEmpty && _selectedVideo == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);

    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _selectedImages.length + (_selectedVideo != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _selectedImages.length) {
            final xFile = _selectedImages[index];
            final bytes = _imageBytes[xFile.path];
            return Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: bytes != null
                        ? Image.memory(bytes, fit: BoxFit.cover)
                        : Image.file(File(xFile.path), fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return GestureDetector(
              onTap: _showVideoFullScreenPreview,
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.1),
                      theme.colorScheme.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _LocalVideoThumbnail(file: File(_selectedVideo!.path)),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _removeVideo,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white70,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: FilledButton(
                onPressed: _isLoading ? null : _createPost,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Post'),
              ),
            ),
          ),
        ],
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Extra padding for transparent AppBar
          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
              
              // Talent Picker Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: _currentUserData?.profileImageUrl != null
                          ? CachedNetworkImageProvider(_currentUserData!.profileImageUrl!)
                          : null,
                      child: _currentUserData?.profileImageUrl == null
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showTalentPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedTalent ?? 'Choose category',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _selectedTalent == null ? theme.hintColor : theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down, size: 18, color: theme.hintColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Full Screen Typing Area
              Expanded(
                child: TextField(
                  controller: _contentController,
                  focusNode: _contentFocusNode,
                  maxLines: null,
                  minLines: null,
                  expands: true,
                  autofocus: widget.initialContent == null,
                  style: const TextStyle(fontSize: 18, height: 1.5),
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Share your creativity...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                    fillColor: Colors.transparent, // Override theme
                  ),
                ),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),

              _buildMentionSuggestions(),
              _buildMediaReview(),

              // Media Selection Toolbar
              Material(
                elevation: 8,
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.image_outlined, color: theme.colorScheme.primary),
                          onPressed: () => _pickImage(ImageSource.gallery),
                          tooltip: 'Add Images',
                        ),
                        IconButton(
                          icon: Icon(Icons.camera_alt_outlined, color: theme.colorScheme.primary),
                          onPressed: () => _pickImage(ImageSource.camera),
                          tooltip: 'Take Photo',
                        ),
                        IconButton(
                          icon: Icon(Icons.videocam_outlined, color: theme.colorScheme.primary),
                          onPressed: () => _pickVideo(ImageSource.gallery),
                          tooltip: 'Add Video',
                        ),
                        IconButton(
                          icon: Icon(Icons.video_call_outlined, color: theme.colorScheme.primary),
                          onPressed: () => _pickVideo(ImageSource.camera),
                          tooltip: 'Record Video',
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            '${_contentController.text.length}/280',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _contentController.text.length > 280 ? Colors.red : theme.hintColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _showTalentPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose Category', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: talents.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(talents[index]),
                  onTap: () {
                    setState(() => _selectedTalent = talents[index]);
                    Navigator.pop(context);
                  },
                  trailing: _selectedTalent == talents[index]
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalVideoThumbnail extends StatefulWidget {
  final File file;
  const _LocalVideoThumbnail({required this.file});

  @override
  State<_LocalVideoThumbnail> createState() => _LocalVideoThumbnailState();
}

class _LocalVideoThumbnailState extends State<_LocalVideoThumbnail> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(color: Colors.black12);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: VideoPlayer(_controller),
    );
  }
}

class _LocalVideoPreviewScreen extends StatefulWidget {
  final File file;
  const _LocalVideoPreviewScreen({required this.file});

  @override
  State<_LocalVideoPreviewScreen> createState() => _LocalVideoPreviewScreenState();
}

class _LocalVideoPreviewScreenState extends State<_LocalVideoPreviewScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
          _controller.setLooping(true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Video Preview', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: _initialized
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller),
                      if (!_controller.value.isPlaying)
                        const Icon(Icons.play_arrow, size: 80, color: Colors.white54),
                    ],
                  ),
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
