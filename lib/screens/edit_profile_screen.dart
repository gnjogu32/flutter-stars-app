import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart' as fp;
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
  XFile? _selectedCoverImage;
  Uint8List? _selectedCoverImageBytes;
  DateTime? _birthday;
  bool _birthdayPublic = false;
  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUser;
  bool _shouldDeletePhoto = false;
  bool _shouldDeleteCover = false;

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
    if (mounted) setState(() {});
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
            _birthday = user?.birthday;
            _birthdayPublic = user?.birthdayPublic ?? false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error loading profile: $e');
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
    try {
      final file = await fp.FilePicker.pickFile(type: fp.FileType.image);
      if (file != null && file.path != null) {
        final path = file.path!;
        final bytes = await File(path).readAsBytes();
        setState(() {
          _selectedProfileImage = XFile(path);
          _selectedProfileImageBytes = bytes;
          _shouldDeletePhoto = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error picking image: $e');
    }
  }

  Future<void> _pickProfileImageFromCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _errorMessage = 'Camera permission denied.');
      return;
    }
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedProfileImage = pickedFile;
          _selectedProfileImageBytes = bytes;
          _shouldDeletePhoto = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error picking image: $e');
    }
  }

  void _removeProfileImage() {
    setState(() {
      _selectedProfileImage = null;
      _selectedProfileImageBytes = null;
      _shouldDeletePhoto = true;
    });
  }

  void _removeCoverImage() {
    setState(() {
      _selectedCoverImage = null;
      _selectedCoverImageBytes = null;
      _shouldDeleteCover = true;
    });
  }

  Future<void> _pickCoverImageFromGallery() async {
    try {
      final file = await fp.FilePicker.pickFile(type: fp.FileType.image);
      if (file != null && file.path != null) {
        final path = file.path!;
        final bytes = await File(path).readAsBytes();
        setState(() {
          _selectedCoverImage = XFile(path);
          _selectedCoverImageBytes = bytes;
          _shouldDeleteCover = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error picking cover image: $e');
      }
    }
  }

  void _showCoverPhotoPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickCoverImageFromGallery();
              },
            ),
            if (_selectedCoverImageBytes != null ||
                (_currentUser?.coverImageUrl != null && !_shouldDeleteCover))
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove Current Cover',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeCoverImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showProfilePhotoPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImageFromCamera();
              },
            ),
            if (_selectedProfileImageBytes != null ||
                (_currentUser?.profileImageUrl != null && !_shouldDeletePhoto))
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove Current Photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfileImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfile() async {
    final displayName = _displayNameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    if (displayName.isEmpty) {
      setState(() => _errorMessage = 'Display name cannot be empty');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');
      if (username.isNotEmpty && username != _currentUser?.username) {
        final isAvailable = await _userService.isUsernameAvailable(username);
        if (!isAvailable) throw Exception('Username is already taken');
      }
      String? profileImageUrl = _currentUser?.profileImageUrl;
      String? coverImageUrl = _currentUser?.coverImageUrl;
      if (_selectedProfileImage != null && _selectedProfileImageBytes != null) {
        profileImageUrl = await _userService.uploadProfileImageFromBytes(
          userId,
          _selectedProfileImage!,
          _selectedProfileImageBytes!,
        );
        _shouldDeletePhoto = false;
      } else if (_shouldDeletePhoto && _currentUser?.profileImageUrl != null) {
        profileImageUrl = null;
        try {
          await _userService.deleteOldProfileImage(userId);
        } catch (e) {
          debugPrint('Error deleting old profile image: $e');
        }
      }
      if (_selectedCoverImage != null && _selectedCoverImageBytes != null) {
        coverImageUrl = await _userService.uploadCoverImageFromBytes(
          userId,
          _selectedCoverImage!,
          _selectedCoverImageBytes!,
        );
        _shouldDeleteCover = false;
      } else if (_shouldDeleteCover && _currentUser?.coverImageUrl != null) {
        coverImageUrl = null;
        try {
          await _userService.deleteOldCoverImage(userId);
        } catch (e) {
          debugPrint('Error deleting old cover image: $e');
        }
      }
      await _userService.updateUserProfile(
        uid: userId,
        displayName: displayName,
        username: username.isEmpty ? null : username,
        bio: _bioController.text.trim(),
        profileImageUrl: profileImageUrl,
        coverImageUrl: coverImageUrl,
        talent: _selectedTalent,
        clearProfileImage:
            _shouldDeletePhoto && _currentUser?.profileImageUrl != null,
        clearCoverImage:
            _shouldDeleteCover && _currentUser?.coverImageUrl != null,
        birthday: _birthday,
        birthdayPublic: _birthdayPublic,
      );
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
        setState(
          () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;
    final editingBio = _bioFocusNode.hasFocus;

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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _showCoverPhotoPicker,
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                        image: _selectedCoverImageBytes != null
                            ? DecorationImage(
                                image: MemoryImage(_selectedCoverImageBytes!),
                                fit: BoxFit.cover,
                              )
                            : (!_shouldDeleteCover &&
                                      _currentUser?.coverImageUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        _currentUser!.coverImageUrl!,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null),
                      ),
                      child: Stack(
                        children: [
                          if (_selectedCoverImageBytes == null &&
                              (_shouldDeleteCover ||
                                  _currentUser?.coverImageUrl == null))
                            const Center(
                              child: Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Colors.grey,
                              ),
                            ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                              backgroundImage:
                                  _selectedProfileImageBytes != null
                                  ? MemoryImage(_selectedProfileImageBytes!)
                                  : (!_shouldDeletePhoto &&
                                            _currentUser?.profileImageUrl !=
                                                null
                                        ? NetworkImage(
                                            _currentUser!.profileImageUrl!,
                                          )
                                        : null),
                              child:
                                  _selectedProfileImageBytes == null &&
                                      (_shouldDeletePhoto ||
                                          _currentUser?.profileImageUrl == null)
                                  ? const Icon(Icons.person, size: 60)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _showProfilePhotoPicker,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.surface,
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
                          if (_selectedProfileImageBytes != null ||
                              (_currentUser?.profileImageUrl != null &&
                                  !_shouldDeletePhoto))
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
                                      color: theme.colorScheme.surface,
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
                  TextField(
                    controller: _displayNameController,
                    focusNode: _displayNameFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    focusNode: _usernameFocusNode,
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
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9._]'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bioController,
                    focusNode: _bioFocusNode,
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
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTalent,
                    items: talents
                        .map(
                          (String talent) => DropdownMenuItem<String>(
                            value: talent,
                            child: Text(talent),
                          ),
                        )
                        .toList(),
                    onChanged: (String? newValue) =>
                        setState(() => _selectedTalent = newValue),
                    decoration: InputDecoration(
                      labelText: 'Your Talent',
                      prefixIcon: const Icon(Icons.star),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _birthday ?? DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() => _birthday = pickedDate);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Birthday',
                        prefixIcon: const Icon(Icons.cake),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _birthday == null
                                ? 'Select Birthday'
                                : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
                          ),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Public Birthday'),
                    subtitle: const Text('Show your birthday on your profile'),
                    value: _birthdayPublic,
                    onChanged: (bool value) =>
                        setState(() => _birthdayPublic = value),
                    secondary: const Icon(Icons.visibility),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 24),
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
          ),
          if (isKeyboardVisible)
            Material(
              elevation: 12,
              color: theme.colorScheme.surface,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        editingBio
                            ? Icons.description_outlined
                            : Icons.person_outline,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        editingBio
                            ? 'Editing your bio.'
                            : 'Editing your profile info.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
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
}
