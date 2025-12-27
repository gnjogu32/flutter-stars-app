import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

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
  late TextEditingController _bioController;
  String? _selectedTalent;
  File? _selectedProfileImage;
  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUser;

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
    _bioController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        final user = await _userService.getUser(userId);
        setState(() {
          _currentUser = user;
          _displayNameController.text = user?.displayName ?? '';
          _bioController.text = user?.bio ?? '';
          _selectedTalent = user?.talent;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: $e';
      });
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedProfileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_displayNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Display name cannot be empty';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      String? profileImageUrl;

      // Upload profile image to Firebase Storage if selected
      if (_selectedProfileImage != null) {
        profileImageUrl = await _userService.uploadProfileImage(
          userId,
          _selectedProfileImage!,
        );
      }

      // Update user profile with new data
      await _userService.updateUserProfile(
        uid: userId,
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        profileImageUrl: profileImageUrl,
        talent: _selectedTalent,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating profile: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Image
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: _selectedProfileImage != null
                      ? FileImage(_selectedProfileImage!)
                      : (_currentUser?.profileImageUrl != null
                            ? NetworkImage(_currentUser!.profileImageUrl!)
                            : null),
                  child:
                      _selectedProfileImage == null &&
                          _currentUser?.profileImageUrl == null
                      ? const Icon(Icons.person, size: 60)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickProfileImage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
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
              ],
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
