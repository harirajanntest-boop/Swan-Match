import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class VerifyProfilePage extends StatefulWidget {
  const VerifyProfilePage({super.key});

  @override
  State<VerifyProfilePage> createState() => _VerifyProfilePageState();
}

class _VerifyProfilePageState extends State<VerifyProfilePage> with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.1, 1.0, curve: Curves.easeOut)));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)));

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.goldMedium, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Trust & Safety",
          style: TextStyle(color: Colors.white, fontFamily: 'serif', letterSpacing: 1, fontSize: 18),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
                              boxShadow: [BoxShadow(color: AppColors.goldMedium.withOpacity(0.15), blurRadius: 50, spreadRadius: 15)],
                            ),
                          ),
                          // Frosted Glass Ring
                          ClipRRect(
                            borderRadius: BorderRadius.circular(75),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.05),
                                  border: Border.all(color: AppColors.goldMedium.withOpacity(0.3), width: 1.5),
                                ),
                                child: const Center(
                                  child: Icon(Icons.verified_user_outlined, color: AppColors.goldLight, size: 60),
                                ),
                              ),
                            ),
                          ),
                          // Green checkmark badge to match screenshot
                          Positioned(
                            bottom: 10,
                            right: 15,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.obsidian,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.obsidian, width: 2),
                              ),
                              child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // ─── Title & Description ───
                      const Text(
                        "Verify your profile",
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Verified profiles receive 3x more matches. Please verify your identity using the option below.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.5),
                      ),
                      
                      const SizedBox(height: 48),

                      // ─── Verification Action Card ───
                      GestureDetector(
                        onTap: () {
                          // Trigger phone dialer to call +91 9994363922
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.goldMedium.withOpacity(0.4), width: 1.2),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Row(
                                children: [
                                  // Icon Box
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.goldMedium.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.phone_in_talk, color: AppColors.goldMedium, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Texts
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Call us to verify",
                                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 6),
                                        RichText(
                                          text: TextSpan(
                                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.4),
                                            children: const [
                                              TextSpan(text: "Call "),
                                              TextSpan(text: "+91 9994363922", style: TextStyle(color: AppColors.goldMedium, fontWeight: FontWeight.bold)),
                                              TextSpan(text: " from your registered number."),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 12),
                                  Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.3), size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // ─── Footer Support Area ───
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Need Help? Call us: ", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                        const Icon(Icons.phone, color: AppColors.goldMedium, size: 14),
                        const SizedBox(width: 4),
                        const Text(
                          "91-9962043543",
                          style: TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Working hours (8 AM - 8 PM IST)",
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
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