import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'location_details_page.dart';

class ReligiousDetailsPage extends StatefulWidget {
  const ReligiousDetailsPage({super.key});

  @override
  State<ReligiousDetailsPage> createState() => _ReligiousDetailsPageState();
}

class _ReligiousDetailsPageState extends State<ReligiousDetailsPage>
    with SingleTickerProviderStateMixin {
  // ─── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ─── Form State ────────────────────────────────────────────────────────────
  String? _selectedReligion;
  String? _selectedCaste;
  final TextEditingController _subcasteController = TextEditingController();
  bool _anyCaste = false;
  String? _dosham;

  // ─── Mock Data ─────────────────────────────────────────────────────────────
  final List<String> _religions = [
    'Hindu',
    'Muslim',
    'Christian',
    'Sikh',
    'Jain',
    'Buddhist',
    'Other',
  ];
  final List<String> _castes = [
    'Vaniya Chettiar',
    'Iyer',
    'Iyengar',
    'Mudaliar',
    'Pillai',
    'Nadar',
    'Other',
  ];

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
    _subcasteController.dispose();
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
          "Religious Details (2/5)",
          style: TextStyle(
            color: Colors.white,
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
          // ─── Progress Bar (Advanced to 40%) ───
          Container(
            height: 2,
            width: double.infinity,
            color: Colors.white.withOpacity(0.05),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.40, // 2 out of 5 steps
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
                      // ─── Religion Dropdown ───
                      const _SectionTitle(title: "Religion"),
                      _PremiumDropdown(
                        hint: "Select religion",
                        value: _selectedReligion,
                        items: _religions,
                        onChanged: (v) => setState(() {
                          _selectedReligion = v;
                          _selectedCaste =
                              null; // Reset caste when religion changes
                        }),
                      ),

                      const SizedBox(height: 20),

                      // ─── Dynamic Fields (Reveal when Religion is selected) ───
                      AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        child: _selectedReligion == null
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ─── Caste ───
                                  const _SectionTitle(title: "Caste"),
                                  _PremiumDropdown(
                                    hint: "Select caste",
                                    value: _selectedCaste,
                                    items: _castes,
                                    onChanged: (v) =>
                                        setState(() => _selectedCaste = v),
                                  ),
                                  const SizedBox(height: 16),

                                  // ─── Subcaste Input ───
                                  _PremiumTextInput(
                                    hint: "Enter subcaste (Optional)",
                                    controller: _subcasteController,
                                  ),
                                  const SizedBox(height: 16),

                                  // ─── Any Caste Checkbox ───
                                  _PremiumCheckbox(
                                    label: "Willing to marry from any caste",
                                    value: _anyCaste,
                                    onChanged: (v) =>
                                        setState(() => _anyCaste = v),
                                  ),
                                  const SizedBox(height: 32),

                                  // ─── Dosham ───
                                  Row(
                                    children: [
                                      const _SectionTitle(
                                        title: "Do you have any dosham? ",
                                      ),
                                      Text(
                                        "(Optional)",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _AnimatedPill(
                                          label: "No",
                                          selectedValue: _dosham,
                                          onTap: (v) =>
                                              setState(() => _dosham = v),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _AnimatedPill(
                                          label: "Yes",
                                          selectedValue: _dosham,
                                          onTap: (v) =>
                                              setState(() => _dosham = v),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _AnimatedPill(
                                          label: "Don't know",
                                          selectedValue: _dosham,
                                          onTap: (v) =>
                                              setState(() => _dosham = v),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                      ),

                      // ─── Next Button ───
                      GoldGradientButton(
                        text: "NEXT",
                        onPressed: () async {
                          await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
                            'religion': _selectedReligion ?? '',
                            'caste': _selectedCaste ?? '',
                            'subCaste': _subcasteController.text.trim(),
                            'anyCaste': _anyCaste,
                            'dosham': _dosham ?? '',
                          });

                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LocationDetailsPage(),
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
                                color: Colors.white.withOpacity(0.5),
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
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PremiumDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;

  const _PremiumDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.goldMedium,
            size: 18,
          ),
          dropdownColor: AppColors.onyx,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(item),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PremiumTextInput extends StatelessWidget {
  final String hint;
  final TextEditingController controller;

  const _PremiumTextInput({required this.hint, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: AppColors.goldMedium,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PremiumCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final Function(bool) onChanged;

  const _PremiumCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.goldMedium
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value
                    ? AppColors.goldMedium
                    : Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: AppColors.goldMedium.withOpacity(0.4),
                        blurRadius: 4,
                      ),
                    ]
                  : [],
            ),
            child: value
                ? const Icon(Icons.check, color: AppColors.obsidian, size: 16)
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
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
                    color: AppColors.goldDark.withOpacity(0.3),
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
            color: isSelected ? Colors.black : Colors.white.withOpacity(0.8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
