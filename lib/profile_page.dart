import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final snapshot = await _firestore.collection('users').doc(uid).get();
      if (snapshot.exists) {
        setState(() {
          userData = snapshot.data();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (userData == null) {
      return const Scaffold(
        body: Center(child: Text('No user data found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('👤 Name: ${userData!['name'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text('📧 Email: ${userData!['email'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text('💯 Trust Score: ${userData!['trustScore'] ?? 0}',
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text('📦 Transactions: ${userData!['transactions'] ?? 0}',
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text('🚫 Reports: ${userData!['reports'] ?? 0}',
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
