import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:country_state_city/country_state_city.dart' as csc;
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'interests_page.dart';

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

  List<csc.Country> _countries = const <csc.Country>[];
  List<csc.State> _states = const <csc.State>[];
  List<csc.City> _cities = const <csc.City>[];

  String? _selectedCountry;
  String? _selectedCountryCode;
  String? _selectedState;
  String? _selectedStateCode;
  String? _selectedCity;
  bool _locationInitialized = false;

  T? _firstWhereOrNull<T>(Iterable<T> source, bool Function(T item) test) {
    for (final item in source) {
      if (test(item)) return item;
    }
    return null;
  }

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

  Map<String, dynamic> _normalizePreferences(Map<String, dynamic>? raw) {
    final source = raw ?? <String, dynamic>{};

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

    return <String, dynamic>{
      'basicDetails': section('basicDetails', <String, dynamic>{
        'age': '',
        'height': '',
        'maritalStatus': '',
        'motherTongue': '',
        'physicalStatus': '',
      }),
      'lifestyle': section('lifestyle', <String, dynamic>{
        'eatingHabits': '',
        'smokingHabits': '',
        'drinkingHabits': '',
      }),
      'religiousDetails': section('religiousDetails', <String, dynamic>{
        'religion': '',
        'caste': '',
        'star': '',
        'dosham': '',
      }),
      'professionalDetails': section('professionalDetails', <String, dynamic>{
        'education': '',
        'employedIn': '',
        'occupation': '',
        'annualIncome': '',
      }),
      'locationDetails': section('locationDetails', <String, dynamic>{
        'country': '',
        'state': '',
        'city': '',
      }),
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
    );

    final location = Map<String, dynamic>.from(
      normalized['locationDetails'] as Map,
    );

    final countries = await csc.getAllCountries();
    if (!mounted) return;

    String? countryName = (location['country'] ?? '').toString().trim();
    String? stateName = (location['state'] ?? '').toString().trim();
    String? cityName = (location['city'] ?? '').toString().trim();

    final selectedCountryObj = countryName.isEmpty
        ? null
        : _firstWhereOrNull(
            countries,
            (country) => country.name.toLowerCase() == (countryName ?? '').toLowerCase(),
          );

    List<csc.State> states = const <csc.State>[];
    csc.State? selectedStateObj;
    List<csc.City> cities = const <csc.City>[];

    if (selectedCountryObj != null) {
      states = await csc.getStatesOfCountry(selectedCountryObj.isoCode);
      selectedStateObj = stateName.isEmpty
          ? null
          : _firstWhereOrNull(
              states,
              (state) => state.name.toLowerCase() == (stateName ?? '').toLowerCase(),
            );

      if (selectedStateObj != null) {
        cities = await csc.getStateCities(
          selectedCountryObj.isoCode,
          selectedStateObj.isoCode,
        );

        final selectedCityObj = cityName.isEmpty
            ? null
            : _firstWhereOrNull(
                cities,
                (city) => city.name.toLowerCase() == (cityName ?? '').toLowerCase(),
              );

        cityName = selectedCityObj?.name;
      } else {
        cityName = null;
      }
    } else {
      countryName = null;
      stateName = null;
      cityName = null;
    }

    if (!mounted) return;
    setState(() {
      _countries = countries;
      _states = states;
      _cities = cities;
      _selectedCountry = countryName;
      _selectedCountryCode = selectedCountryObj?.isoCode;
      _selectedState = selectedStateObj?.name;
      _selectedStateCode = selectedStateObj?.isoCode;
      _selectedCity = cityName;
      _locationInitialized = true;
    });
  }

  Future<String?> _showLocationPicker({
    required String title,
    required List<String> options,
    required String? selected,
  }) async {
    final searchController = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.onyx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = options
                .where(
                  (item) => item.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) => setModalState(() => query = value),
                    decoration: InputDecoration(
                      hintText: 'Search $title',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                      prefixIcon: const Icon(Icons.search, color: AppColors.goldMedium),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.25),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.goldMedium),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No results found',
                              style: TextStyle(color: Colors.white.withOpacity(0.6)),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.08), height: 1),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final isSelected = selected == item;
                              return ListTile(
                                title: Text(
                                  item,
                                  style: TextStyle(
                                    color: isSelected ? AppColors.goldMedium : Colors.white,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                                onTap: () => Navigator.pop(sheetContext, item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _persistLocationSelection(Map<String, dynamic> currentPrefs) async {
    final nextPrefs = Map<String, dynamic>.from(currentPrefs);
    final nextLocation = Map<String, dynamic>.from(
      nextPrefs['locationDetails'] as Map<String, dynamic>,
    );

    nextLocation['country'] = _selectedCountry ?? '';
    nextLocation['state'] = _selectedState ?? '';
    nextLocation['city'] = _selectedCity ?? '';
    nextPrefs['locationDetails'] = nextLocation;

    await UserService.instance.updatePartnerPreferences(nextPrefs);
  }

  Future<void> _onSelectCountry(Map<String, dynamic> currentPrefs) async {
    final countryNames = _countries.map((country) => country.name).toList();
    final picked = await _showLocationPicker(
      title: 'Country',
      options: countryNames,
      selected: _selectedCountry,
    );
    if (picked == null) return;

    final selectedCountry = _firstWhereOrNull(
      _countries,
      (country) => country.name == picked,
    );
    if (selectedCountry == null) return;

    final states = await csc.getStatesOfCountry(selectedCountry.isoCode);
    if (!mounted) return;

    setState(() {
      _selectedCountry = selectedCountry.name;
      _selectedCountryCode = selectedCountry.isoCode;
      _states = states;
      _selectedState = null;
      _selectedStateCode = null;
      _cities = const <csc.City>[];
      _selectedCity = null;
    });

    await _persistLocationSelection(currentPrefs);
  }

  Future<void> _onSelectState(Map<String, dynamic> currentPrefs) async {
    if (_selectedCountryCode == null || _selectedCountryCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a country first.')),
      );
      return;
    }

    if (_states.isEmpty) {
      _states = await csc.getStatesOfCountry(_selectedCountryCode!);
    }

    final stateNames = _states.map((state) => state.name).toList();
    final picked = await _showLocationPicker(
      title: 'State',
      options: stateNames,
      selected: _selectedState,
    );
    if (picked == null) return;

    final selectedState = _firstWhereOrNull(
      _states,
      (state) => state.name == picked,
    );
    if (selectedState == null) return;

    final cities = await csc.getStateCities(
      _selectedCountryCode!,
      selectedState.isoCode,
    );
    if (!mounted) return;

    setState(() {
      _selectedState = selectedState.name;
      _selectedStateCode = selectedState.isoCode;
      _cities = cities;
      _selectedCity = null;
    });

    await _persistLocationSelection(currentPrefs);
  }

  Future<void> _onSelectCity(Map<String, dynamic> currentPrefs) async {
    if (_selectedStateCode == null || _selectedStateCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a state first.')),
      );
      return;
    }

    if (_selectedCountryCode == null || _selectedCountryCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a country first.')),
      );
      return;
    }

    if (_cities.isEmpty) {
      _cities = await csc.getStateCities(_selectedCountryCode!, _selectedStateCode!);
    }

    final cityNames = _cities.map((city) => city.name).toList();
    final picked = await _showLocationPicker(
      title: 'City',
      options: cityNames,
      selected: _selectedCity,
    );
    if (picked == null) return;

    setState(() {
      _selectedCity = picked;
    });

    await _persistLocationSelection(currentPrefs);
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

                if (!_locationInitialized) {
                final locationCountry = (location['country'] ?? '').toString().trim();
                final locationState = (location['state'] ?? '').toString().trim();
                final locationCity = (location['city'] ?? '').toString().trim();

                if (locationCountry.isNotEmpty) _selectedCountry = locationCountry;
                if (locationState.isNotEmpty) _selectedState = locationState;
                if (locationCity.isNotEmpty) _selectedCity = locationCity;
                }

                final locationCountryValue = (_selectedCountry ?? '').trim().isEmpty
                  ? display(location['country'])
                  : _selectedCountry!;
                final locationStateValue = (_selectedState ?? '').trim().isEmpty
                  ? display(location['state'])
                  : _selectedState!;
                final locationCityValue = (_selectedCity ?? '').trim().isEmpty
                  ? display(location['city'])
                  : _selectedCity!;

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

                      // 5. Location Details (Extrapolated)
                      _PreferenceCard(
                        title: "Location Details",
                        children: [
                          _LocationPreferenceRow(
                            label: "Country",
                            value: locationCountryValue,
                            enabled: true,
                            onTap: () => _onSelectCountry(currentPrefs),
                          ),
                          _LocationPreferenceRow(
                            label: "Residing State",
                            value: locationStateValue,
                            enabled: (_selectedCountry ?? locationCountryValue) != 'Not set',
                            onTap: () => _onSelectState(currentPrefs),
                          ),
                          _LocationPreferenceRow(
                            label: "City",
                            value: locationCityValue,
                            isLast: true,
                            enabled: (_selectedState ?? locationStateValue) != 'Not set',
                            onTap: () => _onSelectCity(currentPrefs),
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
                            nextLocation['country'] = _selectedCountry ?? nextLocation['country'] ?? '';
                            nextLocation['state'] = _selectedState ?? nextLocation['state'] ?? '';
                            nextLocation['city'] = _selectedCity ?? nextLocation['city'] ?? '';
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
                              builder: (context) => const InterestsPage(),
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
              fontFamily: 'serif',
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
