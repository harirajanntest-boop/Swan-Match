import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import 'chat_conversation_page.dart';

/// Full-screen "It's a Match!" celebration overlay.
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

  static Future<void> show(
    BuildContext context, {
    required String myPhotoUrl,
    required String theirPhotoUrl,
    required String theirName,
    required String theirUserId,
  }) {
    final navigator = Navigator.of(context, rootNavigator: true);
    return navigator.push<void>(_matchRoute(
      myPhotoUrl: myPhotoUrl,
      theirPhotoUrl: theirPhotoUrl,
      theirName: theirName,
      theirUserId: theirUserId,
    ));
  }

  /// Shows the match screen immediately; loads any missing photos in the background.
  static Future<void> showAfterAccept({
    required NavigatorState navigator,
    required String otherUserId,
    required String theirName,
    String theirPhotoUrl = '',
  }) {
    return navigator.push<void>(_matchRoute(
      myPhotoUrl: '',
      theirPhotoUrl: theirPhotoUrl,
      theirName: theirName,
      theirUserId: otherUserId,
    ));
  }

  static PageRouteBuilder<void> _matchRoute({
    required String myPhotoUrl,
    required String theirPhotoUrl,
    required String theirName,
    required String theirUserId,
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => ItsAMatchOverlay(
        myPhotoUrl: myPhotoUrl,
        theirPhotoUrl: theirPhotoUrl,
        theirName: theirName,
        theirUserId: theirUserId,
      ),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  static String photoFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return '';
    final photos = profile['photos'];
    if (photos is List && photos.isNotEmpty) {
      return photos.first.toString();
    }
    return (profile['profilePicture'] ?? profile['photoUrl'] ?? '').toString();
  }

  @override
  State<ItsAMatchOverlay> createState() => _ItsAMatchOverlayState();
}

class _ItsAMatchOverlayState extends State<ItsAMatchOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _shimmerController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  String _myPhotoUrl = '';
  String _theirPhotoUrl = '';

  @override
  void initState() {
    super.initState();
    _myPhotoUrl = widget.myPhotoUrl;
    _theirPhotoUrl = widget.theirPhotoUrl;

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fade = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    _entryController.forward();
    _loadMissingPhotos();
  }

  Future<void> _loadMissingPhotos() async {
    var changed = false;
    if (_myPhotoUrl.isEmpty) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        final profile = await UserService.instance.getUserProfile(uid);
        final url = ItsAMatchOverlay.photoFromProfile(profile);
        if (url.isNotEmpty && mounted) {
          _myPhotoUrl = url;
          changed = true;
        }
      }
    }
    if (_theirPhotoUrl.isEmpty) {
      final profile =
          await UserService.instance.getUserProfile(widget.theirUserId);
      final url = ItsAMatchOverlay.photoFromProfile(profile);
      if (url.isNotEmpty && mounted) {
        _theirPhotoUrl = url;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _entryController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── Layered gold background ───
          const _GoldAmbientBackground(),
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (_, __) => CustomPaint(
              painter: _GoldSparklePainter(_shimmerController.value),
              size: Size.infinite,
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // ─── Title (app gold gradient) ───
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.goldGradient.createShader(bounds),
                        child: Text(
                          "It's a Match!",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 46,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.05,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ─── Overlapping avatars (~10% cross) ───
                      _OverlappingMatchAvatars(
                        myPhotoUrl: _myPhotoUrl,
                        theirPhotoUrl: _theirPhotoUrl,
                      ),

                      const SizedBox(height: 36),

                      Text(
                        'You and ${widget.theirName} liked each other.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 20,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.15,
                        ),
                      ),

                      const Spacer(flex: 3),

                      // ─── Send a Message (gold gradient) ───
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.goldMedium.withValues(alpha: 0.45),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            child: const Text('Send a Message'),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ─── Keep Discovering (gold outline) ───
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.goldLight,
                            side: const BorderSide(
                              color: AppColors.goldMedium,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          child: const Text('Keep Discovering'),
                        ),
                      ),

                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

/// Two profile circles with ~10% horizontal overlap, centered as a pair.
class _OverlappingMatchAvatars extends StatelessWidget {
  final String myPhotoUrl;
  final String theirPhotoUrl;

  static const double _avatarSize = 148;
  static const double _overlapFraction = 0.10;

  const _OverlappingMatchAvatars({
    required this.myPhotoUrl,
    required this.theirPhotoUrl,
  });

  double get _overlap => _avatarSize * _overlapFraction;

  double get _pairWidth => _avatarSize * 2 - _overlap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _avatarSize + 24,
      width: _pairWidth + 48,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: _pairWidth + 40,
            height: _pairWidth + 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.goldMedium.withValues(alpha: 0.55),
                  AppColors.goldDark.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          ..._sparkleIcons(),
          SizedBox(
            width: _pairWidth,
            height: _avatarSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  child: _MatchAvatar(
                    photoUrl: myPhotoUrl,
                    size: _avatarSize,
                  ),
                ),
                Positioned(
                  left: _avatarSize - _overlap,
                  child: _MatchAvatar(
                    photoUrl: theirPhotoUrl,
                    size: _avatarSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sparkleIcons() {
    const positions = [
      Offset(-108, -20),
      Offset(108, -28),
      Offset(-82, 44),
      Offset(92, 38),
      Offset(0, -58),
    ];
    return List.generate(positions.length, (i) {
      return Positioned(
        left: (_pairWidth + 48) / 2 + positions[i].dx,
        top: (_avatarSize + 24) / 2 + positions[i].dy,
        child: Icon(
          Icons.star_rounded,
          size: i.isEven ? 12 : 8,
          color: AppColors.goldLight.withValues(alpha: 0.5 + (i * 0.06)),
        ),
      );
    });
  }
}

// ─── Ambient gold wash behind content ────────────────────────────────────────

class _GoldAmbientBackground extends StatelessWidget {
  const _GoldAmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        Positioned(
          top: -80,
          left: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.goldMedium.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 120,
          right: -80,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.goldDark.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 320,
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.goldMedium.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        // Subtle vertical gold vignette
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.goldDark.withValues(alpha: 0.08),
                Colors.transparent,
                AppColors.goldDark.withValues(alpha: 0.06),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Floating gold particles ─────────────────────────────────────────────────

class _GoldSparklePainter extends CustomPainter {
  final double t;
  _GoldSparklePainter(this.t);

  static final _rng = math.Random(17);
  static final List<_Sparkle> _dots = List.generate(36, (i) {
    return _Sparkle(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      size: _rng.nextDouble() * 4 + 1.5,
      speed: _rng.nextDouble() * 0.25 + 0.08,
      phase: _rng.nextDouble() * math.pi * 2,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < _dots.length; i++) {
      final p = _dots[i];
      final dy = (p.y - p.speed * t) % 1.0;
      final twinkle = (math.sin(t * math.pi * 2 + p.phase) + 1) / 2;
      final opacity = (0.15 + twinkle * 0.45).clamp(0.0, 1.0);
      paint.color = (i.isEven ? AppColors.goldLight : AppColors.goldMedium)
          .withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, dy * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GoldSparklePainter old) => old.t != t;
}

class _Sparkle {
  final double x, y, size, speed, phase;
  const _Sparkle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
  });
}

// ─── Profile avatar ────────────────────────────────────────────────────────────

class _MatchAvatar extends StatelessWidget {
  final String photoUrl;
  final double size;

  const _MatchAvatar({
    required this.photoUrl,
    this.size = 148,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.goldGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.goldMedium.withValues(alpha: 0.5),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3.5),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
        ),
        child: ClipOval(
          child: photoUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _placeholder(),
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF1A1A1A),
        child: Icon(
          Icons.person,
          color: AppColors.goldMedium.withValues(alpha: 0.5),
          size: size * 0.42,
        ),
      );
}
