import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'professional_details_page.dart';

class LocationDetailsPage extends StatefulWidget {
  const LocationDetailsPage({super.key});

  @override
  State<LocationDetailsPage> createState() => _LocationDetailsPageState();
}

class _LocationDetailsPageState extends State<LocationDetailsPage>
    with SingleTickerProviderStateMixin {
  // ─── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ─── Form State ────────────────────────────────────────────────────────────
  String? _selectedCountry = 'India'; // Defaulting based on your screenshot
  String? _selectedState;
  String? _selectedCity;

  // ─── Mock Data ─────────────────────────────────────────────────────────────
  final List<String> _countries = [
    'India',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'UAE',
    'Singapore',
    'Malaysia',
  ];

  // In a real app, these would load from an API based on the selected country
  final List<String> _statesInIndia = [
    'Tamil Nadu',
    'Kerala',
    'Karnataka',
    'Andhra Pradesh',
    'Telangana',
    'Maharashtra',
    'Delhi',
  ];

  // In a real app, these would load based on the selected state
  final List<String> _citiesInTN = [
    'Chennai',
    'Coimbatore',
    'Madurai',
    'Salem',
    'Tiruchirappalli',
    'Tirunelveli',
    'Erode',
    'Vellore',
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic lists based on selection (Mock logic for UI demo)
    List<String> currentStates = _selectedCountry == 'India'
        ? _statesInIndia
        : [];
    List<String> currentCities = _selectedState == 'Tamil Nadu'
        ? _citiesInTN
        : [];

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
          "Location Details (3/5)",
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
          // ─── Progress Bar (Advanced to 60%) ───
          Container(
            height: 2,
            width: double.infinity,
            color: Colors.white.withOpacity(0.05),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.60,
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
                      // ─── Country ───
                      const _SectionTitle(title: "Your residing country"),
                      _PremiumDropdown(
                        hint: "Select Country",
                        value: _selectedCountry,
                        items: _countries,
                        onChanged: (v) {
                          setState(() {
                            _selectedCountry = v;
                            _selectedState =
                                null; // Reset state when country changes
                            _selectedCity =
                                null; // Reset city when country changes
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // ─── State ───
                      const _SectionTitle(title: "Your residing state"),
                      _PremiumDropdown(
                        hint: _selectedCountry == null
                            ? "Select Country first"
                            : "Select State",
                        value: _selectedState,
                        items: currentStates,
                        onChanged: (v) {
                          setState(() {
                            _selectedState = v;
                            _selectedCity =
                                null; // Reset city when state changes
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // ─── City ───
                      const _SectionTitle(title: "Your residing city"),
                      _PremiumDropdown(
                        hint: _selectedState == null
                            ? "Select State first"
                            : "Select City",
                        value: _selectedCity,
                        items: currentCities,
                        onChanged: (v) => setState(() => _selectedCity = v),
                      ),
                      const SizedBox(height: 48),

                      // ─── Next Button ───
                      GoldGradientButton(
                        text: "NEXT",
                        onPressed: () async {
                          await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
                            'country': _selectedCountry ?? '',
                            'state': _selectedState ?? '',
                            'city': _selectedCity ?? '',
                          });

                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ProfessionalDetailsPage(),
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
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
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
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
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
