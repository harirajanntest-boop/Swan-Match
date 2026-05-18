import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/payment_flow_service.dart';
import 'main_dashboard.dart';

/// Stays visible until the user taps [Back to Home] — no auto-dismiss.

class PaymentStatusPage extends StatefulWidget {
  final bool isSuccess;

  const PaymentStatusPage({super.key, required this.isSuccess});

  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<double>? _fadeIn;
  Animation<Offset>? _slideUp;

  @override
  void initState() {
    super.initState();
    if (widget.isSuccess) {
      PaymentFlowService.setCongratsVisible(true);
      PaymentFlowService.markCongratulationsDisplayed();
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      )..forward();
      _fadeIn = CurvedAnimation(parent: _ctrl!, curve: Curves.easeOut);
      _slideUp = Tween<Offset>(
        begin: const Offset(0, 0.18),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _ctrl!, curve: Curves.easeOut));
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (await PaymentFlowService.hasShownSuccessScreen()) {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainDashboard()),
            (r) => false,
          );
          return;
        }
        await PaymentFlowService.syncPaidSubscription();
      });
    }
  }

  @override
  void dispose() {
    if (widget.isSuccess) {
      PaymentFlowService.setCongratsVisible(false);
    }
    _ctrl?.dispose();
    super.dispose();
  }

  List<Widget> _confettiDots() {
    return const [
      _ConfettiDot(left: 18, top: 90, size: 6),
      _ConfettiDot(left: 55, top: 180, size: 4),
      _ConfettiDot(left: 120, top: 60, size: 5),
      _ConfettiDot(right: 22, top: 110, size: 7),
      _ConfettiDot(right: 68, top: 200, size: 4),
      _ConfettiDot(right: 140, top: 75, size: 5),
      _ConfettiDot(left: 35, bottom: 260, size: 5),
      _ConfettiDot(right: 40, bottom: 280, size: 6),
      _ConfettiDot(left: 80, bottom: 180, size: 4),
      _ConfettiDot(right: 85, bottom: 190, size: 4),
      _ConfettiDot(left: 200, top: 130, size: 4),
      _ConfettiDot(right: 200, bottom: 130, size: 5),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSuccess) {
      return PopScope(
        canPop: false,
        child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Couple photo fills entire screen ──────────────────────────
            Image.asset(
              'assets/images/sucess.png',
              fit: BoxFit.cover,
            ),

            // ── Dark gradient at bottom for text readability ──────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.35, 0.65, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.55),
                      Colors.black.withOpacity(0.92),
                    ],
                  ),
                ),
              ),
            ),

            // ── Scattered gold confetti dots ──────────────────────────────
            ..._confettiDots(),

            // ── Text + button block ───────────────────────────────────────
            Positioned(
              left: 28,
              right: 28,
              bottom: 56,
              child: FadeTransition(
                opacity: _fadeIn!,
                child: SlideTransition(
                  position: _slideUp!,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Heading
                      const Text(
                        "Here's to your\nfuture together 💛",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Sub-heading
                      const Text(
                        "We're happy for you!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Back to Home button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              await PaymentFlowService.markSuccessScreenShown();
                              if (!context.mounted) return;
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MainDashboard(),
                                ),
                                (r) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                letterSpacing: 0.4,
                              ),
                            ),
                            child: const Text('Back to Home'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Payment Failed",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Your subscription checkout was not completed. Please try again.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MainDashboard()),
                  (r) => false,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: Text(
                      "Back to Home",
                      style: TextStyle(
                        color: AppColors.obsidian,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfettiDot extends StatelessWidget {
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;

  const _ConfettiDot({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.goldMedium.withOpacity(0.75),
        ),
      ),
    );
  }
}
