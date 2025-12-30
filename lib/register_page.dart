// lib/register_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'verify_email_page.dart';
import 'widgets/auth_card.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;
  String? errorMessage;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Please fill all fields');
      return;
    }

    if (!email.endsWith('@sc.edu.my')) {
      setState(() => errorMessage = 'Only @sc.edu.my emails are allowed');
      return;
    }

    setState(() {
      errorMessage = null;
      _isLoading = true;
    });

    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        setState(() => errorMessage = 'Registration failed');
        return;
      }

      await user.updateDisplayName(name);
      await user.sendEmailVerification();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailPage(user: user),
        ),
      );
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
          Icons.person_add,
          color: Colors.blue,
          size: 40,
        ),
        title: 'Create account',
        subtitle: 'Use your sc.edu.my email',
        children: [
          const SizedBox(height: 8),

          _field(
            controller: nameController,
            label: 'Full name',
          ),
          const SizedBox(height: 12),

          _field(
            controller: emailController,
            label: 'Email',
            hint: 'you@sc.edu.my',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),

          _field(
            controller: passwordController,
            label: 'Password',
            obscure: true,
          ),

          const SizedBox(height: 14),

          // ===== Error message（与 Login 同款风格）=====
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

          // ===== Primary Button（高度与 Login 对齐）=====
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : register,
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
                      'Create account',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],

        // ===== Footer（与 Login 完全一致）=====
        bottomActions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Already have an account?',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== Reusable field（Login / Register 共用）=====
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
