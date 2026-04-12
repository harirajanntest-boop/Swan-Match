import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════════════════
// HOW TO INTEGRATE INTO YOUR PROJECT
// ════════════════════════════════════════════════════════════════════════════
//
// Step 1 — Replace the three stub classes at the BOTTOM of this file with
//           your real imports:
//
import '../../../../core/constants/colors.dart';
import '../../../../shared/widgets/gold_button.dart';
import '../../../../shared/widgets/glass_card.dart';
//
// Step 2 — Add bgGradient to your AppColors if it is missing:
//
//   static const LinearGradient bgGradient = LinearGradient(
//     colors: [Color(0xFFFDF6EC), Color(0xFFF5E0D3), Color(0xFFFAECE8)],
//     begin:  Alignment.topCenter,
//     end:    Alignment.bottomCenter,
//   );
//
// Step 3 — Register routes in your MaterialApp:
//
//   routes: {
//     '/create-account': (_) => const CreateAccountPage(),
//     '/login':          (_) => const LoginPage(),
//   }
//
// ════════════════════════════════════════════════════════════════════════════

// ─── Onboarding Page ─────────────────────────────────────────────────────────
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  late final AnimationController _bgController;
  late final AnimationController _entryController;
  late final AnimationController _floatController;
  late final AnimationController _shimmerController;
  late final AnimationController _petalController;

  // ── Entry animations ───────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset>  _taglineSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset>  _cardSlide;
  late final Animation<double> _cardOpacity;
  late final Animation<double> _dividerWidth;

  // ── Continuous animations ──────────────────────────────────────────────────
  late final Animation<double> _floatAnim;
  late final Animation<double> _shimmerAnim;
  late final Animation<double> _petalAnim;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);

    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));

    _floatController = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);

    _shimmerController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();

    _petalController = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat();

    // ── Staggered entry choreography ──
    _logoScale = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.45, curve: Curves.elasticOut)));
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn)));
    _taglineSlide = Tween(begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.35, 0.65, curve: Curves.easeOutCubic)));
    _taglineOpacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.35, 0.6, curve: Curves.easeIn)));
    _cardSlide = Tween(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.55, 0.9, curve: Curves.easeOutCubic)));
    _cardOpacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.55, 0.85, curve: Curves.easeIn)));
    _dividerWidth = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut)));

    _floatAnim = Tween(begin: -6.0, end: 6.0).animate(
        CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
    _shimmerAnim = Tween(begin: -1.5, end: 2.5).animate(
        CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut));
    _petalAnim =
        Tween(begin: 0.0, end: 2 * math.pi).animate(_petalController);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    _petalController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _goToCreateAccount() =>
      Navigator.pushNamed(context, '/create-account');

  void _goToLogin() => Navigator.pushNamed(context, '/login');

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(children: [
        // Warm gradient bg
        Container(
            decoration:
                const BoxDecoration(gradient: AppColors.bgGradient)),

        // Drifting glow orbs
        AnimatedBuilder(
          animation: _bgController,
          builder: (_, __) {
            final t = _bgController.value;
            return Stack(children: [
              Positioned(
                  top: -60 + t * 40,
                  right: -80 + t * 30,
                  child: _GlowOrb(
                      size: 280,
                      color: AppColors.blush.withOpacity(0.35))),
              Positioned(
                  bottom: 100 - t * 50,
                  left: -60 + t * 20,
                  child: _GlowOrb(
                      size: 240,
                      color: AppColors.goldLeaf.withOpacity(0.18))),
              Positioned(
                  top: size.height * 0.4 + t * 30,
                  right: -40,
                  child: _GlowOrb(
                      size: 160,
                      color: AppColors.deepRose.withOpacity(0.12))),
            ]);
          },
        ),

        // Rotating petal mandala
        AnimatedBuilder(
          animation: _petalAnim,
          builder: (_, __) =>
              _RotatingPetals(angle: _petalAnim.value, size: size),
        ),

        // Main content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(children: [
              const SizedBox(height: 56),

              // Logo — entry spring + continuous float
              AnimatedBuilder(
                animation: Listenable.merge(
                    [_entryController, _floatController]),
                builder: (_, __) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _floatAnim.value),
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: _LogoWidget(shimmer: _shimmerAnim),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Brand name + tagline slide up
              AnimatedBuilder(
                animation: _entryController,
                builder: (_, __) => FadeTransition(
                  opacity: _taglineOpacity,
                  child: SlideTransition(
                    position: _taglineSlide,
                    child: Column(children: [
                      _BrandName(shimmer: _shimmerAnim),
                      const SizedBox(height: 8),
                      const Text(
                        "Where hearts find their home",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.deepRose,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),

              const Spacer(),

              // Glass card rises from bottom
              AnimatedBuilder(
                animation: _entryController,
                builder: (_, __) => FadeTransition(
                  opacity: _cardOpacity,
                  child: SlideTransition(
                    position: _cardSlide,
                    child: _BottomCard(
                      dividerProgress:  _dividerWidth,
                      shimmer:          _shimmerAnim,
                      onCreateAccount:  _goToCreateAccount, // ← working
                      onLogin:          _goToLogin,         // ← working
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Glow orb ─────────────────────────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final double size;
  final Color  color;
  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 80, spreadRadius: 20)
          ],
        ),
      );
}

// ─── Petal mandala ────────────────────────────────────────────────────────────
class _RotatingPetals extends StatelessWidget {
  final double angle;
  final Size   size;
  const _RotatingPetals({required this.angle, required this.size});

  @override
  Widget build(BuildContext context) => Positioned(
        top:  size.height * 0.08,
        left: size.width  * 0.5 - 180,
        child: Transform.rotate(
          angle: angle * 0.05,
          child: CustomPaint(
              size: const Size(360, 360),
              painter: _PetalPainter(opacity: 0.06)),
        ),
      );
}

class _PetalPainter extends CustomPainter {
  final double opacity;
  const _PetalPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.deepRose.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 8; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((2 * math.pi / 8) * i);
      canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..cubicTo(-19, -52, -19, -91, 0, -130)
            ..cubicTo(19, -91, 19, -52, 0, 0),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PetalPainter old) => old.opacity != opacity;
}

// ─── Logo ring ────────────────────────────────────────────────────────────────
class _LogoWidget extends StatelessWidget {
  final Animation<double> shimmer;
  const _LogoWidget({required this.shimmer});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) => Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFFFF8F0), AppColors.warmCream],
              radius: 0.85,
            ),
            boxShadow: [
              BoxShadow(
                  color: AppColors.deepRose.withOpacity(0.20),
                  blurRadius: 32, spreadRadius: 4,
                  offset: const Offset(0, 8)),
              BoxShadow(
                  color: AppColors.goldLeaf.withOpacity(0.25),
                  blurRadius: 20, spreadRadius: -4),
            ],
          ),
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.goldLeaf.withOpacity(0.6),
                      width: 1.2)),
            ),
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.blush.withOpacity(0.4),
                      width: 0.6)),
            ),
            ShaderMask(
              shaderCallback: (b) => LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                colors: [
                  AppColors.deepRose, AppColors.deepRose,
                  AppColors.deepRose.withOpacity(0.4),
                  AppColors.deepRose, AppColors.deepRose,
                ],
                transform: GradientRotation(shimmer.value),
              ).createShader(b),
              child: const Icon(Icons.favorite,
                  color: Colors.white, size: 38),
            ),
          ]),
        ),
      );
}

// ─── Shimmer brand name ───────────────────────────────────────────────────────
class _BrandName extends StatelessWidget {
  final Animation<double> shimmer;
  const _BrandName({required this.shimmer});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) => ShaderMask(
          shaderCallback: (b) => LinearGradient(
            colors: const [
              AppColors.deepMaroon, AppColors.deepRose,
              AppColors.goldLeaf,   AppColors.deepRose,
              AppColors.deepMaroon,
            ],
            stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            transform: GradientRotation(shimmer.value * 0.4),
          ).createShader(b),
          child: const Text(
            "SWAN MATCH",
            style: TextStyle(
              color: Colors.white, fontSize: 30,
              fontWeight: FontWeight.w700, letterSpacing: 7,
            ),
          ),
        ),
      );
}

// ─── Bottom glass card ────────────────────────────────────────────────────────
class _BottomCard extends StatelessWidget {
  final Animation<double> dividerProgress;
  final Animation<double> shimmer;
  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

  const _BottomCard({
    required this.dividerProgress,
    required this.shimmer,
    required this.onCreateAccount,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    // ── Uses YOUR GlassCard widget ──
    return GlassCard(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Kolam divider animates after card appears
        AnimatedBuilder(
          animation: dividerProgress,
          builder: (_, __) =>
              _KolamDivider(progress: dividerProgress.value),
        ),

        const SizedBox(height: 20),

        const Text(
          "Your forever begins here.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.charcoal, fontSize: 20,
            fontWeight: FontWeight.w600, letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Trusted by millions of Tamil families worldwide",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.deepRose.withOpacity(0.8),
            fontSize: 12, letterSpacing: 0.4,
          ),
        ),

        const SizedBox(height: 28),

        // ── PRIMARY: YOUR GoldGradientButton → /create-account ──
        GoldGradientButton(
          text:      "CREATE PROFILE",
          onPressed: onCreateAccount,
        ),

        const SizedBox(height: 16),

        // ── Divider ──
        Row(children: [
          Expanded(
              child: Container(
                  height: 1,
                  color: AppColors.blush.withOpacity(0.35))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text("or",
                style: TextStyle(
                  color: AppColors.deepRose.withOpacity(0.6),
                  fontSize: 13, fontStyle: FontStyle.italic,
                )),
          ),
          Expanded(
              child: Container(
                  height: 1,
                  color: AppColors.blush.withOpacity(0.35))),
        ]),

        const SizedBox(height: 16),

        // ── SECONDARY: Outlined login button → /login ──
        // Matches the same height/radius as GoldGradientButton
        _LoginButton(onPressed: onLogin),

        const SizedBox(height: 20),

        _TrustBadges(shimmer: shimmer),
      ]),
    );
  }
}

// ─── Outlined login button ────────────────────────────────────────────────────
// Mirror of GoldGradientButton (same 55 h, same border-radius 30)
// but outlined in deepRose instead of filled gold.
class _LoginButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _LoginButton({required this.onPressed});

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); widget.onPressed(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          height: 55,                          // same as GoldGradientButton
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30), // same as GoldGradientButton
            border: Border.all(
                color: AppColors.deepRose.withOpacity(0.55), width: 1.4),
            color: AppColors.deepRose.withOpacity(0.04),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.login_rounded,
                color: AppColors.deepRose.withOpacity(0.85), size: 18),
            const SizedBox(width: 10),
            Text(
              "MEMBER LOGIN",
              style: TextStyle(
                color: AppColors.deepRose.withOpacity(0.85),
                fontSize:     16,
                fontWeight:   FontWeight.bold,
                letterSpacing: 1.2,           // same as GoldGradientButton
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Kolam divider ────────────────────────────────────────────────────────────
class _KolamDivider extends StatelessWidget {
  final double progress;
  const _KolamDivider({required this.progress});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 20,
        child: CustomPaint(
            size: const Size(double.infinity, 20),
            painter: _KolamPainter(progress: progress)),
      );
}

class _KolamPainter extends CustomPainter {
  final double progress;
  const _KolamPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color       = AppColors.goldLeaf.withOpacity(0.55)
      ..strokeWidth = 1.0
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    final dot = Paint()
      ..color = AppColors.deepRose.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final w  = size.width * progress;

    if (progress > 0.4) {
      final p  = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
      final ds = 5.0 * p;
      canvas.drawPath(
          Path()
            ..moveTo(cx, cy - ds) ..lineTo(cx + ds, cy)
            ..lineTo(cx, cy + ds) ..lineTo(cx - ds, cy) ..close(),
          line);
      canvas.drawCircle(Offset(cx, cy), 2 * p, dot);
    }

    canvas.drawLine(Offset(cx - w / 2, cy), Offset(cx + w / 2, cy), line);

    if (progress > 0.2) {
      final n = (w / 2 / 18).floor();
      for (int i = 1; i <= n; i++) {
        canvas.drawCircle(Offset(cx + i * 18, cy), 1.5, dot);
        canvas.drawCircle(Offset(cx - i * 18, cy), 1.5, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_KolamPainter old) => old.progress != progress;
}

// ─── Trust badges ─────────────────────────────────────────────────────────────
class _TrustBadges extends StatelessWidget {
  final Animation<double> shimmer;
  const _TrustBadges({required this.shimmer});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.verified_rounded, "Verified\nProfiles"),
      (Icons.shield_rounded,   "100% Safe\n& Secure"),
      (Icons.people_rounded,   "5M+\nMembers"),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((b) => Column(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.warmCream, shape: BoxShape.circle,
            border: Border.all(color: AppColors.goldLeaf.withOpacity(0.35)),
          ),
          child: Icon(b.$1, color: AppColors.deepRose, size: 18),
        ),
        const SizedBox(height: 6),
        Text(b.$2,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.charcoal.withOpacity(0.65),
              fontSize: 10, letterSpacing: 0.3,
            )),
      ])).toList(),
    );
  }
}
