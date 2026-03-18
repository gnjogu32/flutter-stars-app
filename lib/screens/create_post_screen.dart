import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/post_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;

  final List<XFile> _selectedImages = [];
  final Map<String, Uint8List> _imageBytes = {}; // Store bytes immediately
  XFile? _selectedAudio;
  Uint8List? _audioBytes;
  XFile? _selectedVideo;
  Uint8List? _videoBytes;
  String? _selectedTalent;
  bool _isLoading = false;
  String? _errorMessage;

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
  void dispose() {
    _contentController.dispose();
    super.dispose();
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

  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.xFiles.first;
      final pickedPlatformFile = result.files.first;
      final bytes = pickedPlatformFile.bytes ?? await pickedFile.readAsBytes();

      setState(() {
        _selectedAudio = pickedFile;
        _audioBytes = bytes;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking audio: $e';
      });
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      // User cancelled picker
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedVideo = pickedFile;
        _videoBytes = bytes;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking video: $e';
      });
    }
  }

  Future<void> _createPost() async {
    // Validation
    if (_contentController.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _selectedAudio == null &&
        _selectedVideo == null) {
      setState(() {
        _errorMessage =
            'Please add content, image, audio, or video to your post';
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
          _selectedAudio == null &&
          _selectedVideo == null) {
        throw Exception('Post must have content, images, audio, or video');
      }

      // Create post with better error handling
      await _postService.createPost(
        authorId: currentUser.uid,
        authorName: userData.displayName,
        authorImageUrl: userData.profileImageUrl,
        content: trimmedContent,
        imageFiles: List.from(_selectedImages),
        imageBytes: Map.from(_imageBytes),
        audioFile: _selectedAudio,
        audioBytes: _audioBytes,
        videoFile: _selectedVideo,
        videoBytes: _videoBytes,
        talent: _selectedTalent,
      );

      // Clear form and show success
      if (mounted) {
        _contentController.clear();
        setState(() {
          _selectedImages.clear();
          _imageBytes.clear();
          _selectedAudio = null;
          _audioBytes = null;
          _selectedVideo = null;
          _videoBytes = null;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content text field
            TextField(
              controller: _contentController,
              maxLines: 6,
              minLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your creativity...',
                helperText: 'Tip: Use @followers to notify your followers.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
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

            // Audio/Video selection buttons
            Text(
              'Add Audio/Video (Optional)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickAudio,
                    icon: const Icon(Icons.audio_file),
                    label: const Text('Audio'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickVideo,
                    icon: const Icon(Icons.video_file),
                    label: const Text('Video'),
                  ),
                ),
              ],
            ),
            if (_selectedAudio != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(Icons.music_note),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Audio: ${_selectedAudio!.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedAudio = null;
                        _audioBytes = null;
                      }),
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
            if (_selectedVideo != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(Icons.videocam),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Video: ${_selectedVideo!.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedVideo = null;
                        _videoBytes = null;
                      }),
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Image selection buttons
            Text(
              'Add Images (Optional)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Gallery (Multi)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Selected images preview
            if (_selectedImages.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Images (${_selectedImages.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb
                                    ? Image.network(
                                        _selectedImages[index].path,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(_selectedImages[index].path),
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
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
