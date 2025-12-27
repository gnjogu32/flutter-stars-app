import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../utils/animation_utils.dart';
import '../widgets/post_widget.dart';
import '../widgets/trending_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Starpage'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle),
            onPressed: () {
              // Navigate to create post screen
              Navigator.of(context).pushNamed('/create-post');
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No posts yet. Follow talented stars to see their work!',
              ),
            );
          }

          final posts = snapshot.data!.docs
              .map(
                (doc) => PostModel.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList();

          return ListView.builder(
            itemCount: posts.length + 1, // +1 for trending section
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              // Show trending section at the top
              if (index == 0) {
                return TrendingStreamSection(
                  currentUserId: _auth.currentUser?.uid ?? '',
                );
              }

              // Adjust index for posts list
              final postIndex = index - 1;
              return AnimationUtils.slideUpAnimation(
                duration: const Duration(milliseconds: 400),
                delayMilliseconds: postIndex * 50,
                child: PostWidget(
                  post: posts[postIndex],
                  currentUserId: _auth.currentUser?.uid ?? '',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
