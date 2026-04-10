import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:swam_match_app/firebase_options.dart';
import 'package:swam_match_app/core/constants/colors.dart';
import 'package:swam_match_app/features/auth/presentation/pages/onboarding_page.dart';
import 'package:swam_match_app/features/auth/presentation/pages/create_account_page.dart';
import 'package:swam_match_app/features/auth/presentation/pages/login_page.dart';
import 'package:swam_match_app/features/auth/presentation/pages/main_dashboard.dart';
import 'package:swam_match_app/services/push_notification_service.dart';
import 'package:swam_match_app/services/auth_service.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? initError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PushNotificationService.instance.initialize();
  } catch (error) {
    initError = error.toString();
  }

  runApp(SwamMatchApp(firebaseInitError: initError));
}

class SwamMatchApp extends StatefulWidget {
  final String? firebaseInitError;

  const SwamMatchApp({super.key, this.firebaseInitError});

  @override
  State<SwamMatchApp> createState() => _SwamMatchAppState();
}

class _SwamMatchAppState extends State<SwamMatchApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initEmailLinkListener();
  }

  Future<void> _initEmailLinkListener() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        await _handleEmailLink(initialLink.toString());
      }
    } catch (_) {}

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
      await _handleEmailLink(uri.toString());
    });
  }

  Future<void> _handleEmailLink(String link) async {
    try {
      if (AuthService.instance.isEmailLink(link)) {
        await AuthService.instance.completeEmailLinkSignIn(link);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFirebaseError = widget.firebaseInitError != null;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Swam Match',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'serif',
        // Sets the main background to deep black
        scaffoldBackgroundColor: AppColors.ivory, 
        primaryColor: AppColors.goldMedium,
        // Adds cinematic global animations when navigating between pages
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
        home: hasFirebaseError
          ? FirebaseSetupRequiredPage(error: widget.firebaseInitError!)
          : const _AuthGate(),
      routes: hasFirebaseError
          ? const {}
          : {
              '/create-account': (context) => const CreateAccountPage(),
              '/login': (context) => const LoginPage(),
            },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.ivory,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.goldMedium),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const OnboardingPage();
        }
        return const MainDashboard();
      },
    );
  }
}

class FirebaseSetupRequiredPage extends StatelessWidget {
  final String error;

  const FirebaseSetupRequiredPage({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              const Text(
                'Firebase setup required',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Run FlutterFire setup and add Firebase config files before using login/registration.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SelectableText(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}