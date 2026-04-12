import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'subscription_page.dart';

class LifestyleDetailsPage extends StatefulWidget {
  const LifestyleDetailsPage({super.key});

  @override
  State<LifestyleDetailsPage> createState() => _LifestyleDetailsPageState();
}

class _LifestyleDetailsPageState extends State<LifestyleDetailsPage>
    with SingleTickerProviderStateMixin {
  // ─── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ─── Form State ────────────────────────────────────────────────────────────
  String? _selectedDiet;
  String? _selectedSmoking;
  String? _selectedDrinking;

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
    final canSubmit =
        (_selectedDiet?.isNotEmpty == true) ||
        (_selectedSmoking?.isNotEmpty == true) ||
        (_selectedDrinking?.isNotEmpty == true);

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
          "Lifestyle Habits",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'serif',
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
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.center, // Centered layout
                    children: [
                      // ─── Premium Icon Header ───
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.03),
                          border: Border.all(
                            color: AppColors.goldMedium.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldMedium.withOpacity(0.05),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          color: AppColors.goldMedium,
                          size: 50,
                        ),
                      ),
                      const SizedBox(height: 32),

                      const Text(
                        "Select eating habit",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontFamily: 'serif',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── Eating Habits ───
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _AnimatedPill(
                            label: "Vegetarian",
                            selectedValue: _selectedDiet,
                            onTap: (v) => setState(() => _selectedDiet = v),
                          ),
                          _AnimatedPill(
                            label: "Non-Vegetarian",
                            selectedValue: _selectedDiet,
                            onTap: (v) => setState(() => _selectedDiet = v),
                          ),
                          _AnimatedPill(
                            label: "Eggetarian",
                            selectedValue: _selectedDiet,
                            onTap: (v) => setState(() => _selectedDiet = v),
                          ),
                          _AnimatedPill(
                            label: "Vegan",
                            selectedValue: _selectedDiet,
                            onTap: (v) => setState(() => _selectedDiet = v),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),
                      Container(
                        height: 1,
                        width: 100,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      const SizedBox(height: 48),

                      // ─── Smoking Habits ───
                      const Text(
                        "Smoking habit",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'serif',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _AnimatedPill(
                            label: "No",
                            selectedValue: _selectedSmoking,
                            onTap: (v) => setState(() => _selectedSmoking = v),
                          ),
                          _AnimatedPill(
                            label: "Occasionally",
                            selectedValue: _selectedSmoking,
                            onTap: (v) => setState(() => _selectedSmoking = v),
                          ),
                          _AnimatedPill(
                            label: "Yes",
                            selectedValue: _selectedSmoking,
                            onTap: (v) => setState(() => _selectedSmoking = v),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),

                      // ─── Drinking Habits ───
                      const Text(
                        "Drinking habit",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'serif',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _AnimatedPill(
                            label: "No",
                            selectedValue: _selectedDrinking,
                            onTap: (v) => setState(() => _selectedDrinking = v),
                          ),
                          _AnimatedPill(
                            label: "Occasionally",
                            selectedValue: _selectedDrinking,
                            onTap: (v) => setState(() => _selectedDrinking = v),
                          ),
                          _AnimatedPill(
                            label: "Yes",
                            selectedValue: _selectedDrinking,
                            onTap: (v) => setState(() => _selectedDrinking = v),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // ─── Bottom Sticky Action Area ───
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.obsidian,
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GoldGradientButton(
                        text: "SUBMIT",
                        enabled: canSubmit,
                        onPressed: () async {
                          if (!canSubmit) return;
                          await UserService.instance.updateLifestyle(
                            eatingHabits: _selectedDiet ?? '',
                            smokingHabits: _selectedSmoking ?? '',
                            drinkingHabits: _selectedDrinking ?? '',
                          );

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lifestyle habits saved.')),
                          );

                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SubscriptionPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SubscriptionPage(),
                            ),
                          );
                        },
                        child: Text(
                          "I will do this later",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
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

// ─── Reusable Animated Pill ──────────────────────────────────────────────────
class _AnimatedPill extends StatelessWidget {
  final String label;
  final String? selectedValue;
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: isSelected ? AppColors.goldGradient : null,
          color: isSelected ? null : Colors.white.withOpacity(0.03),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.goldDark.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white.withOpacity(0.85),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
