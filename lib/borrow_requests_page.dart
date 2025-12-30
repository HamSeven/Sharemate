import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'theme/design_tokens.dart';
import 'borrow_request_detail_page.dart';
import 'scan_qr_page.dart';

class BorrowRequestsPage extends StatefulWidget {
  const BorrowRequestsPage({super.key});

  @override
  State<BorrowRequestsPage> createState() => _BorrowRequestsPageState();
}

class _BorrowRequestsPageState extends State<BorrowRequestsPage>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  late TabController _tabController;

  final Map<String, Map<String, dynamic>> _itemCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  // ===============================
  // Utils
  // ===============================
  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return Colors.orange;
    }
  }

  Future<Map<String, dynamic>?> _getItem(String itemId) async {
    if (_itemCache.containsKey(itemId)) return _itemCache[itemId];

    final snap = await _firestore.collection('items').doc(itemId).get();
    if (!snap.exists) return null;

    _itemCache[itemId] = snap.data()!;
    return snap.data();
  }

  // ===============================
  // Approve + auto reject
  // ===============================
  Future<void> _approveAndRejectOthers({
    required String requestId,
    required String itemId,
    required DateTime appointmentDateTime,
    required String location,
  }) async {
    final batch = _firestore.batch();

    final reqSnap = await _firestore
        .collection('borrowRequests')
        .where('itemId', isEqualTo: itemId)
        .get();

    for (final doc in reqSnap.docs) {
      if (doc.id == requestId) {
        batch.update(doc.reference, {
          'status': 'approved',
          'appointment': {
            'dateTime': Timestamp.fromDate(appointmentDateTime),
            'location': location,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (doc['status'] == 'pending') {
        batch.update(doc.reference, {
          'status': 'rejected',
          'rejectedReason': 'Item approved for another borrower',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    batch.update(_firestore.collection('items').doc(itemId), {
      'status': 'borrowed',
    });

    await batch.commit();
  }

  // ===============================
  // Approve dialog
  // ===============================
  Future<void> _showApproveDialog({
    required BuildContext parentContext,
    required String requestId,
    required String itemId,
  }) async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final locationCtrl = TextEditingController();

    await showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text("Approve & Set Appointment"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      selectedDate == null
                          ? "Select date"
                          : "${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}",
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: dialogContext,
                        initialDate:
                            DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => selectedDate = d);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text(
                      selectedTime == null
                          ? "Select time"
                          : selectedTime!.format(dialogContext),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: dialogContext,
                        initialTime: TimeOfDay.now(),
                      );
                      if (t != null) setState(() => selectedTime = t);
                    },
                  ),
                  TextField(
                    controller: locationCtrl,
                    decoration:
                        const InputDecoration(labelText: "Location"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (selectedDate == null ||
                        selectedTime == null ||
                        locationCtrl.text.trim().isEmpty) return;

                    final dt = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );

                    await _approveAndRejectOthers(
                      requestId: requestId,
                      itemId: itemId,
                      appointmentDateTime: dt,
                      location: locationCtrl.text.trim(),
                    );

                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Approve"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===============================
  // List per status
  // ===============================
  Widget _buildList(String status) {
    final uid = _auth.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('borrowRequests')
          .where(Filter.or(
            Filter('ownerId', isEqualTo: uid),
            Filter('requesterId', isEqualTo: uid),
          ))
          .where('status', isEqualTo: status)
          .orderBy('requestedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No requests"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final isOwner = d['ownerId'] == uid;

            final displayName =
                isOwner ? d['requesterName'] : d['ownerName'];
            final displayTrust =
                isOwner ? d['requesterTrustScore'] : d['ownerTrustScore'];

            return InkWell(
              borderRadius: AppRadius.card,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BorrowRequestDetailPage(requestId: docs[i].id),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.card,
                  boxShadow: AppShadows.soft,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _getItem(d['itemId']),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const SizedBox(height: 56);
                        }
                        final item = snap.data!;
                        return Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['imageUrl'],
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item['title'],
                                style: AppText.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "$displayName • Trust $displayTrust",
                      style: AppText.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                _statusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: AppText.labelMedium.copyWith(
                              color: _statusColor(status),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (status == 'pending' && isOwner)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              _showApproveDialog(
                                parentContext: context,
                                requestId: docs[i].id,
                                itemId: d['itemId'],
                              );
                            },
                            child: const Text("Approve"),
                          ),
                        if (status == 'approved' && isOwner)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            icon:
                                const Icon(Icons.qr_code_scanner),
                            label: const Text("Scan QR"),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ScanQrPage(),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Borrow Requests"),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Approved"),
            Tab(text: "Borrowed"),
            Tab(text: "Rejected"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList('pending'),
          _buildList('approved'),
          _buildList('borrowed'),
          _buildList('rejected'),
        ],
      ),
    );
  }
}
