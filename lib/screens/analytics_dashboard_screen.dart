import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/analytics_model.dart';
import '../services/analytics_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: const Center(
          child: Text('Please log in to view your analytics'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Analytics'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary stats
            _buildSummaryCards(),
            const SizedBox(height: 24),
            // Top posts
            _buildTopPostsSection(),
            const SizedBox(height: 24),
            // All posts analytics
            _buildAllPostsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _analyticsService.getAuthorSummary(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final summary = snapshot.data ?? {};
        final theme = Theme.of(context);

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildStatCard(
              title: 'Total Views',
              value: summary['totalViews'] ?? 0,
              icon: Icons.visibility,
              color: Colors.blue,
              theme: theme,
            ),
            _buildStatCard(
              title: 'Total Likes',
              value: summary['totalLikes'] ?? 0,
              icon: Icons.favorite,
              color: Colors.red,
              theme: theme,
            ),
            _buildStatCard(
              title: 'Total Comments',
              value: summary['totalComments'] ?? 0,
              icon: Icons.comment,
              color: Colors.orange,
              theme: theme,
            ),
            _buildStatCard(
              title: 'Total Reposts',
              value: summary['totalReposts'] ?? 0,
              icon: Icons.share,
              color: Colors.green,
              theme: theme,
            ),
            _buildStatCard(
              title: 'Engagement Rate',
              value: summary['avgEngagementRate'] != null
                  ? (summary['avgEngagementRate'] * 100).toStringAsFixed(1) + '%'
                  : '0%',
              icon: Icons.trending_up,
              color: Colors.purple,
              theme: theme,
              isPercentage: true,
            ),
            _buildStatCard(
              title: 'Posts Published',
              value: summary['totalPosts'] ?? 0,
              icon: Icons.article,
              color: Colors.teal,
              theme: theme,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required dynamic value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    bool isPercentage = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(
              value.toString(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPostsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Performing Content',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<AnalyticsModel>>(
          stream: _analyticsService.getTopPostsStream(
            _currentUserId,
            sortBy: 'engagementRate',
            limit: 5,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final posts = snapshot.data ?? [];

            if (posts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No analytics data yet',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }

            return Column(
              children: posts.asMap().entries.map((entry) {
                final index = entry.key;
                final post = entry.value;
                return _buildPostAnalyticsCard(
                  post,
                  rank: index + 1,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAllPostsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Content',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<AnalyticsModel>>(
          stream: _analyticsService.getAuthorAnalyticsStream(
            _currentUserId,
            limit: 50,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final posts = snapshot.data ?? [];

            if (posts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No posts published yet',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                return _buildPostAnalyticsCard(posts[index]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPostAnalyticsCard(
    AnalyticsModel post, {
    int? rank,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Row(
          children: [
            if (rank != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rank == 1
                      ? Colors.amber
                      : rank == 2
                          ? Colors.grey[400]
                          : rank == 3
                              ? Colors.orange[700]
                              : theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: rank <= 3 ? Colors.white : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Post ${post.postId.substring(0, 10)}...',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    timeago.format(post.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (post.viewCount > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${post.engagementPercentage.toStringAsFixed(1)}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: post.engagementPercentage > 5
                          ? Colors.green
                          : post.engagementPercentage > 2
                              ? Colors.orange
                              : Colors.grey,
                    ),
                  ),
                  Text(
                    'Engagement',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricRow(
                  icon: Icons.visibility,
                  label: 'Views',
                  value: post.viewCount,
                  color: Colors.blue,
                  theme: theme,
                ),
                _buildMetricRow(
                  icon: Icons.favorite,
                  label: 'Likes',
                  value: post.likeCount,
                  color: Colors.red,
                  theme: theme,
                ),
                _buildMetricRow(
                  icon: Icons.comment,
                  label: 'Comments',
                  value: post.commentCount,
                  color: Colors.orange,
                  theme: theme,
                ),
                _buildMetricRow(
                  icon: Icons.share,
                  label: 'Shares',
                  value: post.shareCount + post.repostCount,
                  color: Colors.green,
                  theme: theme,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: post.engagementRate.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation(
                    post.engagementRate > 0.1
                        ? Colors.green
                        : post.engagementRate > 0.05
                            ? Colors.orange
                            : Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Engagement Rate: ${post.engagementPercentage.toStringAsFixed(2)}%',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
          Text(
            value.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
