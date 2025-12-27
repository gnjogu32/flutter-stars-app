import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _selectedTalentFilter = 'All';

  final List<String> talents = [
    'All',
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
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Talents'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search talented stars...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          // Talent Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: talents.map((talent) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(talent),
                    selected: _selectedTalentFilter == talent,
                    onSelected: (selected) {
                      setState(() {
                        _selectedTalentFilter = talent;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Users List
          Expanded(child: _buildUsersList()),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    Query query = _firestore.collection('users');

    // Apply talent filter
    if (_selectedTalentFilter != 'All') {
      query = query.where('talent', isEqualTo: _selectedTalentFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No talented stars found in this category.'),
          );
        }

        var users = snapshot.data!.docs
            .map(
              (doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>),
            )
            .toList();

        // Apply search filter
        if (_searchController.text.isNotEmpty) {
          users = users
              .where(
                (user) => user.displayName.toLowerCase().contains(
                  _searchController.text.toLowerCase(),
                ),
              )
              .toList();
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildUserCard(user);
          },
        );
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user.profileImageUrl != null
              ? NetworkImage(user.profileImageUrl!)
              : null,
          child: user.profileImageUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Text(user.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.talent != null) Text('${user.talent}'),
            if (user.bio != null) Text(user.bio!),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {
            // Navigate to user profile
            Navigator.of(
              context,
            ).pushNamed('/user-profile', arguments: user.uid);
          },
          child: const Text('View'),
        ),
      ),
    );
  }
}
