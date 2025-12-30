import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Owner view: list pending requests for the owner's items,
/// sorted by requester rating. Owner can open Approve dialog
/// to set appointment (date/time/location).
///
/// Save as: lib/owner_approve_with_appointment.dart
class OwnerApproveRequestsPage extends StatefulWidget {
  @override
  _OwnerApproveRequestsPageState createState() => _OwnerApproveRequestsPageState();
}

class _OwnerApproveRequestsPageState extends State<OwnerApproveRequestsPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? get _user => _auth.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Requests')),
        body: Center(child: Text('请先登录')),
      );
    }

    // Query borrowRequests where ownerId == current user and status == 'pending'
    // We will fetch the requests, then join requester rating (client-side) for sorting.
    return Scaffold(
      appBar: AppBar(title: Text('Borrow Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('borrowRequests')
            .where('ownerId', isEqualTo: _user!.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.hasError) return Center(child: Text('加载失败'));
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(child: Text('目前没有待处理的请求'));
          }

          // We'll fetch requester ratings for each request (client-side)
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _augmentWithRequesterRatings(docs),
            builder: (ctx2, snap2) {
              if (snap2.connectionState != ConnectionState.done) {
                return Center(child: CircularProgressIndicator());
              }
              final items = snap2.data ?? [];

              // Sort by requesterRating desc (nulls treated as 0)
              items.sort((a, b) {
                final ra = (a['requesterRating'] ?? 0) as num;
                final rb = (b['requesterRating'] ?? 0) as num;
                return rb.compareTo(ra);
              });

              return ListView.separated(
                padding: EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(),
                itemBuilder: (ctx3, i) {
                  final item = items[i];
                  final req = item['requestDoc'] as QueryDocumentSnapshot;
                  final requesterName = item['requesterName'] ?? 'Unknown';
                  final rating = item['requesterRating'] ?? 0;
                  final itemTitle = req['itemTitle'] ?? req['itemId'] ?? 'Item';

                  return ListTile(
                    title: Text(itemTitle),
                    subtitle: Text('Requester: $requesterName · Rating: ${rating.toString()}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          child: Text('详情'),
                          onPressed: () => _showRequestDetail(req),
                        ),
                        ElevatedButton(
                          child: Text('批准'),
                          onPressed: () async {
                            await showApproveWithAppointmentDialog(
                              context,
                              requestId: req.id,
                              itemId: req['itemId'] ?? '',
                              ownerId: _user!.uid,
                              requesterId: req['requesterId'] ?? '',
                            );
                          },
                        )
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _augmentWithRequesterRatings(List<QueryDocumentSnapshot> docs) async {
    final results = <Map<String, dynamic>>[];
    for (final d in docs) {
      final requesterId = d['requesterId'] as String? ?? '';
      String? requesterName;
      num? rating;
      if (requesterId.isNotEmpty) {
        final userSnap = await _firestore.collection('users').doc(requesterId).get();
        if (userSnap.exists) {
          final udata = userSnap.data();
          requesterName = udata?['name'] as String?;
          rating = udata?['rating'] as num?;
        }
      }
      results.add({
        'requestDoc': d,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'requesterRating': rating,
      });
    }
    return results;
  }

  void _showRequestDetail(QueryDocumentSnapshot req) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request Detail'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Item: ${req['itemTitle'] ?? req['itemId']}'),
            SizedBox(height: 8),
            Text('Requester: ${req['requesterId']}'),
            SizedBox(height: 8),
            Text('Message: ${req['message'] ?? '-'}'),
            SizedBox(height: 8),
            Text('Created: ${_formatTimestamp(req['createdAt'])}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('关闭')),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '-';
    try {
      final d = (ts as Timestamp).toDate();
      return DateFormat.yMd().add_jm().format(d.toLocal());
    } catch (e) {
      return ts.toString();
    }
  }
}

/// Show approve dialog used by Owner to set appointment and approve the request.
/// It updates borrowRequests/{requestId} with:
///  - status: 'approved'
///  - ownerDecisionAt: serverTimestamp
///  - appointment: { dateTime: Timestamp, location: string, approvedBy: ownerId }
Future<void> showApproveWithAppointmentDialog(
  BuildContext context, {
  required String requestId,
  required String itemId,
  required String ownerId,
  required String requesterId,
}) async {
  DateTime? chosenDate;
  TimeOfDay? chosenTime;
  String location = '';

  Future pickDate(BuildContext ctx) async {
    final d = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (d != null) chosenDate = d;
  }

  Future pickTime(BuildContext ctx) async {
    final t = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay(hour: 10, minute: 0),
    );
    if (t != null) chosenTime = t;
  }

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final displayDate = chosenDate != null ? DateFormat.yMMMMd().format(chosenDate!) : '请选择日期';
        final displayTime = chosenTime != null ? chosenTime!.format(ctx) : '请选择时间';

        return AlertDialog(
          title: Text('批准并设置预约'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.calendar_today),
                  title: Text(displayDate),
                  onTap: () async {
                    await pickDate(ctx);
                    setState(() {});
                  },
                ),
                ListTile(
                  leading: Icon(Icons.access_time),
                  title: Text(displayTime),
                  onTap: () async {
                    await pickTime(ctx);
                    setState(() {});
                  },
                ),
                TextField(
                  decoration: InputDecoration(labelText: '地点 (e.g. IEB ground floor)'),
                  onChanged: (v) => location = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('取消')),
            TextButton(
              onPressed: () async {
                if (chosenDate == null || chosenTime == null || location.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('请填写日期、时间与地点')));
                  return;
                }

                final dt = DateTime(
                  chosenDate!.year,
                  chosenDate!.month,
                  chosenDate!.day,
                  chosenTime!.hour,
                  chosenTime!.minute,
                );

                final appointment = {
                  'dateTime': Timestamp.fromDate(dt.toUtc()),
                  'location': location.trim(),
                  'approvedBy': ownerId,
                };

                final reqRef = FirebaseFirestore.instance.collection('borrowRequests').doc(requestId);

                // Update status & appointment
                await reqRef.update({
                  'status': 'approved',
                  'ownerDecisionAt': FieldValue.serverTimestamp(),
                  'appointment': appointment,
                  // Optionally create qr placeholder, issuedAt set when borrower views/generates qr
                  'qr': FieldValue.delete(), // remove old qr if any
                });

                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已批准并设置预约')));
              },
              child: Text('确认'),
            )
          ],
        );
      });
    },
  );
}
