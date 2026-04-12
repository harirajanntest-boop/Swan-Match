import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';

class EditPreferencesPage extends StatefulWidget {
  const EditPreferencesPage({super.key});

  @override
  State<EditPreferencesPage> createState() => _EditPreferencesPageState();
}

class _EditPreferencesPageState extends State<EditPreferencesPage> with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  String _ageRange = '';
  String _heightRange = '';

  Map<String, dynamic> _extractFlatPreferenceMap(Map<String, dynamic> profile) {
    final raw = profile['partnerPreference'] ?? profile['partnerPreferences'];
    final source = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    final basic = source['basicDetails'] is Map
        ? Map<String, dynamic>.from(source['basicDetails'] as Map)
        : <String, dynamic>{};
    final lifestyle = source['lifestyle'] is Map
        ? Map<String, dynamic>.from(source['lifestyle'] as Map)
        : <String, dynamic>{};
    final religious = source['religiousDetails'] is Map
        ? Map<String, dynamic>.from(source['religiousDetails'] as Map)
        : <String, dynamic>{};
    final professional = source['professionalDetails'] is Map
        ? Map<String, dynamic>.from(source['professionalDetails'] as Map)
        : <String, dynamic>{};

    final flat = <String, dynamic>{
      ...source,
      'ageRange': source['ageRange'] ?? basic['age'] ?? '',
      'heightRange': source['heightRange'] ?? basic['height'] ?? '',
      'maritalStatus': source['maritalStatus'] ?? basic['maritalStatus'] ?? '',
      'motherTongue': source['motherTongue'] ?? basic['motherTongue'] ?? '',
      'physicalStatus': source['physicalStatus'] ?? basic['physicalStatus'] ?? '',
      'eatingHabits': source['eatingHabits'] ?? lifestyle['eatingHabits'] ?? '',
      'smokingHabits': source['smokingHabits'] ?? lifestyle['smokingHabits'] ?? '',
      'drinkingHabits': source['drinkingHabits'] ?? lifestyle['drinkingHabits'] ?? '',
      'religion': source['religion'] ?? religious['religion'] ?? '',
      'caste': source['caste'] ?? religious['caste'] ?? '',
      'star': source['star'] ?? religious['star'] ?? '',
      'dosham': source['dosham'] ?? religious['dosham'] ?? '',
      'occupation': source['occupation'] ?? professional['occupation'] ?? '',
      'annualIncome': source['annualIncome'] ?? professional['annualIncome'] ?? '',
      'employmentType': source['employmentType'] ?? professional['employedIn'] ?? '',
      'education': source['education'] ?? professional['education'] ?? '',
    };

    return flat;
  }

  List<String> _optionsForPreference(String key) {
    switch (key) {
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
        return const ['Hindu', 'Muslim', 'Christian', 'Sikh', 'Jain', 'Buddhist', 'Any'];
      case 'dosham':
        return const ['Yes', 'No', "Don't know", 'Any'];
      case 'occupation':
      case 'annualIncome':
      case 'employmentType':
      case 'education':
      case 'caste':
      case 'subCaste':
      case 'star':
        return const ['Any'];
      default:
        return const <String>[];
    }
  }

  Future<String?> _chooseOrTypeValue({
    required String title,
    required String initial,
    required List<String> options,
  }) async {
    final controller = TextEditingController(text: initial == 'Not set' ? '' : initial);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? selected = options.contains(initial) ? initial : null;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.onyx,
              title: Text(title, style: const TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (options.isNotEmpty) ...[
                      Text('Quick options', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
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
                        hintText: options.isNotEmpty ? 'Or enter custom value' : 'Enter value',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
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
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
                  child: const Text('Save', style: TextStyle(color: AppColors.goldMedium)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _savePreferenceValue({
    required Map<String, dynamic> currentPrefs,
    required String key,
    required String value,
  }) async {
    final next = Map<String, dynamic>.from(currentPrefs);
    next[key] = value;
    await UserService.instance.updatePartnerPreferences(next);
  }

  Future<void> _editSingleValue({
    required String label,
    required String key,
    required String currentValue,
    required Map<String, dynamic> currentPrefs,
  }) async {
    final updated = await _chooseOrTypeValue(
      title: label,
      initial: currentValue,
      options: _optionsForPreference(key),
    );

    if (updated == null) return;
    await _savePreferenceValue(currentPrefs: currentPrefs, key: key, value: updated);
  }

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.1, 1.0, curve: Curves.easeOut)));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)));

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  // ─── Bottom Sheet for Editing Ranges (Age/Height) ───
  void _showRangeEditor({
    required String title,
    required String type,
    required String currentValue,
    required Map<String, dynamic> currentPrefs,
  }) {
    final controller = TextEditingController(text: currentValue == 'Not set' ? '' : currentValue);
    bool isCompulsory = (currentPrefs['${type}Compulsory'] ?? false) == true;
    final suggestions = type == 'age'
        ? const ['18 - 23', '24 - 30', '31 - 36', 'Any']
        : const ['4ft 8in - 5ft 2in', '5ft 3in - 5ft 7in', '5ft 8in - 6ft 2in', 'Any'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.obsidian.withOpacity(0.9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border.all(color: AppColors.goldMedium.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 24),
                    
                    Text("Edit $title", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                    const SizedBox(height: 8),
                    Text("Please specify the range to find your preferred matches.", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                    const SizedBox(height: 32),

                    TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: title,
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        hintText: type == 'age' ? 'Eg: 24 - 30' : 'Eg: 5ft - 5ft 8in',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.goldMedium),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions.map((item) {
                        final selected = controller.text.trim() == item;
                        return ChoiceChip(
                          label: Text(item),
                          selected: selected,
                          selectedColor: AppColors.goldMedium,
                          labelStyle: TextStyle(
                            color: selected ? AppColors.obsidian : Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setModalState(() => controller.text = item),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // Compulsory Toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isCompulsory ? AppColors.goldMedium.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isCompulsory ? AppColors.goldMedium.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Compulsory", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text("See matches strictly within this range", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.4)),
                              ],
                            ),
                          ),
                          Switch(
                            value: isCompulsory,
                            activeColor: AppColors.obsidian,
                            activeTrackColor: AppColors.goldMedium,
                            inactiveThumbColor: Colors.white54,
                            inactiveTrackColor: Colors.white.withOpacity(0.1),
                            onChanged: (val) => setModalState(() => isCompulsory = val),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    GoldGradientButton(
                      text: "SAVE CHANGES",
                      onPressed: () async {
                        final next = Map<String, dynamic>.from(currentPrefs);
                        next[type == 'age' ? 'ageRange' : 'heightRange'] = controller.text.trim();
                        next['${type}Compulsory'] = isCompulsory;
                        await UserService.instance.updatePartnerPreferences(next);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
          "Partner Preferences",
          style: TextStyle(color: Colors.white, fontFamily: 'serif', letterSpacing: 1, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: UserService.instance.watchCurrentUserProfile(),
        builder: (context, snapshot) {
          final profile = snapshot.data ?? <String, dynamic>{};
          final prefs = _extractFlatPreferenceMap(profile);

          final ageValue = (prefs['ageRange'] ?? _ageRange).toString().trim();
          final heightValue = (prefs['heightRange'] ?? _heightRange).toString().trim();
          final maritalValue = (prefs['maritalStatus'] ?? '').toString().trim();
          final motherTongueValue = (prefs['motherTongue'] ?? '').toString().trim();
          final physicalValue = (prefs['physicalStatus'] ?? '').toString().trim();
          final eatingValue = (prefs['eatingHabits'] ?? '').toString().trim();
          final smokingValue = (prefs['smokingHabits'] ?? '').toString().trim();
          final drinkingValue = (prefs['drinkingHabits'] ?? '').toString().trim();
          final religionValue = (prefs['religion'] ?? '').toString().trim();
          final casteValue = (prefs['caste'] ?? '').toString().trim();
          final subCasteValue = (prefs['subCaste'] ?? '').toString().trim();
          final doshamValue = (prefs['dosham'] ?? '').toString().trim();
          final starValue = (prefs['star'] ?? '').toString().trim();
          final occupationValue = (prefs['occupation'] ?? '').toString().trim();
          final incomeValue = (prefs['annualIncome'] ?? '').toString().trim();
          final employmentValue = (prefs['employmentType'] ?? '').toString().trim();
          final educationValue = (prefs['education'] ?? '').toString().trim();

          String withFallback(String input) => input.isEmpty ? 'Not set' : input;

          return FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // ─── Info Banner ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.goldMedium.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.goldMedium.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.goldMedium, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.5),
                              children: [
                                const TextSpan(text: "Matches are recommended based on your preferences. To see matches exactly based on your preferences, turn on "),
                                TextSpan(text: "'Compulsory'", style: TextStyle(color: AppColors.goldMedium.withOpacity(0.9), fontWeight: FontWeight.bold)),
                                const TextSpan(text: "."),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Basic Details ───
                _PreferenceCard(
                  title: "Basic Details",
                  children: [
                    _PreferenceRow(
                      label: "Age", value: withFallback(ageValue),
                      onTap: () => _showRangeEditor(
                        title: "Age Range",
                        type: 'age',
                        currentValue: withFallback(ageValue),
                        currentPrefs: prefs,
                      ),
                    ),
                    _PreferenceRow(
                      label: "Height", value: withFallback(heightValue), 
                      isLongValue: true,
                      onTap: () => _showRangeEditor(
                        title: "Height Range",
                        type: 'height',
                        currentValue: withFallback(heightValue),
                        currentPrefs: prefs,
                      ),
                    ),
                    _PreferenceRow(
                      label: "Marital Status",
                      value: withFallback(maritalValue),
                      onTap: () => _editSingleValue(
                        label: 'Marital Status',
                        key: 'maritalStatus',
                        currentValue: withFallback(maritalValue),
                        currentPrefs: prefs,
                      ),
                    ),
                    _PreferenceRow(
                      label: "Mother Tongue",
                      value: withFallback(motherTongueValue),
                      onTap: () => _editSingleValue(
                        label: 'Mother Tongue',
                        key: 'motherTongue',
                        currentValue: withFallback(motherTongueValue),
                        currentPrefs: prefs,
                      ),
                    ),
                    _PreferenceRow(
                      label: "Physical Status",
                      value: withFallback(physicalValue),
                      isLast: true,
                      onTap: () => _editSingleValue(
                        label: 'Physical Status',
                        key: 'physicalStatus',
                        currentValue: withFallback(physicalValue),
                        currentPrefs: prefs,
                      ),
                    ),
                  ],
                ),

                // ─── Lifestyle ───
                _PreferenceCard(
                  title: "Lifestyle",
                  children: [
                    _PreferenceRow(
                      label: "Eating Habits",
                      value: withFallback(eatingValue),
                      onTap: () => _editSingleValue(
                        label: 'Eating Habits',
                        key: 'eatingHabits',
                        currentValue: withFallback(eatingValue),
                        currentPrefs: prefs,
                      ),
                    ),
                    _PreferenceRow(
                      label: "Smoking Habits",
                      value: withFallback(smokingValue),
                      onTap: () => _editSingleValue(
                        label: 'Smoking Habits',
                        key: 'smokingHabits',
                        currentValue: withFallback(smokingValue),
                        currentPrefs: prefs,
                      ),
                    ),
                    _PreferenceRow(
                      label: "Drinking Habits",
                      value: withFallback(drinkingValue),
                      isLast: true,
                      onTap: () => _editSingleValue(
                        label: 'Drinking Habits',
                        key: 'drinkingHabits',
                        currentValue: withFallback(drinkingValue),
                        currentPrefs: prefs,
                      ),
                    ),
                  ],
                ),

                // ─── Religious Details (With Locked Feature) ───
                _PreferenceCard(
                  title: "Religious Details",
                  children: [
                    _PreferenceRow(
                      label: "Religion",
                      value: withFallback(religionValue),
                      onTap: () => _editSingleValue(
                        label: 'Religion',
                        key: 'religion',
                        currentValue: withFallback(religionValue),
                        currentPrefs: prefs,
                      ),
                    ),
                    _PreferenceRow(
                      label: "Caste",
                      value: withFallback(casteValue),
                      isLongValue: true,
                      onTap: () => _editSingleValue(
                        label: 'Caste',
                        key: 'caste',
                        currentValue: withFallback(casteValue),
                        currentPrefs: prefs,
                      ),
                    ),
                    _PreferenceRow(
                      label: "Subcaste",
                      value: withFallback(subCasteValue),
                      onTap: () => _editSingleValue(
                        label: 'Subcaste',
                        key: 'subCaste',
                        currentValue: withFallback(subCasteValue),
                        currentPrefs: prefs,
                      ),
                    ),
                    _PreferenceRow(
                      label: "Dosham",
                      value: withFallback(doshamValue),
                      onTap: () => _editSingleValue(
                        label: 'Dosham',
                        key: 'dosham',
                        currentValue: withFallback(doshamValue),
                        currentPrefs: prefs,
                      ),
                    ),
                    _PreferenceRow(
                      label: "Star",
                      value: withFallback(starValue),
                      isLast: true,
                      onTap: () => _editSingleValue(
                        label: 'Star',
                        key: 'star',
                        currentValue: withFallback(starValue),
                        currentPrefs: prefs,
                      ),
                    ),
                  ],
                ),

                // ─── Professional Details ───
                _PreferenceCard(
                  title: "Professional Details",
                  children: [
                    _PreferenceRow(
                      label: "Occupation",
                      value: withFallback(occupationValue),
                      onTap: () => _editSingleValue(
                        label: 'Occupation',
                        key: 'occupation',
                        currentValue: withFallback(occupationValue),
                        currentPrefs: prefs,
                      ),
                    ),
                    _PreferenceRow(
                      label: "Annual Income",
                      value: withFallback(incomeValue),
                      onTap: () => _editSingleValue(
                        label: 'Annual Income',
                        key: 'annualIncome',
                        currentValue: withFallback(incomeValue),
                        currentPrefs: prefs,
                      ),
                    ),
                    _PreferenceRow(
                      label: "Employment Type",
                      value: withFallback(employmentValue),
                      onTap: () => _editSingleValue(
                        label: 'Employment Type',
                        key: 'employmentType',
                        currentValue: withFallback(employmentValue),
                        currentPrefs: prefs,
                      ),
                    ),
                    _PreferenceRow(
                      label: "Education",
                      value: withFallback(educationValue),
                      isLongValue: true,
                      isLast: true,
                      onTap: () => _editSingleValue(
                        label: 'Education',
                        key: 'education',
                        currentValue: withFallback(educationValue),
                        currentPrefs: prefs,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
        },
      ),
    );
  }
}

// ─── Sub-Components ───

// Reusable Glass Card for Categories
class _PreferenceCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _PreferenceCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'serif', letterSpacing: 0.5),
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
      ),
    );
  }
}

// Reusable Clickable Row
class _PreferenceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  final bool isLongValue;
  final VoidCallback onTap;

  const _PreferenceRow({
    required this.label,
    required this.value,
    this.isLast = false,
    this.isLongValue = false,
    required this.onTap,
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
            border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(
            crossAxisAlignment: isLongValue ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    if (isLongValue) ...[
                      const SizedBox(height: 4),
                      const Text("Read more", style: TextStyle(color: AppColors.goldMedium, fontSize: 11)),
                    ]
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.3), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
