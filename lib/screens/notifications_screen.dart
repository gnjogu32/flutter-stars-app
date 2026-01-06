import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../utils/animation_utils.dart';
import '../screens/profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Not authenticated'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () async {
              await _notificationService.markAllAsRead(userId);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.getNotificationsStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When people follow you, like your posts,\nor comment, you\'ll see it here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return AnimationUtils.slideUpAnimation(
                duration: const Duration(milliseconds: 400),
                delayMilliseconds: index * 50,
                child: _buildNotificationItem(
                  context,
                  notifications[index],
                  userId,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    NotificationModel notification,
    String currentUserId,
  ) {
    Color backgroundColor = notification.isRead
        ? Colors.transparent
        : Colors.blue.withValues(alpha: 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: backgroundColor,
      child: ListTile(
        leading: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: notification.isRead ? 1.0 : 1.05,
          child: CircleAvatar(
            backgroundImage: notification.triggeredByImageUrl != null
                ? NetworkImage(notification.triggeredByImageUrl!)
                : null,
            child: notification.triggeredByImageUrl == null
                ? const Icon(Icons.person)
                : null,
          ),
        ),
        title: Text(
          notification.content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: notification.isRead
                ? FontWeight.normal
                : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _formatTime(notification.createdAt),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        trailing: notification.isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () async {
          final context_ = context;
          // Mark as read
          if (!notification.isRead) {
            await _notificationService.markAsRead(
              currentUserId,
              notification.notificationId,
            );
          }

          // Navigate based on notification type
          if (mounted) {
            if (notification.type == 'follow') {
              // ignore: use_build_context_synchronously
              Navigator.of(context_).push(
                MaterialPageRoute(
                  builder: (context) =>
                      ProfileScreen(userId: notification.triggeredBy),
                ),
              );
            } else if (notification.type == 'like_post' ||
                notification.type == 'comment') {
              // Navigate to post (would need to add post screen navigation)
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context_).showSnackBar(
                SnackBar(content: Text('Post: ${notification.postId}')),
              );
            }
          }
        },
        onLongPress: () {
          _showNotificationMenu(context, notification, currentUserId);
        },
      ),
    );
  }

  void _showNotificationMenu(
    BuildContext context,
    NotificationModel notification,
    String currentUserId,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () async {
                final context_ = context;
                Navigator.pop(context_);
                await _notificationService.deleteNotification(
                  currentUserId,
                  notification.notificationId,
                );
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context_).showSnackBar(
                    const SnackBar(content: Text('Notification deleted')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}
