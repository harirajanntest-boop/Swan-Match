import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'interests_view.dart';

class PartnerPreferencesPage extends StatefulWidget {
  const PartnerPreferencesPage({super.key});

  @override
  State<PartnerPreferencesPage> createState() => _PartnerPreferencesPageState();
}

class _PartnerPreferencesPageState extends State<PartnerPreferencesPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  String _selectedCountry = '';
  String _selectedState = '';
  String _selectedCity = '';


  List<String> _optionsForPreference(String key) {
    switch (key) {
      case 'age':
        return const ['18 - 23', '24 - 30', '31 - 36', '37 - 45', 'Any'];
      case 'height':
        return const [
          '4ft 8in - 5ft 2in',
          '5ft 3in - 5ft 7in',
          '5ft 8in - 6ft 2in',
          'Any',
        ];
      case 'maritalStatus':
        return const ['Never married', 'Divorced', 'Widowed', 'Any'];
      case 'motherTongue':
        return const ['Tamil', 'Telugu', 'Malayalam', 'Kannada', 'Hindi', 'Any'];
      case 'physicalStatus':
        return const ['Normal', 'Physically Challenged', 'Any'];
      case 'eatingHabits':
        return const ['Vegetarian', 'Non Vegetarian', 'Eggetarian', 'Any'];
      case 'smokingHabits':
      case 'drinkingHabits':
        return const ['Never', 'Occasionally', 'Regularly', 'Any'];
      case 'religion':
        return const [
          'Hindu',
          'Muslim',
          'Christian',
          'Sikh',
          'Jain',
          'Buddhist',
          'Any',
        ];
      case 'dosham':
        return const ['Yes', 'No', "Don't know", 'Any'];
      case 'annualIncome':
        return const [
          'Below 3 LPA',
          '3 - 6 LPA',
          '6 - 10 LPA',
          '10 - 20 LPA',
          '20+ LPA',
          'Any',
        ];
      case 'employedIn':
        return const [
          'Private',
          'Government',
          'Business',
          'Defence',
          'Not working',
          'Any',
        ];
      default:
        return const <String>[];
    }
  }

  Future<String?> _chooseOrTypeValue({
    required String title,
    required String initial,
    required List<String> options,
  }) async {
    final controller = TextEditingController(
      text: initial == 'Not set' ? '' : initial,
    );

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? selected = options.contains(initial) ? initial : null;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.onyx,
              title: Text(
                title,
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (options.isNotEmpty) ...[
                      Text(
                        'Quick options',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: options.map((option) {
                          final isSelected = selected == option;
                          return ChoiceChip(
                            label: Text(option),
                            selected: isSelected,
                            selectedColor: AppColors.goldMedium,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.obsidian : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) {
                              setModalState(() {
                                selected = option;
                                controller.text = option;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: options.isNotEmpty
                            ? 'Or enter custom value'
                            : 'Enter $title',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.goldMedium),
                        ),
                      ),
                      onChanged: (_) {
                        if (selected != null) {
                          setModalState(() => selected = null);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, controller.text.trim()),
                  child: const Text(
                    'Save',
                    style: TextStyle(color: AppColors.goldMedium),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Map<String, dynamic> _normalizePreferences(Map<String, dynamic>? raw, {Map<String, dynamic>? rootProfile}) {
    final source = raw ?? <String, dynamic>{};
    final root = rootProfile ?? <String, dynamic>{};

    // Helper: read from nested section first, then flat root field as fallback
    String flatFallback(String sectionKey, String key, String flatKey) {
      final nested = (source[sectionKey] is Map)
          ? (source[sectionKey] as Map)[key]?.toString().trim() ?? ''
          : '';
      if (nested.isNotEmpty) return nested;
      return root[flatKey]?.toString().trim() ?? '';
    }

    Map<String, dynamic> section(String key, Map<String, dynamic> defaults) {
      final existing = source[key];
      if (existing is Map) {
        return {
          ...defaults,
          ...Map<String, dynamic>.from(existing),
        };
      }
      return {...defaults};
    }

    // Build age string from flat fields if not in nested
    String ageFromFlat() {
      final nested = (source['basicDetails'] is Map)
          ? (source['basicDetails'] as Map)['age']?.toString().trim() ?? ''
          : '';
      if (nested.isNotEmpty) return nested;
      final minAge = root['minAgePreference'];
      final maxAge = root['maxAgePreference'];
      if (minAge != null && maxAge != null) {
        return '$minAge - $maxAge';
      }
      return '';
    }

    final basic = section('basicDetails', <String, dynamic>{
      'age': '',
      'height': '',
      'maritalStatus': '',
      'motherTongue': '',
      'physicalStatus': '',
    });
    // Fallback age from flat fields
    if ((basic['age'] ?? '').toString().trim().isEmpty) {
      basic['age'] = ageFromFlat();
    }

    final lifestyle = section('lifestyle', <String, dynamic>{
      'eatingHabits': '',
      'smokingHabits': '',
      'drinkingHabits': '',
    });
    // Fallback smoking/drinking from flat fields
    if ((lifestyle['smokingHabits'] ?? '').toString().trim().isEmpty) {
      lifestyle['smokingHabits'] = root['smoking']?.toString().trim() ?? '';
    }
    if ((lifestyle['drinkingHabits'] ?? '').toString().trim().isEmpty) {
      lifestyle['drinkingHabits'] = root['drinking']?.toString().trim() ?? '';
    }

    final religious = section('religiousDetails', <String, dynamic>{
      'religion': '',
      'caste': '',
      'star': '',
      'dosham': '',
    });
    // Fallback religion from flat preferredReligion
    if ((religious['religion'] ?? '').toString().trim().isEmpty) {
      religious['religion'] = root['preferredReligion']?.toString().trim() ?? '';
    }

    final professional = section('professionalDetails', <String, dynamic>{
      'education': '',
      'employedIn': '',
      'occupation': '',
      'annualIncome': '',
    });
    // Fallback education from flat preferredEducation
    if ((professional['education'] ?? '').toString().trim().isEmpty) {
      professional['education'] = root['preferredEducation']?.toString().trim() ?? '';
    }
    // Fallback occupation from flat preferredProfession
    if ((professional['occupation'] ?? '').toString().trim().isEmpty) {
      professional['occupation'] = root['preferredProfession']?.toString().trim() ?? '';
    }

    final locationNested = section('locationDetails', <String, dynamic>{
      'country': '',
      'state': '',
      'city': '',
    });
    // Fallback location from flat preferredLocation
    if ((locationNested['country'] ?? '').toString().trim().isEmpty &&
        (locationNested['city'] ?? '').toString().trim().isEmpty) {
      final flatLocation = root['preferredLocation']?.toString().trim() ?? '';
      if (flatLocation.isNotEmpty) {
        locationNested['city'] = flatLocation;
      }
    }

    return <String, dynamic>{
      'basicDetails': basic,
      'lifestyle': lifestyle,
      'religiousDetails': religious,
      'professionalDetails': professional,
      'locationDetails': locationNested,
    };
  }


  Future<void> _editPreference({
    required String section,
    required String key,
    required String label,
    required String currentValue,
    required Map<String, dynamic> currentPrefs,
  }) async {
    final updated = await _chooseOrTypeValue(
      title: label,
      initial: currentValue,
      options: _optionsForPreference(key),
    );

    if (updated == null) return;

    final nextPrefs = Map<String, dynamic>.from(currentPrefs);
    final nextSection = Map<String, dynamic>.from(nextPrefs[section] as Map<String, dynamic>);
    nextSection[key] = updated;
    nextPrefs[section] = nextSection;

    await UserService.instance.updatePartnerPreferences(nextPrefs);
  }

  Future<void> _loadLocationStateFromProfile() async {
    final profile = await UserService.instance.getCurrentUserProfile();
    final normalized = _normalizePreferences(
      profile?['partnerPreference'] is Map
          ? Map<String, dynamic>.from(profile?['partnerPreference'] as Map)
          : (profile?['partnerPreferences'] is Map
              ? Map<String, dynamic>.from(profile?['partnerPreferences'] as Map)
              : null),
      rootProfile: profile,
    );

    final location = Map<String, dynamic>.from(
      normalized['locationDetails'] as Map,
    );

    if (!mounted) return;
    setState(() {
      _selectedCountry = (location['country'] ?? '').toString().trim();
      _selectedState = (location['state'] ?? '').toString().trim();
      _selectedCity = (location['city'] ?? '').toString().trim();
    });
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

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryController.forward();
    });

    _loadLocationStateFromProfile();
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
          "Partner Preferences",
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
          child: StreamBuilder<Map<String, dynamic>?>(
            stream: UserService.instance.watchCurrentUserProfile(),
            builder: (context, snapshot) {
              final profile = snapshot.data ?? <String, dynamic>{};
              final currentPrefs = _normalizePreferences(
                (profile['partnerPreference'] is Map
                  ? Map<String, dynamic>.from(profile['partnerPreference'] as Map)
                  : (profile['partnerPreferences'] is Map
                    ? Map<String, dynamic>.from(profile['partnerPreferences'] as Map)
                    : null)),
                rootProfile: profile,
              );

              String display(dynamic value) {
                final text = (value ?? '').toString().trim();
                return text.isEmpty ? 'Not set' : text;
              }

              final basic = Map<String, dynamic>.from(currentPrefs['basicDetails'] as Map);
              final lifestyle = Map<String, dynamic>.from(currentPrefs['lifestyle'] as Map);
              final religious = Map<String, dynamic>.from(currentPrefs['religiousDetails'] as Map);
              final professional = Map<String, dynamic>.from(currentPrefs['professionalDetails'] as Map);
              final location = Map<String, dynamic>.from(currentPrefs['locationDetails'] as Map);


                final locationCountryValue = _selectedCountry ?? display(location['country']);
                final locationStateValue = _selectedState ?? display(location['state']);
                final locationCityValue = _selectedCity ?? display(location['city']);

              return Column(
                children: [
              // ─── Header Information ───
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.goldMedium.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.goldMedium.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.goldMedium,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Matches are recommended to you based on your preferences. To see matches exactly based on your preferences, turn on 'Compulsory' inside each section.",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Preferences List ───
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // 1. Basic Details
                      _PreferenceCard(
                        title: "Basic Details",
                        children: [
                          _PreferenceRow(
                            label: "Age",
                            value: display(basic['age']),
                            onTap: () => _editPreference(
                              section: 'basicDetails',
                              key: 'age',
                              label: 'Age',
                              currentValue: basic['age'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Height",
                            value: display(basic['height']),
                            onTap: () => _editPreference(
                              section: 'basicDetails',
                              key: 'height',
                              label: 'Height',
                              currentValue: basic['height'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Marital Status",
                            value: display(basic['maritalStatus']),
                            onTap: () => _editPreference(
                              section: 'basicDetails',
                              key: 'maritalStatus',
                              label: 'Marital Status',
                              currentValue: basic['maritalStatus'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Mother Tongue",
                            value: display(basic['motherTongue']),
                            onTap: () => _editPreference(
                              section: 'basicDetails',
                              key: 'motherTongue',
                              label: 'Mother Tongue',
                              currentValue: basic['motherTongue'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Physical Status",
                            value: display(basic['physicalStatus']),
                            isLast: true,
                            onTap: () => _editPreference(
                              section: 'basicDetails',
                              key: 'physicalStatus',
                              label: 'Physical Status',
                              currentValue: basic['physicalStatus'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 2. Lifestyle
                      _PreferenceCard(
                        title: "Lifestyle",
                        children: [
                          _PreferenceRow(
                            label: "Eating Habits",
                            value: display(lifestyle['eatingHabits']),
                            onTap: () => _editPreference(
                              section: 'lifestyle',
                              key: 'eatingHabits',
                              label: 'Eating Habits',
                              currentValue: lifestyle['eatingHabits'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Smoking Habits",
                            value: display(lifestyle['smokingHabits']),
                            onTap: () => _editPreference(
                              section: 'lifestyle',
                              key: 'smokingHabits',
                              label: 'Smoking Habits',
                              currentValue: lifestyle['smokingHabits'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Drinking Habits",
                            value: display(lifestyle['drinkingHabits']),
                            isLast: true,
                            onTap: () => _editPreference(
                              section: 'lifestyle',
                              key: 'drinkingHabits',
                              label: 'Drinking Habits',
                              currentValue: lifestyle['drinkingHabits'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 3. Religious Details
                      _PreferenceCard(
                        title: "Religious Details",
                        children: [
                          _PreferenceRow(
                            label: "Religion",
                            value: display(religious['religion']),
                            onTap: () => _editPreference(
                              section: 'religiousDetails',
                              key: 'religion',
                              label: 'Religion',
                              currentValue: religious['religion'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Caste",
                            value: display(religious['caste']),
                            onTap: () => _editPreference(
                              section: 'religiousDetails',
                              key: 'caste',
                              label: 'Caste',
                              currentValue: religious['caste'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Star",
                            value: display(religious['star']),
                            onTap: () => _editPreference(
                              section: 'religiousDetails',
                              key: 'star',
                              label: 'Star',
                              currentValue: religious['star'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Dosham",
                            value: display(religious['dosham']),
                            isLast: true,
                            onTap: () => _editPreference(
                              section: 'religiousDetails',
                              key: 'dosham',
                              label: 'Dosham',
                              currentValue: religious['dosham'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 4. Professional Details (Extrapolated)
                      _PreferenceCard(
                        title: "Professional Details",
                        children: [
                          _PreferenceRow(
                            label: "Education",
                            value: display(professional['education']),
                            onTap: () => _editPreference(
                              section: 'professionalDetails',
                              key: 'education',
                              label: 'Education',
                              currentValue: professional['education'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Employed in",
                            value: display(professional['employedIn']),
                            onTap: () => _editPreference(
                              section: 'professionalDetails',
                              key: 'employedIn',
                              label: 'Employed in',
                              currentValue: professional['employedIn'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Occupation",
                            value: display(professional['occupation']),
                            onTap: () => _editPreference(
                              section: 'professionalDetails',
                              key: 'occupation',
                              label: 'Occupation',
                              currentValue: professional['occupation'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Annual Income",
                            value: display(professional['annualIncome']),
                            isLast: true,
                            onTap: () => _editPreference(
                              section: 'professionalDetails',
                              key: 'annualIncome',
                              label: 'Annual Income',
                              currentValue: professional['annualIncome'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 5. Location Details
                      _PreferenceCard(
                        title: "Location Details",
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                // State TextField
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
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // ─── Action Button ───
                      GoldGradientButton(
                        text: "VIEW MATCHES",
                        onPressed: () async {
                          try {
                            final nextPrefs = Map<String, dynamic>.from(currentPrefs);
                            final nextLocation = Map<String, dynamic>.from(
                              nextPrefs['locationDetails'] as Map<String, dynamic>,
                            );
                            nextLocation['country'] = _selectedCountry.isEmpty ? nextLocation['country'] ?? '' : _selectedCountry;
                            nextLocation['state'] = _selectedState.isEmpty ? nextLocation['state'] ?? '' : _selectedState;
                            nextLocation['city'] = _selectedCity.isEmpty ? nextLocation['city'] ?? '' : _selectedCity;
                            nextPrefs['locationDetails'] = nextLocation;

                            await UserService.instance.updatePartnerPreferences(nextPrefs);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Partner preferences saved.')),
                            );
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Unable to save partner preferences.')),
                            );
                            return;
                          }

                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const InterestsView(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Reusable Glass Card Component ───────────────────────────────────────────
class _PreferenceCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _PreferenceCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.goldLight,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(children: children),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Reusable Clickable Row Component ────────────────────────────────────────
class _PreferenceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  final VoidCallback onTap;

  const _PreferenceRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.goldMedium.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.goldMedium.withOpacity(0.9),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.3),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPreferenceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  final bool enabled;
  final VoidCallback onTap;

  const _LocationPreferenceRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.isLast = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isNotSet = value.trim().isEmpty || value == 'Not set';
    final rightColor = enabled
        ? (isNotSet ? Colors.white54 : const Color(0xFFFFD700))
        : Colors.grey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.goldMedium.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  isNotSet ? 'Not set' : value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: rightColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                color: enabled ? rightColor : Colors.grey,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
