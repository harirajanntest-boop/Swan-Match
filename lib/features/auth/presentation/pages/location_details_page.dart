import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:country_state_city/country_state_city.dart' as csc;
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
  String? _selectedCountry;
  String? _selectedCountryCode;
  String? _selectedState;
  String? _selectedStateCode;
  String? _selectedCity;

  List<csc.Country> _countries = const <csc.Country>[];
  List<csc.State> _states = const <csc.State>[];
  List<csc.City> _cities = const <csc.City>[];
  bool _isLoadingCountries = true;
  bool _isLoadingStates = false;
  bool _isLoadingCities = false;

  T? _firstWhereOrNull<T>(Iterable<T> list, bool Function(T item) test) {
    for (final item in list) {
      if (test(item)) return item;
    }
    return null;
  }

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

    _loadCountryStateCityData();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryController.forward();
    });
  }

  Future<void> _loadCountryStateCityData() async {
    try {
      final profile = await UserService.instance.getCurrentUserProfile();
      final countries = await csc.getAllCountries();

      if (!mounted) return;

      final savedCountry = (profile?['country'] ?? '').toString().trim();
      if (countries.isEmpty) {
        if (mounted) {
          setState(() => _isLoadingCountries = false);
        }
        return;
      }

      final defaultCountry = countries.firstWhere(
        (country) => country.name.toLowerCase() == (savedCountry.isEmpty ? 'india' : savedCountry.toLowerCase()),
        orElse: () => countries.first,
      );

      final defaultCountryCode = defaultCountry.isoCode.trim();

      setState(() {
        _countries = countries;
        _selectedCountry = defaultCountry.name;
        _selectedCountryCode = defaultCountryCode;
        _isLoadingCountries = false;
      });

      if (defaultCountryCode.isNotEmpty) {
        await _loadStatesForCountry(
          countryCode: defaultCountryCode,
          preferredState: (profile?['state'] ?? '').toString().trim(),
          preferredCity: (profile?['city'] ?? '').toString().trim(),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingCountries = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load country/state/city list.')),
      );
    }
  }

  Future<void> _loadStatesForCountry({
    required String countryCode,
    String preferredState = '',
    String preferredCity = '',
  }) async {
    setState(() {
      _isLoadingStates = true;
      _states = const <csc.State>[];
      _cities = const <csc.City>[];
      _selectedState = null;
      _selectedStateCode = null;
      _selectedCity = null;
    });

    final states = await csc.getStatesOfCountry(countryCode);
    if (!mounted) return;

    csc.State? selectedState;
    if (preferredState.isNotEmpty) {
      for (final state in states) {
        if (state.name.toLowerCase() == preferredState.toLowerCase()) {
          selectedState = state;
          break;
        }
      }
    }

    setState(() {
      _states = states;
      _selectedState = selectedState?.name;
      _selectedStateCode = selectedState?.isoCode;
      _isLoadingStates = false;
    });

    if (selectedState != null) {
      await _loadCitiesForState(
        countryCode: countryCode,
        stateCode: selectedState.isoCode,
        preferredCity: preferredCity,
      );
    }
  }

  Future<void> _loadCitiesForState({
    required String countryCode,
    required String stateCode,
    String preferredCity = '',
  }) async {
    setState(() {
      _isLoadingCities = true;
      _cities = const <csc.City>[];
      _selectedCity = null;
    });

    final cities = await csc.getStateCities(countryCode, stateCode);
    if (!mounted) return;

    csc.City? selectedCity;
    if (preferredCity.isNotEmpty) {
      for (final city in cities) {
        if (city.name.toLowerCase() == preferredCity.toLowerCase()) {
          selectedCity = city;
          break;
        }
      }
    }

    setState(() {
      _cities = cities;
      _selectedCity = selectedCity?.name;
      _isLoadingCities = false;
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
                        items: _countries
                            .map((country) => country.name.trim())
                          .where((name) => name.isNotEmpty)
                          .toList(),
                        enabled: !_isLoadingCountries,
                        onChanged: (v) async {
                              final selected = _countries
                                  .where((country) => country.name.trim() == v)
                                  .toList();
                                final picked = _firstWhereOrNull(selected, (_) => true);
                                final isoCode = picked?.isoCode.trim() ?? '';
                                if (picked == null || isoCode.isEmpty) return;

                          setState(() {
                            _selectedCountry = picked.name;
                            _selectedCountryCode = isoCode;
                            _selectedState = null;
                            _selectedStateCode = null;
                            _selectedCity = null;
                          });

                          await _loadStatesForCountry(countryCode: isoCode);
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
                        items: _states
                            .map((state) => state.name.trim())
                          .where((name) => name.isNotEmpty)
                          .toList(),
                        enabled: !_isLoadingStates && _selectedCountryCode != null,
                        onChanged: (v) async {
                              final selected = _states
                                  .where((state) => state.name.trim() == v)
                                  .toList();
                                final picked = _firstWhereOrNull(selected, (_) => true);
                                final stateCode = picked?.isoCode.trim() ?? '';
                                if (picked == null || _selectedCountryCode == null || stateCode.isEmpty) return;

                          setState(() {
                            _selectedState = picked.name;
                            _selectedStateCode = stateCode;
                            _selectedCity = null;
                          });

                          await _loadCitiesForState(
                            countryCode: _selectedCountryCode!,
                            stateCode: stateCode,
                          );
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
                        items: _cities
                            .map((city) => city.name.trim())
                          .where((name) => name.isNotEmpty)
                          .toList(),
                        enabled: !_isLoadingCities && _selectedStateCode != null,
                        onChanged: (v) => setState(() => _selectedCity = v),
                      ),
                      const SizedBox(height: 48),

                      // ─── Next Button ───
                      GoldGradientButton(
                        text: "NEXT",
                        onPressed: () async {
                          try {
                            await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
                              'country': _selectedCountry ?? '',
                              'state': _selectedState ?? '',
                              'city': _selectedCity ?? '',
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
