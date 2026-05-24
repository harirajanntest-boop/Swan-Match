import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

class OnboardingStep1Identity extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;

  const OnboardingStep1Identity({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<OnboardingStep1Identity> createState() =>
      _OnboardingStep1IdentityState();
}

class _OnboardingStep1IdentityState extends State<OnboardingStep1Identity> {
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _countryCtrl;
  DateTime? _dateOfBirth;
  String? _gender;
  final ImagePicker _picker = ImagePicker();
  List<String> _localPhotos = [];
  bool _termsAccepted = false;

  final List<String> _genders = [
    'Man',
    'Woman',
    'Non-binary',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.data.firstName);
    _lastNameCtrl = TextEditingController(text: widget.data.lastName);
    _cityCtrl = TextEditingController(text: widget.data.city);
    _countryCtrl = TextEditingController(text: widget.data.country);
    _termsAccepted = widget.data.termsAccepted;
    _dateOfBirth = widget.data.dateOfBirth;
    _gender = widget.data.gender.isNotEmpty ? widget.data.gender : null;
    if (widget.data.photos.isNotEmpty) {
      _localPhotos = List<String>.from(widget.data.photos);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  int? _calculateAge() {
    if (_dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - _dateOfBirth!.year;
    if (now.month < _dateOfBirth!.month ||
        (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day))
      age--;
    return age;
  }

  Future<void> _pickDOB() async {
    // If DOB is already set from the sign-up flow, prevent changing it
    if (widget.data.dateOfBirth != null) {
      _showError('Date of birth cannot be changed after registration.');
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(
        const Duration(days: 6570),
      ), // ~18 years
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
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _pickImage() async {
    if (_localPhotos.length >= 6) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1080,
      );
      if (image != null) setState(() => _localPhotos.add(image.path));
    } catch (_) {}
  }

  void _removePhoto(int index) => setState(() => _localPhotos.removeAt(index));

  void _handleNext() {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final country = _countryCtrl.text.trim();
    final age = _calculateAge();

    if (firstName.length < 2) {
      _showError('Please enter your first name (at least 2 characters)');
      return;
    }
    if (_dateOfBirth == null || age == null || age < 18) {
      _showError('Please select your date of birth (must be 18+)');
      return;
    }
    if (_gender == null) {
      _showError('Please select your gender');
      return;
    }
    if (city.isEmpty || country.isEmpty) {
      _showError('Please enter your city and country');
      return;
    }
    if (_localPhotos.length < 3) {
      _showError('Please upload at least 3 photos');
      return;
    }
    if (!_termsAccepted) {
      _showError('You must accept the Terms of Service and Privacy Policy');
      return;
    }

    // Save to data
    widget.data.firstName = firstName;
    widget.data.lastName = lastName;
    widget.data.dateOfBirth = _dateOfBirth;
    widget.data.selectedAge = age;
    widget.data.gender = _gender!;
    widget.data.city = city;
    widget.data.country = country;
    widget.data.termsAccepted = _termsAccepted;
    widget.data.photos = List<String>.from(_localPhotos);
    widget.data.profilePicture = _localPhotos.isNotEmpty
        ? _localPhotos.first
        : '';

    widget.onNext();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch link.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not launch link.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final age = _calculateAge();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Basic Identity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tell us about yourself',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name fields
                  Row(
                    children: [
                      Expanded(
                        child: PremiumTextField(
                          label: 'FIRST NAME',
                          hint: 'First name',
                          controller: _firstNameCtrl,
                          maxLength: 50,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PremiumTextField(
                          label: 'LAST NAME',
                          hint: 'Last name',
                          controller: _lastNameCtrl,
                          maxLength: 50,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Date of Birth
                  GestureDetector(
                    onTap: _pickDOB,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: OnboardingColors.fieldBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DATE OF BIRTH',
                                  style: TextStyle(
                                    color: OnboardingColors.primaryGold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _dateOfBirth != null
                                      ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                                      : 'Select your date of birth',
                                  style: TextStyle(
                                    color: _dateOfBirth != null
                                        ? Colors.white
                                        : Colors.white38,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (age != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: OnboardingColors.primaryGold.withOpacity(
                                  0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Age $age',
                                style: const TextStyle(
                                  color: OnboardingColors.primaryGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white38,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Gender
                  const SectionTitle(title: 'Gender'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _genders
                        .map(
                          (g) => GoldChip(
                            label: g,
                            selected: _gender == g,
                            onTap: () => setState(() => _gender = g),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),

                  // Location
                  Row(
                    children: [
                      Expanded(
                        child: PremiumTextField(
                          label: 'CITY',
                          hint: 'Your city',
                          controller: _cityCtrl,
                          maxLength: 100,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PremiumTextField(
                          label: 'COUNTRY',
                          hint: 'Your country',
                          controller: _countryCtrl,
                          maxLength: 100,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Verified Phone & Email (read-only)
                  if (widget.data.phone.isNotEmpty)
                    PremiumTextField(
                      label: 'PHONE',
                      hint: '',
                      controller: TextEditingController(
                        text: widget.data.phone,
                      ),
                      readOnly: true,
                      suffix: const VerifiedBadge(),
                    ),
                  if (widget.data.phone.isNotEmpty) const SizedBox(height: 14),
                  if (widget.data.email.isNotEmpty)
                    PremiumTextField(
                      label: 'EMAIL',
                      hint: '',
                      controller: TextEditingController(
                        text: widget.data.email,
                      ),
                      readOnly: true,
                      suffix: const VerifiedBadge(),
                    ),
                  if (widget.data.email.isNotEmpty) const SizedBox(height: 18),

                  // Photos
                  SectionTitle(
                    title: 'Profile Photos',
                    subtitle:
                        'Upload at least 3 high-quality photos (${_localPhotos.length}/6)',
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      if (index < _localPhotos.length) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _localPhotos[index].startsWith('http')
                                  ? Image.network(
                                      _localPhotos[index],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    )
                                  : Image.file(
                                      File(_localPhotos[index]),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removePhoto(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            if (index == 0)
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: OnboardingColors.primaryGold,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Profile',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }
                      return GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: OnboardingColors.fieldBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: index < 3
                                  ? OnboardingColors.primaryGold.withOpacity(
                                      0.3,
                                    )
                                  : Colors.white12,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: index < 3
                                    ? OnboardingColors.primaryGold.withOpacity(
                                        0.5,
                                      )
                                    : Colors.white24,
                                size: 28,
                              ),
                              if (index < 3) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Required',
                                  style: TextStyle(
                                    color: OnboardingColors.primaryGold
                                        .withOpacity(0.5),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Terms & Conditions Checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _termsAccepted,
                          onChanged: (val) => setState(() => _termsAccepted = val ?? false),
                          activeColor: OnboardingColors.primaryGold,
                          checkColor: Colors.black,
                          side: const BorderSide(color: Colors.white54, width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'I agree to the ',
                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                            children: [
                              TextSpan(
                                text: 'Terms of Service',
                                style: const TextStyle(color: OnboardingColors.primaryGold, decoration: TextDecoration.underline),
                                recognizer: TapGestureRecognizer()..onTap = () => _launchUrl('https://www.swan-match.com/terms'),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(color: OnboardingColors.primaryGold, decoration: TextDecoration.underline),
                                recognizer: TapGestureRecognizer()..onTap = () => _launchUrl('https://www.swan-match.com/privacy'),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          NextButton(label: 'Next', onPressed: _handleNext, enabled: true),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
