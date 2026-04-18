import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
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
  String _selectedCountry = '';
  String _selectedState = '';
  String _selectedCity = '';


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

    _loadSavedLocationData();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryController.forward();
    });
  }

  Future<void> _loadSavedLocationData() async {
    try {
      final profile = await UserService.instance.getCurrentUserProfile();
      if (!mounted) return;

      setState(() {
        _selectedCountry = (profile?['country'] ?? '').toString().trim();
        _selectedState = (profile?['state'] ?? '').toString().trim();
        _selectedCity = (profile?['city'] ?? '').toString().trim();
      });
    } catch (_) {
      if (!mounted) return;
    }
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
                      // ─── Location Picker ───
                      // Country picker button
                      GestureDetector(
                        onTap: () {
                          showCountryPicker(
                            context: context,
                            showPhoneCode: false,
                            onSelect: (Country country) {
                              setState(() {
                                _selectedCountry = country.name;
                                _selectedState = '';
                                _selectedCity = '';
                              });
                            },
                            countryListTheme: CountryListThemeData(
                              backgroundColor: const Color(0xFF1A1A1A),
                              textStyle: const TextStyle(color: Colors.white, fontSize: 14),
                              searchTextStyle: const TextStyle(color: Colors.white),
                              inputDecoration: InputDecoration(
                                hintText: 'Search country...',
                                hintStyle: const TextStyle(color: Colors.white38),
                                prefixIcon: const Icon(Icons.search, color: Color(0xFFD4A017)),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Color(0xFFD4A017)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Color(0xFFD4A017), width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(bottom: const BorderSide(color: Color(0xFFD4A017))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedCountry.isEmpty ? 'Select Country' : _selectedCountry,
                                style: TextStyle(
                                  color: _selectedCountry.isEmpty ? Colors.white38 : Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Color(0xFFD4A017)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // State TextField (manual input after country selected)
                      TextField(
                        enabled: _selectedCountry.isNotEmpty,
                        onChanged: (v) => setState(() => _selectedState = v),
                        style: const TextStyle(color: Colors.white),
                        cursorColor: const Color(0xFFD4A017),
                        decoration: InputDecoration(
                          labelText: 'State / Province',
                          labelStyle: const TextStyle(color: Colors.white54),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFD4A017)),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFD4A017), width: 2),
                          ),
                          disabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // City TextField
                      TextField(
                        enabled: _selectedState.isNotEmpty,
                        onChanged: (v) => setState(() => _selectedCity = v),
                        style: const TextStyle(color: Colors.white),
                        cursorColor: const Color(0xFFD4A017),
                        decoration: InputDecoration(
                          labelText: 'City / Town',
                          labelStyle: const TextStyle(color: Colors.white54),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFD4A017)),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFD4A017), width: 2),
                          ),
                          disabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // ─── Next Button ───
                      GoldGradientButton(
                        text: "NEXT",
                        onPressed: () async {
                          try {
                            await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
                              'country': _selectedCountry,
                              'state': _selectedState,
                              'city': _selectedCity,
                            });

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Location details saved.')),
                            );
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to save location details.')),
                            );
                            return;
                          }

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
  final bool enabled;

  const _PremiumDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        constraints: const BoxConstraints(minHeight: 55),
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A1A),
          iconEnabledColor: AppColors.goldMedium,
          iconDisabledColor: Colors.white54,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            labelText: hint,
            labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
            floatingLabelStyle: const TextStyle(
              color: AppColors.goldMedium,
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.goldMedium,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.goldMedium,
                width: 2.0,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.25),
                width: 1.2,
              ),
            ),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
