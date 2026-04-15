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
import 'package:swam_match_app/services/notification_service.dart' as v1;
import 'package:swam_match_app/features/auth/presentation/pages/payment_status_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:swam_match_app/features/auth/presentation/pages/splash_page.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SwamMatchApp());
}

class SwamMatchApp extends StatefulWidget {
  const SwamMatchApp({super.key});

  @override
  State<SwamMatchApp> createState() => _SwamMatchAppState();
}

class _SwamMatchAppState extends State<SwamMatchApp> {
  late final Future<String?> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  Future<String?> _initializeApp() async {
    try {
      await _performInitialization().timeout(const Duration(seconds: 12));
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Future<void> _performInitialization() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushNotificationService.instance.initialize();
    await v1.NotificationService.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _initFuture,
      builder: (context, snapshot) {
        final initDone = snapshot.connectionState == ConnectionState.done;
        final initError = initDone ? snapshot.data : null;
        final hasFirebaseError = initError != null;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Swan Match',
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
            // ─── Global Gold SnackBar Theme ───────────────────────────────────────
            snackBarTheme: SnackBarThemeData(
              backgroundColor: const Color(0xFF1A1400),   // deep dark-gold background
              contentTextStyle: const TextStyle(
                color: Color(0xFFF1D592),                 // goldLight text
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(
                  color: Color(0xFFD4AF37),               // goldMedium border
                  width: 1,
                ),
              ),
              behavior: SnackBarBehavior.floating,
              insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              elevation: 8,
            ),
          ),
          home: !initDone
              ? const _AppLoadingScreen()
              : hasFirebaseError
                  ? FirebaseSetupRequiredPage(error: initError)
                  : const SplashPage(),
          routes: !initDone || hasFirebaseError
              ? const {}
              : {
                  '/create-account': (context) => const CreateAccountPage(),
                  '/login': (context) => const LoginPage(),
                  '/payment-success': (context) => const PaymentStatusPage(isSuccess: true),
                  '/payment-cancel': (context) => const PaymentStatusPage(isSuccess: false),
                },
        );
      },
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.ivory,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.goldMedium),
      ),
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