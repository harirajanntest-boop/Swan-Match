import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:swam_match_app/firebase_options.dart';
import 'package:swam_match_app/core/constants/colors.dart';
import 'package:swam_match_app/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:swam_match_app/features/auth/presentation/pages/splash_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swam_match_app/services/user_service.dart';
import 'package:swam_match_app/core/navigation/app_route_observer.dart';

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

  // Pass all uncaught Flutter framework errors to Crashlytics — and still
  // print them to the device log, which replacing onError otherwise silences
  // (a red error screen then leaves no trace in `adb logcat` / Xcode).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      UserService.instance.updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      UserService.instance.updateOnlineStatus(false);
    }
  }

  Future<String?> _initializeApp() async {
    // Firebase core is the ONLY step that must succeed for the app to run.
    // (main() already called it; this returns the existing instance.) If this
    // fails, the app legitimately can't work → show "Firebase setup required".
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 15));
    } catch (error) {
      debugPrint("Firebase core init error: $error");
      return error.toString();
    }

    // Everything else is best-effort and must NEVER block the app or trigger
    // the "Firebase setup required" screen. Run it fire-and-forget so a hang —
    // e.g. push notifications on the iOS Simulator, which has no APNs, or App
    // Check on the Simulator — can't cascade into the fatal error path. (The old
    // code awaited these under a 12s outer timeout while their own timeouts
    // summed to 16s, so the Simulator always tripped the fatal path.)
    unawaited(_initBestEffortServices());
    return null;
  }

  Future<void> _initBestEffortServices() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint("App Check initialization error: $e");
    }

    // ─── Analytics (best-effort) ───────────────────────────────────────────
    try {
      await analytics.setAnalyticsCollectionEnabled(!kDebugMode);
      await analytics.logAppOpen();
    } catch (e) {
      debugPrint("Analytics initialization error: $e");
    }

    // ─── Push notifications (best-effort; no APNs token on the Simulator) ──
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await PushNotificationService.instance
          .initialize()
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint("Push notification initialization error: $e");
    }
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
          navigatorObservers: [appRouteObserver],
          // App-wide: tapping anywhere outside a text field closes the
          // keyboard. iOS has no system "back" to dismiss it, and multiline
          // fields (e.g. Bio) use Return for a new line, so without this the
          // keyboard stayed open on every page. Buttons and text fields win
          // the tap first, so they behave exactly as before.
          builder: (context, child) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child,
          ),
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
