import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'verify_email_page.dart';
import 'widgets/auth_card.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String? errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    setState(() {
      _isLoading = true;
      errorMessage = null;
    });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = cred.user;
      if (user == null) {
        setState(() => errorMessage = "Login failed.");
        return;
      }

      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;

      if (refreshed != null && !refreshed.emailVerified) {
        await refreshed.sendEmailVerification();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailPage(user: refreshed),
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');

    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: AuthCard(
        headerIcon: const Icon(
          Icons.lock_open_rounded,
          color: Colors.blue,
          size: 40, // ✅ 对齐 Register
        ),
        title: "Welcome back",
        subtitle: "Sign in with your sc.edu.my email",
        children: [
          const SizedBox(height: 8),

          _field(
            controller: emailController,
            label: "Email",
            hint: "you@sc.edu.my",
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),

          _field(
            controller: passwordController,
            label: "Password",
            obscure: true,
          ),

          const SizedBox(height: 14),

          // ===== Error message（与 Register 同款）=====
          if (errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 6),

          // ===== Primary Button（高度对齐）=====
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Login",
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],

        // ===== Footer（与 Register 行为一致）=====
        bottomActions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Don't have an account?",
                style: TextStyle(color: Colors.grey.shade600),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/register'),
                child: const Text("Register"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== Reusable field（与 Register 完全一致）=====
  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
