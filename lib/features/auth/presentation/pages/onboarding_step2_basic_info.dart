import 'package:flutter/material.dart';
import 'package:swam_match_app/shared/helpers/age_helper.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';
import '../../../../shared/widgets/linear_message.dart';

class OnboardingStep2BasicInfo extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStep2BasicInfo({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingStep2BasicInfo> createState() =>
      _OnboardingStep2BasicInfoState();
}

class _OnboardingStep2BasicInfoState extends State<OnboardingStep2BasicInfo> {
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _countryCtrl;
  DateTime? _dateOfBirth;
  String? _gender;
  String _selectedReligion = '';
  List<String> _selectedLanguages = [];

  // Set once the user taps Continue with something missing: from then on
  // each missing required field is highlighted in red until it's filled.
  bool _showErrors = false;
  final _nameKey = GlobalKey();
  final _dobKey = GlobalKey();
  final _genderKey = GlobalKey();
  final _locationKey = GlobalKey();

  final List<String> _genders = ['Man', 'Woman', 'Non-binary'];

  final List<String> _availableLanguages = [
    'English',
    'Tamil',
    'Hindi',
    'Telugu',
    'Malayalam',
    'Kannada',
    'Gujarati',
    'Bengali',
    'Punjabi',
    'Marathi',
    'Spanish',
    'French',
    'Arabic',
  ];

  final List<String> _religions = [
    'Hindu',
    'Muslim',
    'Christian',
    'Sikh',
    'Buddhist',
    'Jain',
    'Spiritual',
    'Non-Religious',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.data.firstName);
    _lastNameCtrl = TextEditingController(text: widget.data.lastName);
    _cityCtrl = TextEditingController(text: widget.data.city);
    _stateCtrl = TextEditingController(text: widget.data.state);
    _countryCtrl = TextEditingController(text: widget.data.country);
    _dateOfBirth = widget.data.dateOfBirth;
    _gender = widget.data.gender.isNotEmpty ? widget.data.gender : null;
    _selectedReligion = widget.data.religion;

    // Load languages
    final langs = <String>{};
    if (widget.data.primaryLanguage.isNotEmpty) langs.add(widget.data.primaryLanguage);
    langs.addAll(widget.data.otherLanguages);
    _selectedLanguages = langs.toList();
    if (_selectedLanguages.isEmpty) _selectedLanguages = ['English'];
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  int? _calculateAge() {
    if (_dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - _dateOfBirth!.year;
    if (now.month < _dateOfBirth!.month ||
        (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDOB() async {
    // Latest selectable date = still 18+ today. The initial date must not be
    // after it (showDatePicker asserts), e.g. a DOB carried over from signup.
    final DateTime lastDate = defaultAdultDob();
    DateTime initialDate = _dateOfBirth ?? DateTime(2000, 1, 1);
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;
    if (initialDate.isBefore(DateTime(1940))) initialDate = DateTime(1940);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: OnboardingColors.primaryGold,
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  bool get _isValid {
    final fname = _firstNameCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final country = _countryCtrl.text.trim();
    final age = _calculateAge();
    return fname.isNotEmpty &&
        _dateOfBirth != null &&
        age != null &&
        age >= 18 &&
        _gender != null &&
        city.isNotEmpty &&
        country.isNotEmpty &&
        _selectedLanguages.isNotEmpty;
  }

  bool get _nameMissing => _firstNameCtrl.text.trim().isEmpty;
  bool get _dobMissing => _dateOfBirth == null || (_calculateAge() ?? 0) < 18;
  bool get _genderMissing => _gender == null;
  bool get _cityMissing => _cityCtrl.text.trim().isEmpty;
  bool get _countryMissing => _countryCtrl.text.trim().isEmpty;

  /// Tells the user exactly what is still missing (the Continue button used
  /// to just stay disabled, and many users couldn't tell why), highlights
  /// those fields and scrolls to the first one.
  void _showMissingFields() {
    final missing = <String>[
      if (_nameMissing) 'First Name',
      if (_dobMissing) 'Date of Birth',
      if (_genderMissing) 'Gender',
      if (_cityMissing) 'City',
      if (_countryMissing) 'Country',
      if (_selectedLanguages.isEmpty) 'Language',
    ];
    setState(() => _showErrors = true);
    showLinearMessage(
      context,
      'Please fill in: ${missing.join(', ')}',
      isError: true,
    );
    final firstKey = _nameMissing
        ? _nameKey
        : _dobMissing
            ? _dobKey
            : _genderMissing
                ? _genderKey
                : _locationKey;
    final target = firstKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    }
  }

  void _saveAndNext() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_isValid) {
      _showMissingFields();
      return;
    }
    widget.data.firstName = _firstNameCtrl.text.trim();
    widget.data.lastName = _lastNameCtrl.text.trim();
    widget.data.dateOfBirth = _dateOfBirth;
    widget.data.selectedAge = _calculateAge();
    widget.data.gender = _gender ?? '';
    widget.data.city = _cityCtrl.text.trim();
    widget.data.state = _stateCtrl.text.trim();
    widget.data.country = _countryCtrl.text.trim();
    widget.data.religion = _selectedReligion;

    if (_selectedLanguages.isNotEmpty) {
      widget.data.primaryLanguage = _selectedLanguages.first;
      widget.data.otherLanguages = _selectedLanguages.sublist(1);
    }

    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic Information',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tell us a little about yourself.',
            style: TextStyle(
              color: OnboardingColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // First Name & Last Name
          Row(
            key: _nameKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: UnderlineTextField(
                  label: 'First Name',
                  hint: 'John',
                  controller: _firstNameCtrl,
                  onChanged: (_) => setState(() {}),
                  errorText: _showErrors && _nameMissing ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: UnderlineTextField(
                  label: 'Last Name',
                  hint: 'Doe',
                  controller: _lastNameCtrl,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Date of Birth
          Text(
            'Date of Birth',
            key: _dobKey,
            style: const TextStyle(color: OnboardingColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDOB,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: OnboardingColors.fieldBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _showErrors && _dobMissing
                      ? Colors.redAccent
                      : _dateOfBirth != null
                          ? OnboardingColors.primaryGold
                          : OnboardingColors.unselectedBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: OnboardingColors.primaryGold, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _dateOfBirth != null
                        ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}  (${_calculateAge()} yrs)'
                        : 'Select Date of Birth',
                    style: TextStyle(
                      color: _dateOfBirth != null
                          ? OnboardingColors.textPrimary
                          : OnboardingColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showErrors && _dobMissing) ...[
            const SizedBox(height: 6),
            const Text(
              'Please select your date of birth (18+)',
              style: TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 24),

          // Gender
          Text(
            'Gender',
            key: _genderKey,
            style: const TextStyle(color: OnboardingColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _genders.map((g) {
              final isSelected = _gender == g;
              return GoldChip(
                label: g,
                selected: isSelected,
                onTap: () => setState(() => _gender = g),
              );
            }).toList(),
          ),
          if (_showErrors && _genderMissing) ...[
            const SizedBox(height: 6),
            const Text(
              'Please select your gender',
              style: TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 24),

          // Location
          Row(
            key: _locationKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: UnderlineTextField(
                  label: 'City',
                  hint: 'New York',
                  controller: _cityCtrl,
                  onChanged: (_) => setState(() {}),
                  errorText: _showErrors && _cityMissing ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: UnderlineTextField(
                  label: 'State (Opt.)',
                  hint: 'NY',
                  controller: _stateCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: UnderlineTextField(
                  label: 'Country',
                  hint: 'USA',
                  controller: _countryCtrl,
                  onChanged: (_) => setState(() {}),
                  errorText: _showErrors && _countryMissing ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Languages Spoken (Multi-select Chips)
          const Text(
            'Languages Spoken (Select all that apply)',
            style: TextStyle(color: OnboardingColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableLanguages.map((lang) {
              final selected = _selectedLanguages.contains(lang);
              return GoldChip(
                label: lang,
                selected: selected,
                showCheckmark: true,
                onTap: () {
                  setState(() {
                    if (selected) {
                      if (_selectedLanguages.length > 1) {
                        _selectedLanguages.remove(lang);
                      }
                    } else {
                      _selectedLanguages.add(lang);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Religion (Optional)
          Row(
            children: [
              const Text(
                'Religion',
                style: TextStyle(color: OnboardingColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(width: 6),
              Text(
                '(Optional)',
                style: TextStyle(
                  color: OnboardingColors.primaryGold.withOpacity(0.8),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _religions.map((rel) {
              final selected = _selectedReligion == rel;
              return GoldChip(
                label: rel,
                selected: selected,
                onTap: () {
                  setState(() {
                    _selectedReligion = selected ? '' : rel;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 36),

          // Always tappable: a greyed-out button gave no hint about what was
          // missing. Tapping with gaps lists and highlights them instead.
          NextButton(
            label: 'Continue',
            onPressed: _saveAndNext,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
