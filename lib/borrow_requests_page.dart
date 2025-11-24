import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'scan_qr_page.dart'; // 👈 新增导入扫描页

class BorrowRequestsPage extends StatefulWidget {
  const BorrowRequestsPage({super.key});

  @override
  State<BorrowRequestsPage> createState() => _BorrowRequestsPageState();
}

class _BorrowRequestsPageState extends State<BorrowRequestsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔹 Update request (Approve or Reject)
  Future<void> _updateRequest(
    String requestId,
    String newStatus,
    String itemId,
    String borrowerId,
  ) async {
    try {
      await _firestore.collection('borrowRequests').doc(requestId).update({
        'status': newStatus,
        'updatedAt': DateTime.now(),
      });

      if (newStatus == 'approved') {
        await _firestore.collection('items').doc(itemId).update({
          'status': 'Borrowed',
          'borrowerId': borrowerId,
        });

        final borrowerRef = _firestore.collection('users').doc(borrowerId);
        await _firestore.runTransaction((txn) async {
          final borrowerDoc = await txn.get(borrowerRef);
          if (borrowerDoc.exists) {
            final currentTrust = borrowerDoc['trustScore'] ?? 0;
            txn.update(borrowerRef, {'trustScore': currentTrust + 2});
          }
        });
      } else if (newStatus == 'rejected') {
        await _firestore.collection('items').doc(itemId).update({
          'status': 'Available',
          'borrowerId': null,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request $newStatus successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error updating request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view requests.')),
      );
    }

    final requestsStream = _firestore
        .collection('borrowRequests')
        .where(Filter.or(
          Filter('ownerId', isEqualTo: currentUserId),
          Filter('borrowerId', isEqualTo: currentUserId),
        ))
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrow Requests'),
        actions: [
          // 📷 扫描 QR Code 按钮
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan QR to Approve',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanQRPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: requestsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No borrow requests yet.'));
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final data = requests[index].data() as Map<String, dynamic>;
              final requestId = requests[index].id;
              final itemId = data['itemId'] ?? 'unknown';
              final borrowerId = data['borrowerId'] ?? 'unknown';
              final ownerId = data['ownerId'] ?? '';
              final isOwner = ownerId == currentUserId;

              Color statusColor;
              switch (data['status']) {
                case 'approved':
                  statusColor = Colors.green;
                  break;
                case 'rejected':
                  statusColor = Colors.redAccent;
                  break;
                default:
                  statusColor = Colors.orange;
              }

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                child: ListTile(
                  leading: const Icon(Icons.request_page, color: Colors.blue),
                  title: Text(
                    'Item ID: ${data['itemId'] ?? 'Unknown'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Borrower ID: ${data['borrowerId'] ?? 'N/A'}\nStatus: ${data['status'] ?? 'pending'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🟢 状态 Chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          data['status']?.toString().toUpperCase() ?? '',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // 🧩 操作按钮（仅 Owner 且 Pending）
                      if (isOwner && data['status'] == 'pending') ...[
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: Colors.green),
                          tooltip: 'Approve',
                          onPressed: () => _updateRequest(
                            requestId,
                            'approved',
                            itemId,
                            borrowerId,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel,
                              color: Colors.redAccent),
                          tooltip: 'Reject',
                          onPressed: () => _updateRequest(
                            requestId,
                            'rejected',
                            itemId,
                            borrowerId,
                          ),
                        ),
                      ],
                    ],
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
