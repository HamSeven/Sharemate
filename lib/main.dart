import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'login_page.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'verify_email_page.dart';

import 'theme/design_tokens.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _InitApp());
}

class _InitApp extends StatefulWidget {
  const _InitApp({Key? key}) : super(key: key);

  @override
  State<_InitApp> createState() => _InitAppState();
}

class _InitAppState extends State<_InitApp> {
  late final Future<FirebaseApp> _init;

  @override
  void initState() {
    super.initState();
    _init = Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return const ShareMateApp();
      },
    );
  }
}

class ShareMateApp extends StatelessWidget {
  const ShareMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home': (_) => const HomePage(),
        '/profile': (_) => const ProfilePage(),
      },
    );
  }
}

ThemeData _buildTheme() {
  return ThemeData(
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge:AppText.titleLarge,
      titleMedium: AppText.titleMedium,
  bodyLarge: AppText.bodyLarge,
  bodyMedium: AppText.bodyMedium,
  labelMedium: AppText.labelMedium,
    ),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        // 🔐 Not logged in
        if (user == null) {
          return const LoginPage();
        }

        // ✉️ Logged in but email not verified
        if (!user.emailVerified) {
          return VerifyEmailPage(user: user);
        }

        // ✅ Verified → enter app
        return const HomePage();
      },
    );
  }
}
