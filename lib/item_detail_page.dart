import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/design_tokens.dart';

class ItemDetailPage extends StatelessWidget {
  final String itemId;

  const ItemDetailPage({
    super.key,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login again")),
      );
    }

    final currentUid = user.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Item Details"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('items')
            .doc(itemId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Item not found"));
          }

          final item = snapshot.data!.data() as Map<String, dynamic>;
          final ownerId = item['ownerId'];
          final isOwner = currentUid == ownerId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =========================
                // Image
                // =========================
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: item['imageUrl'] != null &&
                          item['imageUrl'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            item['imageUrl'],
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.inventory_2, size: 60),
                        ),
                ),

                const SizedBox(height: 16),

                // =========================
                // Title & status
                // =========================
                Text(
                  item['title'] ?? 'Unnamed Item',
                  style: AppText.titleLarge,
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    _statusPill(item['status']),
                    const SizedBox(width: 8),
                    if (isOwner)
                      const Text(
                        "(Your item)",
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  item['description'] ?? '',
                  style: AppText.bodyMedium,
                ),

                const SizedBox(height: 24),

                // =========================
                // ACTION SECTION
                // =========================
                _actionSection(
                  context: context,
                  isOwner: isOwner,
                  item: item,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ======================================================
  // Action section
  // ======================================================
  Widget _actionSection({
    required BuildContext context,
    required bool isOwner,
    required Map<String, dynamic> item,
  }) {
    final rawStatus =
        (item['status'] ?? '').toString().trim().toLowerCase();

    final isAvailable = rawStatus == 'available';

    // ======================
    // OWNER VIEW
    // ======================
    if (isOwner) {
      return _infoCard(
        icon: Icons.lock_outline,
        title: "You own this item",
        message: "You cannot borrow your own item.",
      );
    }

    // ======================
    // AVAILABLE → ACTION
    // ======================
    if (isAvailable) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: AppButtons.primary,
          onPressed: () async {
            final firestore = FirebaseFirestore.instance;
            final uid = FirebaseAuth.instance.currentUser!.uid;

            final requesterSnap =
                await firestore.collection('users').doc(uid).get();
            final ownerSnap = await firestore
                .collection('users')
                .doc(item['ownerId'])
                .get();

            await firestore.collection('borrowRequests').add({
              'itemId': itemId,
              'itemName': item['title'],

              'requesterId': uid,
              'requesterName': requesterSnap['name'],
              'requesterTrustScore':
                  requesterSnap['trustScore'] ?? 100,

              'ownerId': item['ownerId'],
              'ownerName': ownerSnap['name'],
              'ownerTrustScore':
                  ownerSnap['trustScore'] ?? 100,

              'status': 'pending',
              'requestedAt': FieldValue.serverTimestamp(),
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Borrow request sent")),
            );
          },
          child: const Text("Request to Borrow"),
        ),
      );
    }

    // ======================
    // NOT AVAILABLE → INFO CARD
    // ======================
    return _infoCard(
      icon: _statusIcon(rawStatus),
      title: _statusTitle(rawStatus),
      message: _statusMessage(rawStatus),
    );
  }

  // ======================================================
  // Info Card (Reusable)
  // ======================================================
  Widget _infoCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.titleMedium),
                const SizedBox(height: 4),
                Text(message, style: AppText.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // Helpers
  // ======================================================
  Widget _statusPill(dynamic status) {
    final s = (status ?? '').toString().trim().toLowerCase();

    Color color;
    switch (s) {
      case 'borrowed':
        color = Colors.orange;
        break;
      case 'approved':
        color = Colors.blue;
        break;
      case 'return_pending':
        color = Colors.deepOrange;
        break;
      case 'available':
      default:
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        s.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'borrowed':
        return Icons.hourglass_bottom;
      case 'approved':
        return Icons.verified;
      case 'return_pending':
        return Icons.undo;
      default:
        return Icons.info_outline;
    }
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'borrowed':
        return "Item is borrowed";
      case 'approved':
        return "Borrow approved";
      case 'return_pending':
        return "Return in progress";
      default:
        return "Item unavailable";
    }
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'borrowed':
        return "This item is currently borrowed by another user.";
      case 'approved':
        return "This item has been approved and is awaiting pickup.";
      case 'return_pending':
        return "The borrower is returning this item.";
      default:
        return "This item cannot be borrowed at the moment.";
    }
  }
}
