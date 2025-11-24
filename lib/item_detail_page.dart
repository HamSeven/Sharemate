import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'report_page.dart';
import 'borrow_qr_page.dart';

class ItemDetailPage extends StatefulWidget {
  final String itemId;
  const ItemDetailPage({super.key, required this.itemId});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? itemData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchItemDetails();
  }

  // 🔹 Load item data from Firestore
  Future<void> fetchItemDetails() async {
    try {
      final snapshot =
          await _firestore.collection('items').doc(widget.itemId).get();
      if (snapshot.exists) {
        setState(() {
          itemData = snapshot.data();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Item not found')),
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading item details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading item details: $e')),
      );
    }
  }

  // 🟢 Borrow item (creates borrow request)
 Future<void> borrowItem() async {
  try {
    final uid = _auth.currentUser?.uid;
    if (uid == null || itemData == null) return;

    // Step 1️⃣: Create borrow request
    final requestRef = await _firestore.collection('borrowRequests').add({
      'itemId': widget.itemId,
      'borrowerId': uid,
      'ownerId': itemData!['ownerId'],
      'status': 'pending',
      'requestedAt': DateTime.now(),
    });

    // Step 2️⃣: Go to QR page and show auto-generated QR
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BorrowQRPage(requestId: requestRef.id),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Error sending request: $e')),
    );
  }
}

  // 🔁 Return item (creates return request)
  Future<void> returnItem() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null || itemData == null) return;

      final ownerId = itemData!['ownerId'] ?? '';
      if (ownerId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Item owner not found')),
        );
        return;
      }

      await _firestore.collection('returnRequests').add({
        'itemId': widget.itemId,
        'borrowerId': uid,
        'ownerId': ownerId,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔁 Return request sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error sending return request: $e')),
      );
    }
  }

  // 🚨 Report borrower (navigate to ReportPage)
  void reportBorrower(String borrowerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPage(
          borrowerId: borrowerId,
          itemId: widget.itemId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (itemData == null) {
      return const Scaffold(
        body: Center(child: Text('Item data not found.')),
      );
    }

    final isBorrowed = itemData!['status'] == 'Borrowed';
    final currentUserId = _auth.currentUser?.uid;
    final isOwner = currentUserId == itemData!['ownerId'];
    final borrowerId = itemData!['borrowerId'];

    return Scaffold(
      appBar: AppBar(
        title: Text(itemData!['title'] ?? 'Item Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🖼️ Item image
              if (itemData!['imageUrl'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    itemData!['imageUrl'],
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.inventory, size: 80, color: Colors.white70),
                ),

              const SizedBox(height: 20),

              // 🏷️ Item title
              Text(
                itemData!['title'] ?? 'Unnamed Item',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              // 📝 Item description
              Text(
                itemData!['description'] ?? 'No description provided.',
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 20),

              // 👤 Owner info
              Text(
                'Owner: ${itemData!['ownerName'] ?? 'Unknown'}',
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),

              const SizedBox(height: 30),

              // 🔹 Main button
              Center(
                child: isBorrowed
                    ? ElevatedButton.icon(
                        onPressed: returnItem,
                        icon: const Icon(Icons.undo),
                        label: const Text('Return Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 14),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: borrowItem,
                        icon: const Icon(Icons.handshake),
                        label: const Text('Borrow Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 14),
                        ),
                      ),
              ),

              const SizedBox(height: 15),

              // 🚨 Report button (for owner)
              if (isBorrowed && isOwner)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (borrowerId != null && borrowerId.isNotEmpty) {
                        reportBorrower(borrowerId);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('⚠️ No borrower ID available')),
                        );
                      }
                    },
                    icon: const Icon(Icons.report),
                    label: const Text('Report Borrower'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
