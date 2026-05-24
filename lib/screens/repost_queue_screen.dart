import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/repost_queue_model.dart';
import '../services/repost_queue_service.dart';
import '../widgets/expandable_text.dart';
import 'package:timeago/timeago.dart' as timeago;

class RepostQueueScreen extends StatefulWidget {
  const RepostQueueScreen({super.key});

  @override
  State<RepostQueueScreen> createState() => _RepostQueueScreenState();
}

class _RepostQueueScreenState extends State<RepostQueueScreen> {
  final RepostQueueService _queueService = RepostQueueService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Repost Queue')),
        body: const Center(
          child: Text('Please log in to view your repost queue'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Repost Queue'), elevation: 0),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Scheduled'),
                Tab(text: 'History'),
              ],
              indicatorSize: TabBarIndicatorSize.tab,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Pending tab
                  _buildPendingList(userId),
                  // Scheduled tab
                  _buildScheduledList(userId),
                  // History tab
                  _buildHistoryList(userId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList(String userId) {
    return StreamBuilder<List<RepostQueueModel>>(
      stream: _queueService.getPendingRepostsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];
        final pending = items.where((item) => !item.isScheduled).toList();

        if (pending.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No pending reposts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: pending.length,
          itemBuilder: (context, index) {
            return _buildQueueItemCard(
              pending[index],
              onCancel: () => _cancelRepost(pending[index].queueId),
            );
          },
        );
      },
    );
  }

  Widget _buildScheduledList(String userId) {
    return StreamBuilder<List<RepostQueueModel>>(
      stream: _queueService.getPendingRepostsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];
        final scheduled = items.where((item) => item.isScheduled).toList();

        if (scheduled.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No scheduled reposts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: scheduled.length,
          itemBuilder: (context, index) {
            return _buildQueueItemCard(
              scheduled[index],
              onCancel: () => _cancelRepost(scheduled[index].queueId),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryList(String userId) {
    return StreamBuilder<List<RepostQueueModel>>(
      stream: _queueService.getUserRepostHistoryStream(userId, limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];
        final completed = items
            .where((item) => item.status == 'sent' || item.status == 'failed')
            .toList();

        if (completed.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No repost history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: completed.length,
          itemBuilder: (context, index) {
            return _buildHistoryItemCard(completed[index]);
          },
        );
      },
    );
  }

  Widget _buildQueueItemCard(
    RepostQueueModel item, {
    required VoidCallback onCancel,
  }) {
    final theme = Theme.of(context);
    final isFuture = item.isFuture;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post ${item.postId.substring(0, 8)}...',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isFuture)
                        Text(
                          'Scheduled for ${timeago.format(item.scheduleTime)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else
                        Text(
                          'Queued ${timeago.format(item.createdAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(item.statusText),
                  backgroundColor: item.status == 'pending'
                      ? theme.colorScheme.secondaryContainer
                      : (theme.brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey.shade200),
                ),
              ],
            ),
            if (item.repostCaption != null &&
                item.repostCaption!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ExpandableText(
                  item.repostCaption!,
                  style: theme.textTheme.bodySmall,
                  trimLines: 2,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Cancel'),
                onPressed: onCancel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItemCard(RepostQueueModel item) {
    final theme = Theme.of(context);
    final isSuccess = item.status == 'sent';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Post ${item.postId.substring(0, 8)}...',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(item.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (!isSuccess && item.errorMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Error: ${item.errorMessage}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: isSuccess ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelRepost(String queueId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Repost'),
        content: const Text('Are you sure you want to cancel this repost?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _queueService.cancelRepost(queueId);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Repost cancelled')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
