import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController controller = MobileScannerController();
  bool processing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Borrow QR")),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) async {
          if (processing) return;

          final barcode = capture.barcodes.first;
          final raw = barcode.rawValue;

          if (raw == null || raw.isEmpty) return;

          processing = true; // 🔒 硬锁
          controller.stop(); // 🔒 立刻停 scanner

          await _processQR(context, raw);
        },
      ),
    );
  }

  Future<void> _processQR(BuildContext context, String raw) async {
    debugPrint("========== QR DEBUG ==========");
debugPrint("RAW STRING: [$raw]");
debugPrint("RAW LENGTH: ${raw.length}");
debugPrint("RAW CODE UNITS: ${raw.codeUnits}");
debugPrint("==============================");
    try {
      // 🔥 关键：清洗 QR 字串（mobile_scanner 坑点）
      final cleaned = raw
          .trim()
          .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');

      debugPrint("QR RAW CLEANED = $cleaned");

      // 🔒 必须是 JSON
      if (!cleaned.startsWith('{') || !cleaned.endsWith('}')) {
        throw Exception('Not JSON');
      }

      final Map<String, dynamic> data = jsonDecode(cleaned);

      // 🔒 字段完整性校验
      final requiredKeys = [
        'requestId',
        'itemId',
        'requesterId',
        'ownerId',
        'appointmentTime',
      ];

      for (final k in requiredKeys) {
        if (!data.containsKey(k)) {
          throw Exception('Missing field: $k');
        }
      }

      final String requestId = data['requestId'];
      final String itemId = data['itemId'];
      final String requesterId = data['requesterId'];
      final String ownerId = data['ownerId'];
      final int appointmentMs = data['appointmentTime'];

      final currentUid = FirebaseAuth.instance.currentUser!.uid;

      // 🔒 只有 owner 能扫
      if (currentUid != ownerId) {
        _exit("❌ 只有 Owner 可以确认借出");
        return;
      }

      final reqRef =
          FirebaseFirestore.instance.collection('borrowRequests').doc(requestId);
      final snap = await reqRef.get();

      if (!snap.exists) {
        _exit("❌ 请求不存在");
        return;
      }

      final req = snap.data()!;

      if (req['status'] != 'approved') {
        _exit("⚠️ 请求已处理或不可用");
        return;
      }

      // ⏱️ 时间校验（宽松版）
      final apptTime =
          DateTime.fromMillisecondsSinceEpoch(appointmentMs).toLocal();
      final diff = DateTime.now().difference(apptTime).inHours.abs();

      if (diff > 48) {
        _exit("⚠️ 不在预约时间范围内");
        return;
      }

      // ✅ 确认借出
      await reqRef.update({
        'status': 'borrowed',
        'borrowedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('items')
          .doc(itemId)
          .update({
        'status': 'borrowed',
        'borrowerId': requesterId,
      });

      _exit("✅ 借出成功确认！");
    } catch (e) {
      debugPrint("QR PARSE ERROR = $e");
      _exit("❌ QR 无效或解析失败");
    }
  }

  void _exit(String msg) async {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));

    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
