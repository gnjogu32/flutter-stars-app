import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/post_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../utils/mention_utils.dart';
import '../models/user_model.dart';
import '../widgets/keyboard_prompt_banner.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
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
          final handle = MentionUtils.normalizeDisplayNameToHandle(
            user.displayName,
          );
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
            final handle = MentionUtils.normalizeDisplayNameToHandle(
              user.displayName,
            );
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundImage: user.profileImageUrl != null
                    ? NetworkImage(user.profileImageUrl!)
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
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage();

      if (pickedFiles.isNotEmpty) {
        final Map<String, Uint8List> newBytes = {};
        for (final file in pickedFiles) {
          if (_imageBytes.containsKey(file.path)) continue; // avoid duplicates
          newBytes[file.path] = await file.readAsBytes();
        }

        setState(() {
          _selectedImages.addAll(
            pickedFiles.where((file) => !_imageBytes.containsKey(file.path)),
          );
          _imageBytes.addAll(newBytes);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking images: $e';
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );

      if (pickedFile != null) {
        // Read bytes immediately to prevent cache deletion issues
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImages.add(pickedFile);
          _imageBytes[pickedFile.path] = bytes;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error taking photo: $e';
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
      final result = await fp.FilePicker.pickFiles(type: fp.FileType.video);
      if (result != null) {
        final file = result.files.single;
        if (file.path == null) return;

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

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.6,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Add Media',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildPickerOption(
                      icon: Icons.photo_library,
                      label: 'Gallery (Multi)',
                      subtitle: 'Choose from your photos',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage();
                      },
                    ),
                    _buildPickerOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      subtitle: 'Take a new photo',
                      onTap: () {
                        Navigator.pop(context);
                        _takePhoto();
                      },
                    ),
                    _buildPickerOption(
                      icon: Icons.videocam,
                      label: 'Video',
                      subtitle: 'Select a video file',
                      onTap: () {
                        Navigator.pop(context);
                        _pickVideo();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
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
    final showKeyboardPrompt = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        centerTitle: true,
        elevation: 0,
      ),
      bottomNavigationBar: showKeyboardPrompt
          ? SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Media Toolbar for easy access while typing
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _showMediaPicker,
                          icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                          tooltip: 'Add Media',
                        ),
                        IconButton(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image_outlined),
                          tooltip: 'Gallery',
                        ),
                        IconButton(
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.camera_alt_outlined),
                          tooltip: 'Camera',
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _isLoading ? null : _createPost,
                          child: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      MediaQuery.viewInsetsOf(context).bottom + 12,
                    ),
                    child: const KeyboardPromptBanner(
                      visible: true,
                      text:
                          'Sharing your post. Add the final details before publishing.',
                      icon: Icons.edit_note_outlined,
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content text field
            TextField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              maxLines: 6,
              minLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your creativity...',
                helperText: 'Tip: Type @ to mention people or use @followers.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            _buildMentionSuggestions(context),
            const SizedBox(height: 16),

            // Talent selection
            Text(
              'Select Your Talent Category',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedTalent,
              items: talents.map((String talent) {
                return DropdownMenuItem<String>(
                  value: talent,
                  child: Text(talent),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedTalent = newValue;
                });
              },
              decoration: InputDecoration(
                hintText: 'Select a talent',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Media Selection Trigger
            Text(
              'Add Media',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _showMediaPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add photos or video',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selected media preview
            if (_selectedImages.isNotEmpty || _selectedVideo != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attachments',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length + (_selectedVideo != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_selectedVideo != null && index == 0) {
                          // Video Preview
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Stack(
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.videocam, color: Colors.white, size: 40),
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

                        final imageIndex = _selectedVideo != null ? index - 1 : index;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb
                                    ? Image.network(
                                        _selectedImages[imageIndex].path,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(_selectedImages[imageIndex].path),
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(imageIndex),
                                  child: _buildRemoveButton(),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 24),

            // Post button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createPost,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
