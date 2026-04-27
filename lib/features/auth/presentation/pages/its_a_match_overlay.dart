import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/colors.dart';
import 'chat_conversation_page.dart';

/// Full-screen "It's a Match!" celebration overlay.
/// Shows when the current user's interest is accepted by the other party.
/// Dismiss by tapping "Start Chatting" or "Maybe Later".
class ItsAMatchOverlay extends StatefulWidget {
  final String myPhotoUrl;
  final String theirPhotoUrl;
  final String theirName;
  final String theirUserId;

  const ItsAMatchOverlay({
    super.key,
    required this.myPhotoUrl,
    required this.theirPhotoUrl,
    required this.theirName,
    required this.theirUserId,
  });

  /// Helper — push this overlay on top of the current route.
  static Future<void> show(
    BuildContext context, {
    required String myPhotoUrl,
    required String theirPhotoUrl,
    required String theirName,
    required String theirUserId,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.85),
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => ItsAMatchOverlay(
          myPhotoUrl: myPhotoUrl,
          theirPhotoUrl: theirPhotoUrl,
          theirName: theirName,
          theirUserId: theirUserId,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<ItsAMatchOverlay> createState() => _ItsAMatchOverlayState();
}

class _ItsAMatchOverlayState extends State<ItsAMatchOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _heartController;
  late final AnimationController _avatarController;
  late final AnimationController _titleController;

  late final Animation<double> _heartScale;
  late final Animation<double> _leftAvatarSlide;
  late final Animation<double> _rightAvatarSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleScale;

  @override
  void initState() {
    super.initState();

    _avatarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _leftAvatarSlide = Tween<double>(begin: -1.5, end: 0).animate(
      CurvedAnimation(parent: _avatarController, curve: Curves.easeOutBack),
    );
    _rightAvatarSlide = Tween<double>(begin: 1.5, end: 0).animate(
      CurvedAnimation(parent: _avatarController, curve: Curves.easeOutBack),
    );
    _heartScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
    );
    _titleFade = CurvedAnimation(parent: _titleController, curve: Curves.easeIn);
    _titleScale = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOutBack),
    );

    // Sequence: avatars → heart → title
    _avatarController.forward().then((_) {
      _heartController.forward().then((_) {
        _titleController.forward();
      });
    });
  }

  @override
  void dispose() {
    _avatarController.dispose();
    _heartController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── Particle background ───
          const _GoldParticles(),

          // ─── Main content ───
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // ─── Two avatars + heart ───
                SizedBox(
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Left avatar (my photo)
                      AnimatedBuilder(
                        animation: _leftAvatarSlide,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(_leftAvatarSlide.value * 120, 0),
                          child: child,
                        ),
                        child: _Avatar(photoUrl: widget.myPhotoUrl, offset: -56),
                      ),
                      // Right avatar (their photo)
                      AnimatedBuilder(
                        animation: _rightAvatarSlide,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(_rightAvatarSlide.value * 120, 0),
                          child: child,
                        ),
                        child: _Avatar(photoUrl: widget.theirPhotoUrl, offset: 56),
                      ),
                      // Heart badge
                      ScaleTransition(
                        scale: _heartScale,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.goldGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.goldMedium.withOpacity(0.6),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.favorite_rounded,
                              color: Colors.black, size: 26),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ─── Title ───
                FadeTransition(
                  opacity: _titleFade,
                  child: ScaleTransition(
                    scale: _titleScale,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.goldGradient.createShader(bounds),
                          child: const Text(
                            "It's a Match!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You and ${widget.theirName} liked each other.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // ─── CTA Buttons ───
                FadeTransition(
                  opacity: _titleFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatConversationPage(
                                    otherUserId: widget.theirUserId,
                                    otherUserName: widget.theirName,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                            label: const Text('Start Chatting'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.goldMedium,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Maybe Later',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar circle ────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String photoUrl;
  final double offset;

  const _Avatar({required this.photoUrl, required this.offset});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offset, 0),
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.goldMedium, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldMedium.withOpacity(0.25),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipOval(
          child: photoUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFF1A1A1A)),
                  errorWidget: (_, __, ___) => _noPhoto(),
                )
              : _noPhoto(),
        ),
      ),
    );
  }

  Widget _noPhoto() => Container(
        color: const Color(0xFF1A1A1A),
        child: const Icon(Icons.person, color: Colors.white24, size: 50),
      );
}

// ─── Simple gold particle painter ────────────────────────────────────────────

class _GoldParticles extends StatefulWidget {
  const _GoldParticles();

  @override
  State<_GoldParticles> createState() => _GoldParticlesState();
}

class _GoldParticlesState extends State<_GoldParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _ParticlePainter(_ctrl.value),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double t;

  static final _rng = math.Random(42);
  static final List<_Particle> _particles = List.generate(
    40,
    (_) => _Particle(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      size: _rng.nextDouble() * 6 + 2,
      speed: _rng.nextDouble() * 0.3 + 0.1,
      opacity: _rng.nextDouble() * 0.6 + 0.2,
    ),
  );

  _ParticlePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _particles) {
      final dy = (p.y - p.speed * t) % 1.0;
      final opacity = (p.opacity * (1 - ((dy - 0.5).abs() * 2))).clamp(0.0, 1.0);
      paint.color = AppColors.goldMedium.withOpacity(opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, dy * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

class _Particle {
  final double x, y, size, speed, opacity;
  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}
