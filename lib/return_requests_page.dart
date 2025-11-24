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

  // 🔁 Approve or reject return requests + trust logic
  Future<void> _updateReturn(
    String requestId,
    String newStatus,
    String itemId,
    String borrowerId,
    String ownerId,
  ) async {
    try {
      // Step 1️⃣ Update the return request document
      await _firestore.collection('returnRequests').doc(requestId).update({
        'status': newStatus,
        'updatedAt': DateTime.now(),
      });

      // Step 2️⃣ If approved → mark item available again
      if (newStatus == 'approved') {
        await _firestore.collection('items').doc(itemId).update({
          'status': 'Available',
        });

        // Step 3️⃣ Trust score logic (+5 for both)
        final borrowerRef = _firestore.collection('users').doc(borrowerId);
        final ownerRef = _firestore.collection('users').doc(ownerId);

        await _firestore.runTransaction((txn) async {
          // Borrower +5
          final borrowerDoc = await txn.get(borrowerRef);
          if (borrowerDoc.exists) {
            final currentTrust = borrowerDoc['trustScore'] ?? 0;
            txn.update(borrowerRef, {'trustScore': currentTrust + 5});
          }

          // Owner +5
          final ownerDoc = await txn.get(ownerRef);
          if (ownerDoc.exists) {
            final currentTrust = ownerDoc['trustScore'] ?? 0;
            txn.update(ownerRef, {'trustScore': currentTrust + 5});
          }
        });
      }

      // Step 4️⃣ Snack message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Return $newStatus!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error updating return: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? ownerId = _auth.currentUser?.uid;

    if (ownerId == null) {
      return const Scaffold(
        body: Center(child: Text('You must be logged in to view return requests.')),
      );
    }

    // 🔹 Listen for all return requests where this user is the owner
    final returnStream = _firestore
        .collection('returnRequests')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('requestedAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Return Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: returnStream,
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Empty state
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No return requests yet.'));
          }

          final requests = snapshot.data!.docs;

          // List builder
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final data = requests[index].data() as Map<String, dynamic>;
              final requestId = requests[index].id;
              final itemId = data['itemId'] ?? '';
              final borrowerId = data['borrowerId'] ?? '';
              final ownerId = data['ownerId'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                child: ListTile(
                  leading: const Icon(Icons.undo, color: Colors.orange),
                  title: Text(
                    'Item ID: ${data['itemId'] ?? 'Unknown'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Borrower ID: ${data['borrowerId'] ?? 'N/A'}\nStatus: ${data['status'] ?? 'pending'}',
                  ),
                  trailing: data['status'] == 'pending'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.green),
                              tooltip: 'Approve Return',
                              onPressed: () => _updateReturn(
                                requestId,
                                'approved',
                                itemId,
                                borrowerId,
                                ownerId,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel,
                                  color: Colors.redAccent),
                              tooltip: 'Reject Return',
                              onPressed: () => _updateReturn(
                                requestId,
                                'rejected',
                                itemId,
                                borrowerId,
                                ownerId,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          data['status'].toString().toUpperCase(),
                          style: TextStyle(
                            color: data['status'] == 'approved'
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
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
