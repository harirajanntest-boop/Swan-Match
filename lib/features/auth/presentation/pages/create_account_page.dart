import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/registration_draft_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'basic_details_page.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage>
    with SingleTickerProviderStateMixin {
  // ─── Form State ────────────────────────────────────────────────────────────
  String _selectedFor = 'Myself'; // Default selection
  String _selectedLanguage = 'Tamil';

  final List<String> _profileForOptions = [
    'Myself',
    'Son',
    'Daughter',
    'Brother',
    'Sister',
    'Friend',
    'Relative',
  ];

  final List<String> _languages = [
    'Tamil',
    'English',
    'Telugu',
    'Malayalam',
    'Hindi',
    'Kannada',
  ];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
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
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Create Profile",
          style: TextStyle(
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        actions: [
          // Premium Language Toggle Icon
          IconButton(
            icon: const Icon(Icons.language, color: AppColors.goldMedium),
            onPressed: () {},
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            // ─── Elegant Progress Bar ───
            Container(
              height: 2,
              width: double.infinity,
              color: Colors.white.withOpacity(0.05),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.15, // 15% complete (Step 1)
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldMedium.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Header Section ───
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.goldMedium.withOpacity(0.5),
                            width: 1,
                          ),
                          color: Colors.white.withOpacity(0.02),
                        ),
                        child: const Icon(
                          Icons.favorite_border,
                          color: AppColors.goldMedium,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        "Welcome to Swan Match!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ─── Profile For Section ───
                    Text(
                      "I am creating this profile for",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Animated Wrap for selectable pills
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _profileForOptions.map((option) {
                        final isSelected = _selectedFor == option;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedFor = option),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: isSelected
                                  ? AppColors.goldGradient
                                  : null,
                              color: isSelected
                                  ? null
                                  : Colors.white.withOpacity(0.03),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : Colors.white.withOpacity(0.1),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.goldDark.withOpacity(
                                          0.3,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.black
                                    : Colors.white.withOpacity(0.7),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 40),

                    // ─── Mother Tongue Section ───
                    Text(
                      "Mother tongue",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Premium Dropdown Alternative
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          isExpanded: true,
                          dropdownColor: AppColors.onyx,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.goldMedium,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                          items: _languages.map((String lang) {
                            return DropdownMenuItem<String>(
                              value: lang,
                              child: Text(lang),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() => _selectedLanguage = newValue);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // ─── Action Button ───
                    GoldGradientButton(
                      text: "START REGISTRATION",
                      onPressed: () {
                        RegistrationDraftService.instance
                            .setValues(<String, dynamic>{
                              'profileFor': _selectedFor,
                              'motherTongue': _selectedLanguage,
                            });

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BasicDetailsPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
