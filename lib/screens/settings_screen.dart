import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: userId == null
          ? const Center(child: Text('Please log in to view settings.'))
          : FutureBuilder<UserModel?>(
              future: _userService.getUser(userId),
              builder: (context, snapshot) {
                final user = snapshot.data;
                final notificationsEnabled = user?.notificationsEnabled ?? true;

                return ListView(
                  children: [
                    _buildSectionHeader(context, 'Account'),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Edit Profile'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context).pushNamed('/edit-profile'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Change Password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context).pushNamed('/change-password'),
                    ),

                    _buildSectionHeader(context, 'Notifications'),
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_active_outlined),
                      title: const Text('Enable Notifications'),
                      subtitle: const Text('Receive alerts for likes, follows, etc.'),
                      value: notificationsEnabled,
                      onChanged: (bool value) async {
                        await _userService.updateNotificationSettings(
                          userId,
                          value,
                        );
                        setState(() {});
                      },
                    ),

                    _buildSectionHeader(context, 'Privacy & Safety'),
                    ListTile(
                      leading: const Icon(Icons.block_flipped),
                      title: const Text('Blocked Users'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Manage blocked users in your profile.'),
                          ),
                        );
                      },
                    ),

                    _buildSectionHeader(context, 'Preferences'),
                    SwitchListTile(
                      secondary: const Icon(Icons.dark_mode_outlined),
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Use system theme settings'),
                      value: theme.brightness == Brightness.dark,
                      onChanged: null,
                    ),

                    _buildSectionHeader(context, 'About'),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Starpage Version'),
                      trailing:
                          Text('1.1.8+12', style: const TextStyle(color: Colors.grey)),
                    ),

                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton(
                        onPressed: () => _showLogoutDialog(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Logout'),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
              AuthService().logout().ignore();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
