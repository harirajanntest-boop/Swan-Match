import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:swam_match_app/firebase_options.dart';
import 'package:swam_match_app/core/constants/colors.dart';
import 'package:swam_match_app/features/auth/presentation/pages/main_dashboard.dart';
import 'package:swam_match_app/services/payment_flow_service.dart';
import 'package:swam_match_app/services/push_notification_service.dart';
import 'package:swam_match_app/features/auth/presentation/pages/payment_status_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:swam_match_app/features/auth/presentation/pages/splash_page.dart';
import 'package:swam_match_app/features/auth/presentation/pages/profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swam_match_app/services/stripe_service.dart';
import 'package:swam_match_app/services/user_service.dart';

/// Global Firebase Analytics instance — use anywhere in the app:
/// `analytics.logEvent(name: 'swipe_right', parameters: {'target_uid': uid})`
final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── Crash reporting: capture any Flutter framework errors ───────────────
  // Must be initialised before runApp so errors during startup are captured.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Pass all uncaught Flutter framework errors to Crashlytics.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Pass uncaught async errors from the Dart platform layer to Crashlytics.
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Enable crash collection in release mode only; disable in debug so
  // crash reports don't pollute production data during development.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  runApp(const SwamMatchApp());
}

class SwamMatchApp extends StatefulWidget {
  const SwamMatchApp({super.key});

  @override
  State<SwamMatchApp> createState() => _SwamMatchAppState();
}

class _SwamMatchAppState extends State<SwamMatchApp> with WidgetsBindingObserver {
  late final Future<String?> _initFuture;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _initializeApp();
    _initFuture.then((_) async {
      await PaymentFlowService.reconcileCheckoutState();
      if (mounted) _initDeepLinks();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initDeepLinks() {
    _appLinks.uriLinkStream.listen(_handlePaymentUri, onError: (_) {});
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handlePaymentUri(uri);
    });
  }

  bool _isPaymentSuccessUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return host == 'payment-success' ||
        path.contains('payment-success') ||
        uri.toString().contains('payment-success');
  }

  bool _isPaymentCancelUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return host == 'payment-cancel' ||
        path.contains('payment-cancel') ||
        uri.toString().contains('payment-cancel');
  }

  Future<void> _handlePaymentUri(Uri uri) async {
    if (_isPaymentSuccessUri(uri)) {
      await PaymentFlowService.handlePaymentSuccessDeepLink();
    } else if (_isPaymentCancelUri(uri)) {
      await PaymentFlowService.clearCheckoutPending();
      final nav = _navigatorKey.currentState;
      if (nav == null) return;
      nav.pushNamedAndRemoveUntil('/payment-cancel', (route) => false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      UserService.instance.updateOnlineStatus(true);
      _onAppResumed();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      UserService.instance.updateOnlineStatus(false);
    }
  }

  Future<void> _onAppResumed() async {
    await PaymentFlowService.presentCongratulationsIfPaid();
  }

  Future<String?> _initializeApp() async {
    try {
      await _performInitialization().timeout(const Duration(seconds: 12));
      return null;
    } catch (error) {
      debugPrint("Initialization error: $error");
      return error.toString();
    }
  }

  Future<void> _performInitialization() async {
    // Firebase.initializeApp() was already called in main() before runApp().
    // Calling it a second time is safe — it returns the existing app instance.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      );
    } catch (e) {
      debugPrint("App Check initialization error: $e");
    }

    // ─── Analytics: set analytics collection on/off per build mode ─────────
    await analytics.setAnalyticsCollectionEnabled(!kDebugMode);
    // Log app_open event so we can track daily active users in Firebase console
    await analytics.logAppOpen();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushNotificationService.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _initFuture,
      builder: (context, snapshot) {
        final initDone = snapshot.connectionState == ConnectionState.done;
        final initError = initDone ? snapshot.data : null;
        final hasFirebaseError = initError != null;

        PaymentFlowService.navigatorKey = _navigatorKey;

        return MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Swan Match',
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: GoogleFonts.poppins().fontFamily,
            textTheme: TextTheme(
              displayLarge: GoogleFonts.poppins(),
              displayMedium: GoogleFonts.poppins(),
              displaySmall: GoogleFonts.poppins(),
              headlineLarge: GoogleFonts.poppins(),
              headlineMedium: GoogleFonts.poppins(),
              headlineSmall: GoogleFonts.poppins(),
              titleLarge: GoogleFonts.poppins(),
              titleMedium: GoogleFonts.poppins(),
              titleSmall: GoogleFonts.poppins(),
              bodyLarge: GoogleFonts.poppins(),
              bodyMedium: GoogleFonts.poppins(),
              bodySmall: GoogleFonts.poppins(),
              labelLarge: GoogleFonts.poppins(),
              labelMedium: GoogleFonts.poppins(),
              labelSmall: GoogleFonts.poppins(),
            ),
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
                  '/profile': (context) => const ProfileScreen(),
                  '/payment-success': (context) =>
                      const PaymentStatusPage(isSuccess: true),
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
    // Return a solid black screen during Firebase init.
    // This perfectly matches the native splash screen and allows 
    // the animated SplashPage to fade in seamlessly afterwards.
    return const Scaffold(
      backgroundColor: Colors.black,
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
