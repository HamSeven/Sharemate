import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/design_tokens.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text("User not found"));
          }

          final user = snap.data!.data() as Map<String, dynamic>;
          final name = user['name'] ?? 'Unnamed User';
          final email = FirebaseAuth.instance.currentUser!.email ?? '-';

          // ✅ trustScore 统一为 double
          final double trust =
              (user['trustScore'] ?? 100).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _profileHeader(name, trust),
                const SizedBox(height: 16),
                _infoCard(email, uid),
                const SizedBox(height: 16),
                _actionCard(context),
              ],
            ),
          );
        },
      ),
    );
  }

  // ======================
  // Header
  // ======================
  Widget _profileHeader(String name, double trust) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(name, style: AppText.titleLarge),
          const SizedBox(height: 6),
          _trustRow(trust),
          const SizedBox(height: 6),
          Text(
            "Trust score is system-generated",
            style: AppText.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _trustRow(double trust) {
    final color = trust >= 90
        ? Colors.green
        : trust >= 70
            ? Colors.orange
            : Colors.red;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          "Trust Score: ${trust.toStringAsFixed(1)}",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // ======================
  // Info Card
  // ======================
  Widget _infoCard(String email, String uid) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Account Information", style: AppText.titleMedium),
          const SizedBox(height: 12),
          _infoRow(Icons.email, "Email", email),
          const SizedBox(height: 8),
          _infoRow(Icons.person, "User ID", uid),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text("$label:", style: AppText.bodyMedium),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: AppText.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ======================
  // Actions
  // ======================
  Widget _actionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Actions", style: AppText.titleMedium),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
