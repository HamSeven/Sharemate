import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/design_tokens.dart';
import 'borrow_qr_page.dart';
import 'scan_qr_page.dart';

class BorrowRequestDetailPage extends StatelessWidget {
  final String requestId;

  const BorrowRequestDetailPage({
    super.key,
    required this.requestId,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Borrow Request Details"),
        backgroundColor: AppColors.card,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('borrowRequests')
            .doc(requestId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (!snap.data!.exists) {
            return const Center(child: Text("Request not found"));
          }

          final data = snap.data!.data() as Map<String, dynamic>;
          final status = data['status'];
          final requesterId = data['requesterId'];
          final ownerId = data['ownerId'];
          final itemId = data['itemId'];
          final appointment = data['appointment'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _itemSection(itemId),
                const SizedBox(height: 16),

                if (appointment != null &&
                    (status == 'approved' ||
                        status == 'borrowed' ||
                        status == 'return_pending'))
                  _appointmentCard(appointment),

                const SizedBox(height: 16),

                _actionSection(
                  context: context,
                  status: status,
                  currentUid: currentUid,
                  requesterId: requesterId,
                  ownerId: ownerId,
                  itemId: itemId,
                  data: data,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ===============================
  // Item info
  // ===============================
  Widget _itemSection(String itemId) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('items').doc(itemId).get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (!snap.data!.exists) {
          return const Text("Item not found");
        }

        final item = snap.data!.data() as Map<String, dynamic>;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadius.card,
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item['imageUrl'] != null && item['imageUrl'] != '')
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    item['imageUrl'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 200,
                  color: AppColors.background,
                  child: const Icon(
                    Icons.inventory_2,
                    size: 60,
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 12),
              Text(item['title'] ?? 'Unnamed Item',
                  style: AppText.titleLarge),
              const SizedBox(height: 6),
              Text(item['description'] ?? '',
                  style: AppText.bodyMedium),
            ],
          ),
        );
      },
    );
  }

  // ===============================
  // Appointment
  // ===============================
  Widget _appointmentCard(Map<String, dynamic> appointment) {
    final dt =
        (appointment['dateTime'] as Timestamp).toDate().toLocal();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Appointment", style: AppText.titleMedium),
          const SizedBox(height: 6),
          Text("📅 $dt", style: AppText.bodyMedium),
          Text("📍 ${appointment['location']}",
              style: AppText.bodyMedium),
        ],
      ),
    );
  }

  // ===============================
  // Actions
  // ===============================
  Widget _actionSection({
    required BuildContext context,
    required String status,
    required String currentUid,
    required String requesterId,
    required String ownerId,
    required String itemId,
    required Map<String, dynamic> data,
  }) {
    if (status == 'approved') {
      if (currentUid == requesterId) {
        return ElevatedButton.icon(
          style: AppButtons.primary,
          icon: const Icon(Icons.qr_code),
          label: const Text("Show QR Code"),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BorrowQrPage(requestId: requestId),
              ),
            );
          },
        );
      }

      if (currentUid == ownerId) {
        return ElevatedButton.icon(
          style: AppButtons.primary,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text("Scan Borrower QR"),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanQrPage()),
            );
          },
        );
      }
    }

    if (status == 'borrowed' && currentUid == requesterId) {
      return ElevatedButton.icon(
        style: AppButtons.primary,
        icon: const Icon(Icons.undo),
        label: const Text("Request Return"),
        onPressed: () async {
          final firestore = FirebaseFirestore.instance;

          final itemSnap =
              await firestore.collection('items').doc(itemId).get();

          if (!itemSnap.exists) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Item not found")),
            );
            return;
          }

          final itemOwnerId = itemSnap['ownerId'];

          await firestore.collection('returnRequests').add({
            'borrowRequestId': requestId,
            'itemId': itemId,

            'borrowerId': requesterId,
            'borrowerName': data['requesterName'],
            'borrowerTrustScore': data['requesterTrustScore'],

            'ownerId': itemOwnerId,
            'ownerName': data['ownerName'],
            'ownerTrustScore': data['ownerTrustScore'],

            'status': 'pending',
            'requestedAt': FieldValue.serverTimestamp(),
          });

          await firestore
              .collection('borrowRequests')
              .doc(requestId)
              .update({'status': 'return_pending'});

          await firestore.collection('items').doc(itemId).update({
            'status': 'return_pending',
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Return request sent")),
          );
        },
      );
    }

    if (status == 'return_pending') {
      return const Text(
        "⏳ Waiting for owner to approve return",
        style: AppText.bodyMedium,
      );
    }

    if (status == 'rejected') {
      return Text(
        "❌ Request rejected",
        style: AppText.bodyMedium.copyWith(color: AppColors.danger),
      );
    }

    return const SizedBox.shrink();
  }
}
