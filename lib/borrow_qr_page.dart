import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'theme/design_tokens.dart';

class BorrowQrPage extends StatelessWidget {
  final String requestId;
  const BorrowQrPage({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Borrow Verification"),
        backgroundColor: AppColors.card,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('borrowRequests')
            .doc(requestId)
            .get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          final data = snap.data!.data() as Map<String, dynamic>;
          final appointment = data['appointment'];

          if (data['status'] != 'approved' || appointment == null) {
            return const Center(
              child: Text(
                "QR is not available",
                style: AppText.bodyMedium,
              ),
            );
          }

          final payload = jsonEncode({
            'requestId': requestId,
            'itemId': data['itemId'],
            'requesterId': data['requesterId'],
            'ownerId': data['ownerId'],
            'appointmentTime':
                (appointment['dateTime'] as Timestamp)
                    .toDate()
                    .millisecondsSinceEpoch,
            'location': appointment['location'],
          });

          final dateTime =
              (appointment['dateTime'] as Timestamp).toDate().toLocal();

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // =========================
                // Top instruction
                // =========================
                Text(
                  "Borrow Confirmation",
                  style: AppText.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  "Please present this QR code to the owner\nat the agreed time and location",
                  textAlign: TextAlign.center,
                  style: AppText.bodySmall,
                ),

                const SizedBox(height: 24),

                // =========================
                // QR Card
                // =========================
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: AppRadius.card,
                    boxShadow: AppShadows.soft,
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: payload,
                        size: 220,
                        backgroundColor: AppColors.card,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Valid for this borrowing only",
                        style: AppText.bodySmall,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // =========================
                // Appointment info
                // =========================
                Container(
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
                      Text(
                        "Appointment Details",
                        style: AppText.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      _infoRow(
                        Icons.schedule,
                        _formatDateTime(dateTime),
                      ),
                      const SizedBox(height: 6),
                      _infoRow(
                        Icons.location_on,
                        appointment['location'],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // =========================
                // Bottom action
                // =========================
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: AppButtons.primary,
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Done"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AppText.bodyMedium),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
           "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
