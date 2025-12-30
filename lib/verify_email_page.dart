// lib/verify_email_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; // 或 auth_gate.dart（看你 AuthGate 放哪）


class VerifyEmailPage extends StatefulWidget {
  final User user;
  const VerifyEmailPage({super.key, required this.user});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _checking = false;
  String? message;

  Future<void> _checkVerification() async {
  setState(() {
    _checking = true;
    message = null;
  });

  await widget.user.reload();
  final refreshedUser = FirebaseAuth.instance.currentUser;

  if (refreshedUser == null) {
    setState(() {
      _checking = false;
      message = "User session expired. Please login again.";
    });
    return;
  }

  if (!refreshedUser.emailVerified) {
    setState(() {
      _checking = false;
      message = "Email not verified yet.";
    });
    return;
  }

  final userRef = FirebaseFirestore.instance
      .collection('users')
      .doc(refreshedUser.uid);

  final snap = await userRef.get();

  if (!snap.exists) {
    // 🆕 第一次验证 → 创建 user document
    await userRef.set({
      'name': refreshedUser.displayName ?? 'Unnamed',
      'email': refreshedUser.email,
      'trustScore': 100,
      'verified': true,
      'createdAt': FieldValue.serverTimestamp(),
      'verifiedAt': FieldValue.serverTimestamp(),
    });
  } else {
    // 已存在 → 只更新 verified
    await userRef.update({
      'verified': true,
      'verifiedAt': FieldValue.serverTimestamp(),
    });
  }

  if (!mounted) return;

  // 回 AuthGate
  Navigator.pushNamedAndRemoveUntil(
    context,
    '/',
    (_) => false,
  );
}



  Future<void> _resendEmail() async {
    await widget.user.sendEmailVerification();
    setState(() => message = "Verification email resent.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Email")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email_outlined,
                size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              "Please verify your email address to continue.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            if (message != null) ...[
              Text(
                message!,
                style: TextStyle(
                  color: message!.contains("resent")
                      ? Colors.green
                      : Colors.red,
                ),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _checking ? null : _checkVerification,
                child: _checking
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("I have verified"),
              ),
            ),

            TextButton(
              onPressed: _resendEmail,
              child: const Text("Resend verification email"),
            ),
          ],
        ),
      ),
    );
  }
}
