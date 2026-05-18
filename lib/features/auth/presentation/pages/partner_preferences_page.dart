import 'dart:ui';
import 'package:flutter/material.dart';
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


  List<String> _optionsForPreference(String key) {
    switch (key) {
      case 'age':
        return const ['18 - 23', '24 - 30', '31 - 36', '37 - 45', '45 - 55', '55+', 'Any'];

      case 'maritalStatus':
        return const ['Never Married', 'Divorced', 'Widowed', 'Separated', 'Any'];
      case 'religion':
        return const [
          'Hindu',
          'Muslim',
          'Christian',
          'Sikh',
          'Jain',
          'Buddhist',
          'Atheist',
          'Any',
        ];
      case 'education':
        return const ['High School', 'Associate Degree', 'Bachelor', 'Master', 'Doctorate', 'Any'];
      case 'profession':
        return const ['IT', 'Finance', 'Healthcare', 'Education', 'Engineering', 'Business', 'Law', 'Any'];
      case 'income':
        return const ['Under 25K', '25K - 50K', '50K - 100K', '100K - 200K', '200K+', 'Any'];
      case 'eatingHabits':
        return const ['Vegetarian', 'Non Vegetarian', 'Eggetarian', 'Any'];
      case 'smokingHabits':
      case 'drinkingHabits':
        return const ['Never', 'Occasionally', 'Regularly', 'Any'];
      case 'lifestyle':
        return const ['Health-focused', 'Career-driven', 'Family-oriented', 'Social', 'Adventure-seeking', 'Any'];
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

    // Extract age range from flat fields
    String getAgeRange() {
      final minAge = root['minAgePreference'] ?? 18;
      final maxAge = root['maxAgePreference'] ?? 99;
      return '$minAge - $maxAge';
    }

    final basic = section('basicDetails', <String, dynamic>{
      'age': getAgeRange(),
      'maritalStatus': root['preferredMaritalStatus']?.toString().trim() ?? '',
      'religion': root['preferredReligion']?.toString().trim() ?? '',
    });

    final lifestyle = section('lifestyle', <String, dynamic>{
      'eatingHabits': root['preferredEatingHabits']?.toString().trim() ?? '',
      'smokingHabits': root['smoking']?.toString().trim() ?? '',
      'drinkingHabits': root['drinking']?.toString().trim() ?? '',
      'lifestyle': _convertLifestyleList(root['preferredLifestyle']),
    });

    final professional = section('professionalDetails', <String, dynamic>{
      'education': root['preferredEducation']?.toString().trim() ?? '',
      'profession': root['preferredProfession']?.toString().trim() ?? '',
      'income': root['preferredIncomeRange']?.toString().trim() ?? '',
    });

    final location = section('locationDetails', <String, dynamic>{
      'country': root['preferredLocation']?.toString().trim() ?? '',
    });

    return <String, dynamic>{
      'basicDetails': basic,
      'lifestyle': lifestyle,
      'professionalDetails': professional,
      'locationDetails': location,
    };
  }

  String _convertLifestyleList(dynamic lifestyle) {
    if (lifestyle is List) {
      return (lifestyle).cast<String>().join(', ');
    }
    return lifestyle?.toString().trim() ?? '';
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
              final professional = Map<String, dynamic>.from(currentPrefs['professionalDetails'] as Map);
              final location = Map<String, dynamic>.from(currentPrefs['locationDetails'] as Map);

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
                          "Set your partner preferences to find matches tailored to you.",
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
                            label: "Age Range",
                            value: display(basic['age']),
                            onTap: () => _editPreference(
                              section: 'basicDetails',
                              key: 'age',
                              label: 'Age Range',
                              currentValue: basic['age'].toString(),
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
                            label: "Religion",
                            value: display(basic['religion']),
                            isLast: true,
                            onTap: () => _editPreference(
                              section: 'basicDetails',
                              key: 'religion',
                              label: 'Religion',
                              currentValue: basic['religion'].toString(),
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
                            onTap: () => _editPreference(
                              section: 'lifestyle',
                              key: 'drinkingHabits',
                              label: 'Drinking Habits',
                              currentValue: lifestyle['drinkingHabits'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Lifestyle",
                            value: display(lifestyle['lifestyle']),
                            isLast: true,
                            onTap: () => _editPreference(
                              section: 'lifestyle',
                              key: 'lifestyle',
                              label: 'Lifestyle',
                              currentValue: lifestyle['lifestyle'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 3. Professional Details
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
                            label: "Profession",
                            value: display(professional['profession']),
                            onTap: () => _editPreference(
                              section: 'professionalDetails',
                              key: 'profession',
                              label: 'Profession',
                              currentValue: professional['profession'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                          _PreferenceRow(
                            label: "Annual Income",
                            value: display(professional['income']),
                            isLast: true,
                            onTap: () => _editPreference(
                              section: 'professionalDetails',
                              key: 'income',
                              label: 'Annual Income',
                              currentValue: professional['income'].toString(),
                              currentPrefs: currentPrefs,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 4. Location Details
                      _PreferenceCard(
                        title: "Location Details",
                        children: [
                          _PreferenceRow(
                            label: "Preferred Location",
                            value: display(location['country']),
                            isLast: true,
                            onTap: () => _editPreference(
                              section: 'locationDetails',
                              key: 'country',
                              label: 'Preferred Location',
                              currentValue: location['country'].toString(),
                              currentPrefs: currentPrefs,
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
                            await UserService.instance.updatePartnerPreferences(currentPrefs);
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
