import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReturnRequestsPage extends StatefulWidget {
  const ReturnRequestsPage({super.key});

  @override
  State<ReturnRequestsPage> createState() => _ReturnRequestsPageState();
}

class _ReturnRequestsPageState extends State<ReturnRequestsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =====================================================
  // Approve / Reject Return
  // =====================================================
  Future<void> _updateReturn({
    required String returnRequestId,
    required String newStatus,
    required String itemId,
    required String borrowerId,
    required String ownerId,
    String? borrowRequestId,
  }) async {
    try {
      // 1️⃣ update return request
      await _firestore
          .collection('returnRequests')
          .doc(returnRequestId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2️⃣ approved → item 回到 available
      if (newStatus == 'approved') {
        await _firestore.collection('items').doc(itemId).update({
          'status': 'available',
          'borrowerId': FieldValue.delete(),
        });

        // borrow request → returned
        if (borrowRequestId != null) {
          await _firestore
              .collection('borrowRequests')
              .doc(borrowRequestId)
              .update({
            'status': 'returned',
            'returnedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Return $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerId = _auth.currentUser?.uid;

    if (ownerId == null) {
      return const Scaffold(
        body: Center(child: Text('Please login')),
      );
    }

    final stream = _firestore
        .collection('returnRequests')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Return Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No return requests'));
          }

          // 本地排序（新到旧）
          final requests = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aTime = a['requestedAt'] as Timestamp?;
              final bTime = b['requestedAt'] as Timestamp?;
              return (bTime?.millisecondsSinceEpoch ?? 0)
                  .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
            });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final doc = requests[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = (data['status'] ?? 'pending').toString();

              // 🔑 新字段（有 fallback，旧数据不炸）
              final borrowerName =
                  data['borrowerName'] ?? data['borrowerId'];
              final borrowerTrust = data['borrowerTrustScore'];

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.undo, color: Colors.orange),

                  // ======= TITLE =======
                  title: Row(
                    children: [
                      const Icon(Icons.person, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          borrowerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (borrowerTrust != null)
                        Text(
                          '⭐ ${borrowerTrust.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                    ],
                  ),

                  // ======= SUBTITLE =======
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Status: ${status.toUpperCase()}',
                      style: TextStyle(
                        color: status == 'pending'
                            ? Colors.orange
                            : status == 'approved'
                                ? Colors.green
                                : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // ======= ACTIONS =======
                  trailing: status == 'pending'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              tooltip: 'Approve Return',
                              onPressed: () => _updateReturn(
                                returnRequestId: doc.id,
                                newStatus: 'approved',
                                itemId: data['itemId'],
                                borrowerId: data['borrowerId'],
                                ownerId: data['ownerId'],
                                borrowRequestId:
                                    data['borrowRequestId'],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.red,
                              ),
                              tooltip: 'Reject Return',
                              onPressed: () => _updateReturn(
                                returnRequestId: doc.id,
                                newStatus: 'rejected',
                                itemId: data['itemId'],
                                borrowerId: data['borrowerId'],
                                ownerId: data['ownerId'],
                                borrowRequestId:
                                    data['borrowRequestId'],
                              ),
                            ),
                          ],
                        )
                      : Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: status == 'approved'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
