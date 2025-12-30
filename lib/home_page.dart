import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'widgets/item_card.dart';
import 'theme/design_tokens.dart';

import 'add_item_page.dart';
import 'item_detail_page.dart';
import 'borrow_requests_page.dart';
import 'return_requests_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _homeList(),
      const BorrowRequestsPage(),
      const ReturnRequestsPage(),
      const ProfilePage(),
    ];
  }

  Future<void> _logout() async {
    await _auth.signOut();
  }

  void _onNavTap(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  // ==========================
  // Home list (items)
  // ==========================
  Widget _homeList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('items')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No items available.\nTap + to add your first item!',
              textAlign: TextAlign.center,
              style: AppText.bodyMedium,
            ),
          );
        }

        final items = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 80),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final data = items[index].data() as Map<String, dynamic>;

            return ItemCard(
              title: data['title'] ?? 'Unnamed Item',
              description: data['description'] ?? '',
              imageUrl: data['imageUrl'],
              ownerName: data['ownerName'] ?? 'Unknown',
              status: (data['status'] ?? 'available').toString(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ItemDetailPage(itemId: items[index].id),
                  ),
                );
              },
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ItemDetailPage(itemId: items[index].id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ==========================
  // UI
  // ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text("ShareMate"),
        backgroundColor: AppColors.card,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: AppColors.textPrimary,
            ),
            onPressed: _logout,
          ),
        ],
      ),

      body: _pages[_selectedIndex],

      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddItemPage(),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code),
            label: 'Borrow',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.undo),
            label: 'Returns',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
