import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/colors.dart';
import 'chat_conversation_page.dart';

/// Calmer, single-sided counterpart to `ItsAMatchOverlay`: shown after the
/// current user accepts a received connection request's video response (as
/// opposed to a mutual swipe-like). Same dark + gold tone, simpler content —
/// no sparkle canvas, no "It's a Match!" copy.
class ConnectionAcceptedPage extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhotoUrl;

  const ConnectionAcceptedPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl = '',
  });

  @override
  State<ConnectionAcceptedPage> createState() => _ConnectionAcceptedPageState();
}

class _ConnectionAcceptedPageState extends State<ConnectionAcceptedPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startChatting() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationPage(
          otherUserId: widget.otherUserId,
          otherUserName: widget.otherUserName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _GoldAmbientBackground(),
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
                      _buildAvatar(),
                      const SizedBox(height: 36),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.goldGradient.createShader(bounds),
                        child: Text(
                          "You're connected",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 40,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.1,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Start your conversation with ${widget.otherUserName}.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 17,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(flex: 3),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.goldMedium.withOpacity(0.45),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _startChatting,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            child: const Text('Start Chatting'),
                          ),
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

  Widget _buildAvatar() {
    const size = 148.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.goldGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.goldMedium.withOpacity(0.5),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3.5),
      child: DecoratedBox(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
        child: ClipOval(
          child: widget.otherUserPhotoUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: widget.otherUserPhotoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _avatarPlaceholder(size),
                  errorWidget: (_, __, ___) => _avatarPlaceholder(size),
                )
              : _avatarPlaceholder(size),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(double size) => Container(
        color: const Color(0xFF1A1A1A),
        child: Icon(
          Icons.person,
          color: AppColors.goldMedium.withOpacity(0.5),
          size: size * 0.42,
        ),
      );
}

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
                  AppColors.goldMedium.withOpacity(0.22),
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
                    AppColors.goldMedium.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.goldDark.withOpacity(0.08),
                Colors.transparent,
                AppColors.goldDark.withOpacity(0.06),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
