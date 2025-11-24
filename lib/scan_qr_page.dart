import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class ScanQRPage extends StatefulWidget {
  const ScanQRPage({super.key});

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage> {
  bool isProcessing = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MobileScannerController cameraController = MobileScannerController();

  // 🔹 Auto-approve borrow request after scanning QR
  Future<void> _approveBorrowRequest(String requestId) async {
    try {
      setState(() => isProcessing = true);

      final doc =
          await _firestore.collection('borrowRequests').doc(requestId).get();

      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Invalid QR code or request ID')),
        );
        setState(() => isProcessing = false);
        return;
      }

      final data = doc.data()!;
      final itemId = data['itemId'];
      final borrowerId = data['borrowerId'];

      // Update borrow request
      await _firestore.collection('borrowRequests').doc(requestId).update({
        'status': 'approved',
        'updatedAt': DateTime.now(),
      });

      // Update item
      await _firestore.collection('items').doc(itemId).update({
        'status': 'Borrowed',
        'borrowerId': borrowerId,
      });

      // Reward borrower
      final userRef = _firestore.collection('users').doc(borrowerId);
      await _firestore.runTransaction((txn) async {
        final userDoc = await txn.get(userRef);
        if (userDoc.exists) {
          final trust = userDoc['trustScore'] ?? 0;
          txn.update(userRef, {'trustScore': trust + 2});
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Borrow request approved successfully!')),
      );

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR to Approve Borrow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 🟢 Camera Scanner
          MobileScanner(
            controller: cameraController,
            fit: BoxFit.cover,
            onDetect: (capture) async {
              if (isProcessing) return;
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null && code.trim().isNotEmpty) {
                  await _approveBorrowRequest(code.trim());
                }
              }
            },
          ),

          // 🟦 Overlay box
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),

          // ⏳ Processing overlay
          if (isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Processing approval...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
