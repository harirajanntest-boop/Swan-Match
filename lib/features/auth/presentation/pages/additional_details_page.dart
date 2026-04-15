import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/registration_draft_service.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'partner_preferences_page.dart';

class AdditionalDetailsPage extends StatefulWidget {
  const AdditionalDetailsPage({super.key});

  @override
  State<AdditionalDetailsPage> createState() => _AdditionalDetailsPageState();
}

class _AdditionalDetailsPageState extends State<AdditionalDetailsPage>
    with SingleTickerProviderStateMixin {
  // ─── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ─── Form State ────────────────────────────────────────────────────────────
  String _familyStatus = 'Middle class';
  final TextEditingController _bioController = TextEditingController();
  final FocusNode _bioFocus = FocusNode();

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
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    UserService.instance.getCurrentUserProfile().then((profile) {
      if (!mounted || profile == null) return;
      final aboutMe = (profile['aboutMe'] ?? '').toString();
      if (aboutMe.trim().isNotEmpty) {
        _bioController.text = aboutMe;
      }
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _bioController.dispose();
    _bioFocus.dispose();
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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.goldMedium,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Additional Details (5/5)",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'serif',
            letterSpacing: 1,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.language,
              color: AppColors.goldMedium,
              size: 20,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Progress Bar (100% Complete!) ───
          Container(
            height: 2,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.05),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 1.0, // 100% complete
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldMedium.withValues(alpha: 0.8),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Family Status ───
                      const _SectionTitle(title: "Select family status"),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _AnimatedPill(
                            label: "Middle class",
                            selectedValue: _familyStatus,
                            onTap: (v) => setState(() => _familyStatus = v),
                          ),
                          _AnimatedPill(
                            label: "Upper middle class",
                            selectedValue: _familyStatus,
                            onTap: (v) => setState(() => _familyStatus = v),
                          ),
                          _AnimatedPill(
                            label: "Rich / Affluent (Elite)",
                            selectedValue: _familyStatus,
                            onTap: (v) => setState(() => _familyStatus = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ─── Bio Text Area ───
                      const _SectionTitle(title: "A few words about myself"),
                      _PremiumTextArea(
                        controller: _bioController,
                        focusNode: _bioFocus,
                        hint:
                            "Write about your personality, hobbies, and what you are looking for in a partner...",
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Minimum 50 characters",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                      const SizedBox(height: 60),

                      // ─── Finish Button ───
                      GoldGradientButton(
                        text: "COMPLETE REGISTRATION",
                        onPressed: () async {
                          await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
                            'familyStatus': _familyStatus,
                            'aboutMe': _bioController.text.trim(),
                            'registrationCompleted': true,
                          });

                          RegistrationDraftService.instance.clear();

                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PartnerPreferencesPage(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // ─── Footer Support ───
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Need help? Call ",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            const Icon(
                              Icons.phone,
                              color: AppColors.goldMedium,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              "8144-99-88-77",
                              style: TextStyle(
                                color: AppColors.goldMedium,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
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

// ─── Reusable UI Components ──────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AnimatedPill extends StatelessWidget {
  final String label;
  final String selectedValue;
  final Function(String) onTap;

  const _AnimatedPill({
    required this.label,
    required this.selectedValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isSelected = label == selectedValue;
    return GestureDetector(
      onTap: () => onTap(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSelected ? AppColors.goldGradient : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.goldDark.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _PremiumTextArea extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  const _PremiumTextArea({
    required this.controller,
    required this.focusNode,
    required this.hint,
  });

  @override
  State<_PremiumTextArea> createState() => _PremiumTextAreaState();
}

class _PremiumTextAreaState extends State<_PremiumTextArea> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFocused
              ? AppColors.goldMedium
              : Colors.white.withValues(alpha: 0.15),
          width: _isFocused ? 1.5 : 1.0,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppColors.goldMedium.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        maxLines: 6,
        minLines: 4,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        cursorColor: AppColors.goldMedium,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
