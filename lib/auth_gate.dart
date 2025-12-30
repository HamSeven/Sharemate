import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_page.dart';
import 'login_page.dart';
import 'verify_email_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ⏳ Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // ❌ Not logged in
        if (user == null) {
          return const LoginPage();
        }

        // ❌ Logged in but NOT verified
        if (!user.emailVerified) {
          return VerifyEmailPage(user: user);
        }

        // ✅ Logged in AND verified
        return const HomePage();
      },
    );
  }
}
