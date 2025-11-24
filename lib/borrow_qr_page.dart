// lib/borrow_qr_page.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // 确保 pubspec 已加入 qr_flutter

class BorrowQRPage extends StatelessWidget {
  final String requestId;
  const BorrowQRPage({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Borrow Request QR Code')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '📦 Show this QR to the owner to confirm pickup',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              QrImageView(
                data: requestId,
                version: QrVersions.auto,
                size: 260.0,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 20),
              SelectableText('Request ID: $requestId', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Close'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
