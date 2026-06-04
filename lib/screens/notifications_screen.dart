import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/post_service.dart';
import '../utils/animation_utils.dart';
import '../screens/profile_screen.dart';
import '../screens/chat_screen.dart';
import '../widgets/post_details_sheet.dart';

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
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          centerTitle: true,
          elevation: 0,
        ),
        body: _LoginPromptBody(
          icon: Icons.notifications_outlined,
          message: 'Log in to see your notifications.',
        ),
      );
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
    return _NotificationItem(
      key: ValueKey(notification.notificationId),
      notification: notification,
      currentUserId: currentUserId,
    );
  }
}

class _NotificationItem extends StatefulWidget {
  final NotificationModel notification;
  final String currentUserId;

  const _NotificationItem({
    super.key,
    required this.notification,
    required this.currentUserId,
  });

  @override
  State<_NotificationItem> createState() => _NotificationItemState();
}

class _NotificationItemState extends State<_NotificationItem>
    with AutomaticKeepAliveClientMixin {
  final NotificationService _notificationService = NotificationService();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final notification = widget.notification;
    final currentUserId = widget.currentUserId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color backgroundColor = notification.isRead
        ? Colors.transparent
        : theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.08);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: backgroundColor,
      child: ListTile(
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    ProfileScreen(userId: notification.triggeredBy),
              ),
            );
          },
          child: AnimatedScale(
            duration: const Duration(milliseconds: 300),
            scale: notification.isRead ? 1.0 : 1.05,
            child: CircleAvatar(
              backgroundImage: notification.triggeredByImageUrl != null
                  ? CachedNetworkImageProvider(notification.triggeredByImageUrl!)
                  : null,
              child: notification.triggeredByImageUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
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
          // Mark as read
          if (!notification.isRead) {
            await _notificationService.markAsRead(
              currentUserId,
              notification.notificationId,
            );
          }

          if (!context.mounted) return;

          // Navigate based on notification type
          if (notification.type == 'follow') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    ProfileScreen(userId: notification.triggeredBy),
              ),
            );
          } else if (notification.type == 'message') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  conversationId: _getConversationId(
                    currentUserId,
                    notification.triggeredBy,
                  ),
                  otherUserId: notification.triggeredBy,
                  otherUserName: notification.triggeredByName,
                ),
              ),
            );
          } else if (notification.type == 'like_post' ||
              notification.type == 'comment' ||
              notification.type == 'mention_followers' ||
              notification.type == 'mention_user' ||
              notification.type == 'like_comment') {
            if (notification.postId != null) {
              _openPostDetails(context, notification.postId!, currentUserId);
            }
          }
        },
        onLongPress: () {
          _showNotificationMenu(context, notification, currentUserId);
        },
      ),
    );
  }

  String _getConversationId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _openPostDetails(
    BuildContext context,
    String postId,
    String currentUserId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final post = await PostService().getPost(postId);

      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss loading indicator

      if (post != null) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => DraggableScrollableSheet(
            expand: false,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            builder: (context, scrollController) => PostDetailsSheet(
              post: post,
              currentUserId: currentUserId,
              scrollController: scrollController,
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('This post is no longer available.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading if error
        messenger.showSnackBar(
          SnackBar(content: Text('Error loading post: $e')),
        );
      }
    }
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
                Navigator.pop(context);
                await _notificationService.deleteNotification(
                  currentUserId,
                  notification.notificationId,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification deleted')),
                );
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

/// Reusable login prompt shown in place of screens that need authentication.
class _LoginPromptBody extends StatelessWidget {
  final IconData icon;
  final String message;
  const _LoginPromptBody({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: cs.primaryContainer,
              child: Icon(icon, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center, style: tt.bodyLarge),
            const SizedBox(height: 28),
            SizedBox(
              width: 200,
              child: FilledButton(
                onPressed: () => Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamed('/login'),
                child: const Text('Log In'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: OutlinedButton(
                onPressed: () => Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamed('/signup'),
                child: const Text('Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
