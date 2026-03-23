import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';

class EditPostScreen extends StatefulWidget {
  final PostModel post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _contentController;
  late TextEditingController _repostCaptionController;
  final PostService _postService = PostService();
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
  void initState() {
    super.initState();
    debugPrint('EditPostScreen initialized for post: ${widget.post.postId}');
    debugPrint('Initial content: ${widget.post.content}');
    _contentController = TextEditingController(text: widget.post.content);
    _repostCaptionController = TextEditingController(
      text: widget.post.repostCaption ?? '',
    );
    _selectedTalent = widget.post.talent;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _repostCaptionController.dispose();
    super.dispose();
  }

  Future<void> _updatePost() async {
    if (_contentController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Post content cannot be empty';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _postService.updatePost(
        postId: widget.post.postId,
        content: _contentController.text.trim(),
        talent: _selectedTalent,
        repostCaption: widget.post.repostCaption != null
            ? _repostCaptionController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating post: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // If this is a repost, show original author's content (read-only)
            if (widget.post.repostCaption != null) ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original Post by ${widget.post.originalAuthorName ?? 'Unknown'}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.post.content,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your Caption',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
            ],
            // Show images (read-only, can't change images when editing)
            if (widget.post.imageUrls.isNotEmpty) ...[
              Text(
                'Images (cannot be changed)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.post.imageUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.post.imageUrls[index],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Content text field
            if (widget.post.repostCaption == null) ...[
              Text('Content', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                maxLines: 6,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Edit your post content...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              Text(
                'Your Caption',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _repostCaptionController,
                maxLines: 3,
                maxLength: 280,
                decoration: InputDecoration(
                  hintText: 'Edit your repost caption...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  counterText: '', // Hide character counter
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Talent selection (not editable for reposts)
            if (widget.post.repostCaption == null) ...[
              Text(
                'Talent Category',
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
              const SizedBox(height: 16),
            ],

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

            // Update button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updatePost,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Update Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
