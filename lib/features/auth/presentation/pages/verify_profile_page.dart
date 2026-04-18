import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/colors.dart';
import 'subscription_page.dart';

class VerifyProfilePage extends StatefulWidget {
  const VerifyProfilePage({super.key});

  @override
  State<VerifyProfilePage> createState() => _VerifyProfilePageState();
}

class _VerifyProfilePageState extends State<VerifyProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
      ),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open phone dialer.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.goldMedium,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Trust & Safety",
          style: TextStyle(
            color: Colors.white,
            letterSpacing: 1,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ─── Glowing Premium Shield Icon ───
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Ambient Glow
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.goldMedium.withOpacity(0.15),
                                  blurRadius: 50,
                                  spreadRadius: 15,
                                ),
                              ],
                            ),
                          ),
                          // Frosted Glass Ring
                          ClipRRect(
                            borderRadius: BorderRadius.circular(75),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 10,
                                sigmaY: 10,
                              ),
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.05),
                                  border: Border.all(
                                    color:
                                        AppColors.goldMedium.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.verified_user_outlined,
                                    color: AppColors.goldLight,
                                    size: 60,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Green checkmark badge
                          Positioned(
                            bottom: 10,
                            right: 15,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.obsidian,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.obsidian,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.greenAccent,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // ─── Title & Description ───
                      const Text(
                        "Verify your profile",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Verified profiles receive 3x more matches. Choose a verification option below.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ─── SECTION LABEL ───
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.goldMedium,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Verification Options",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ─── OPTION 1 : Subscribe to get Verified Badge ───
                      _SubscriptionVerifyCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionPage(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ─── Footer Support Area ───
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Need Help? Call us: ",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                        const Icon(
                          Icons.phone,
                          color: AppColors.goldMedium,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _makeCall("+919962043543"),
                          child: const Text(
                            "91-9962043543",
                            style: TextStyle(
                              color: AppColors.goldLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Working hours (8 AM - 8 PM IST)",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Subscription Verify Card ─────────────────────────────────────────────────
class _SubscriptionVerifyCard extends StatelessWidget {
  final VoidCallback onTap;

  const _SubscriptionVerifyCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              AppColors.goldDark.withOpacity(0.85),
              const Color(0xFF8B6914),
              AppColors.goldMedium.withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldMedium.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: Badge + label ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Get Verified Badge",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Subscribe to a premium plan",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Verified badge chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          "Badge",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Perks row ──
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _PerkChip(label: "✓  Verified badge on profile"),
                  _PerkChip(label: "✓  3× more matches"),
                  _PerkChip(label: "✓  Priority in search"),
                  _PerkChip(label: "✓  Access premium features"),
                ],
              ),

              const SizedBox(height: 20),

              // ── CTA button ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.55),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(
                        color: Colors.white54,
                        width: 1,
                      ),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, size: 18),
                      SizedBox(width: 8),
                      Text("View Subscription Plans"),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios, size: 13),
                    ],
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

class _PerkChip extends StatelessWidget {
  final String label;
  const _PerkChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}