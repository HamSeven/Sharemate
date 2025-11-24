import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportPage extends StatefulWidget {
  final String borrowerId;
  final String itemId;

  const ReportPage({
    super.key,
    required this.borrowerId,
    required this.itemId,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _reasonController = TextEditingController();
  bool isSubmitting = false;

  // 🧾 Submit a report + deduct trust score
  Future<void> submitReport() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please enter a reason')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final reporterId = _auth.currentUser?.uid;
      if (reporterId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ You must be logged in to report')),
        );
        return;
      }

      // 🔹 Create a new report document
      await _firestore.collection('reports').add({
        'borrowerId': widget.borrowerId,
        'itemId': widget.itemId,
        'reporterId': reporterId,
        'reason': _reasonController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔹 Decrease borrower’s trust score (-10)
      final borrowerRef = _firestore.collection('users').doc(widget.borrowerId);
      await _firestore.runTransaction((txn) async {
        final doc = await txn.get(borrowerRef);
        if (doc.exists) {
          final currentTrust = doc['trustScore'] ?? 100;
          txn.update(borrowerRef, {
            'trustScore': (currentTrust - 10).clamp(0, 100),
            'reports': (doc['reports'] ?? 0) + 1,
          });
        }
      });

      // 🔹 Success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Report submitted successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error submitting report: $e')),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Borrower'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reason for Report:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe the issue (e.g., item not returned, damaged, etc.)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 25),

            Center(
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : submitReport,
                icon: const Icon(Icons.report),
                label: Text(isSubmitting ? 'Submitting...' : 'Submit Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
