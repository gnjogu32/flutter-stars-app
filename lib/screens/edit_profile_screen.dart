import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import 'auth/change_password_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _displayNameController;
  final FocusNode _displayNameFocusNode = FocusNode();
  late TextEditingController _usernameController;
  final FocusNode _usernameFocusNode = FocusNode();
  late TextEditingController _bioController;
  final FocusNode _bioFocusNode = FocusNode();
  String? _selectedTalent;
  XFile? _selectedProfileImage;
  Uint8List? _selectedProfileImageBytes;
  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUser;
  bool _shouldDeletePhoto = false; // Track if user wants to delete photo

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
    _displayNameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
    _displayNameFocusNode.addListener(_handleFocusChanged);
    _usernameFocusNode.addListener(_handleFocusChanged);
    _bioFocusNode.addListener(_handleFocusChanged);
    _loadUserData();
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        final user = await _userService.getUser(userId);
        if (mounted) {
          setState(() {
            _currentUser = user;
            _displayNameController.text = user?.displayName ?? '';
            _usernameController.text = user?.username ?? '';
            _bioController.text = user?.bio ?? '';
            _selectedTalent = user?.talent;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading profile: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _displayNameFocusNode.removeListener(_handleFocusChanged);
    _usernameFocusNode.removeListener(_handleFocusChanged);
    _bioFocusNode.removeListener(_handleFocusChanged);
    _displayNameFocusNode.dispose();
    _usernameFocusNode.dispose();
    _bioFocusNode.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImageFromGallery() async {
    await _pickProfileImageFromSource(ImageSource.gallery);
  }

  Future<void> _pickProfileImageFromCamera() async {
    await _pickProfileImageFromSource(ImageSource.camera);
  }

  Future<void> _pickProfileImageFromSource(ImageSource source) async {
    // For camera, explicitly request the permission first.
    // For gallery, image_picker uses the system photo-picker intent on Android
    // which needs no READ_MEDIA_IMAGES grant, so we skip the manual check to
    // avoid false "permission denied" errors on Android 13/14.
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Camera permission denied. Please grant camera permission in Settings.';
          });
        }
        return;
      }
    }

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: source);

      if (pickedFile != null) {
        // Read bytes immediately to prevent cache deletion issues
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedProfileImage = pickedFile;
          _selectedProfileImageBytes = bytes;
          _shouldDeletePhoto =
              false; // Reset delete flag when picking new image
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error picking image: $e';
        });
      }
    }
  }

  void _removeProfileImage() {
    setState(() {
      _selectedProfileImage = null;
      _selectedProfileImageBytes = null;
      _shouldDeletePhoto = true; // Mark that we want to delete the photo
    });
  }

  void _showProfilePhotoPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.35,
        minChildSize: 0.2,
        maxChildSize: 0.5,
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
                  'Change Profile Photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.photo_library,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: const Text(
                        'Choose from Gallery',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _pickProfileImageFromGallery();
                      },
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: const Text(
                        'Take a Photo',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _pickProfileImageFromCamera();
                      },
                    ),
                    if (_selectedProfileImageBytes != null ||
                        (_currentUser?.profileImageUrl != null &&
                            !_shouldDeletePhoto))
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                        title: const Text(
                          'Remove Current Photo',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _removeProfileImage();
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

  Future<void> _updateProfile() async {
    final displayName = _displayNameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();

    if (displayName.isEmpty) {
      setState(() {
        _errorMessage = 'Display name cannot be empty';
      });
      return;
    }

    if (username.isNotEmpty) {
      if (username.length < 3) {
        setState(() {
          _errorMessage = 'Username must be at least 3 characters';
        });
        return;
      }
      if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(username)) {
        setState(() {
          _errorMessage =
              'Username can only contain letters, numbers, dots, and underscores';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Check username uniqueness if it changed
      if (username.isNotEmpty && username != _currentUser?.username) {
        final isAvailable = await _userService.isUsernameAvailable(username);
        if (!isAvailable) {
          throw Exception('Username is already taken');
        }
      }

      String? profileImageUrl = _currentUser?.profileImageUrl;

      // Upload new profile image to Firebase Storage if selected
      if (_selectedProfileImage != null && _selectedProfileImageBytes != null) {
        profileImageUrl = await _userService.uploadProfileImageFromBytes(
          userId,
          _selectedProfileImage!,
          _selectedProfileImageBytes!,
        );
        _shouldDeletePhoto = false; // Reset flag after uploading new image
      }
      // If user wants to delete the photo
      else if (_shouldDeletePhoto && _currentUser?.profileImageUrl != null) {
        profileImageUrl = null;

        // Delete old profile image from storage
        try {
          await _userService.deleteOldProfileImage(userId);
        } catch (e) {
          if (kDebugMode) print('Error deleting old image: $e');
        }
      }

      // Update user profile with new data
      await _userService.updateUserProfile(
        uid: userId,
        displayName: displayName,
        username: username.isEmpty ? null : username,
        bio: _bioController.text.trim(),
        profileImageUrl: profileImageUrl,
        talent: _selectedTalent,
        clearProfileImage:
            _shouldDeletePhoto && _currentUser?.profileImageUrl != null,
      );

      // Keep Firebase Auth display name in sync with Firestore
      final currentAuthUser = _authService.currentUser;
      if (currentAuthUser != null &&
          currentAuthUser.displayName != displayName) {
        await currentAuthUser.updateDisplayName(displayName);
        await currentAuthUser.reload();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
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
        title: const Text('Edit Profile'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Change Password',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Image
            Center(
              child: SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: _showProfilePhotoPicker,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: _selectedProfileImageBytes != null
                            ? MemoryImage(_selectedProfileImageBytes!)
                            : (!_shouldDeletePhoto &&
                                      _currentUser?.profileImageUrl != null
                                  ? NetworkImage(_currentUser!.profileImageUrl!)
                                  : null),
                        child:
                            _selectedProfileImageBytes == null &&
                                (_shouldDeletePhoto ||
                                    _currentUser?.profileImageUrl == null)
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                    ),
                    // Camera icon button
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showProfilePhotoPicker,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    // Delete icon button (only show if there's a photo and not already deleted)
                    if ((_selectedProfileImageBytes != null ||
                        (_currentUser?.profileImageUrl != null &&
                            !_shouldDeletePhoto)))
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _removeProfileImage,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Display Name
            TextField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: 'Display Name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Username
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixIcon: const Icon(Icons.alternate_email),
                prefixText: '@',
                helperText: 'Unique handle for mentions',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
              ],
            ),
            const SizedBox(height: 16),

            // Bio
            TextField(
              controller: _bioController,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                labelText: 'Bio',
                prefixIcon: const Icon(Icons.description),
                hintText: 'Tell us about yourself...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Talent Selection
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
                labelText: 'Your Talent',
                prefixIcon: const Icon(Icons.star),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Error Message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
