import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';
import '../../../../models/onboarding_data.dart';

// SCREEN 1: First Name
class FirstNameScreen extends StatefulWidget {
  final OnboardingData data;
  final Function(String) onNext;

  const FirstNameScreen({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<FirstNameScreen> createState() => _FirstNameScreenState();
}

class _FirstNameScreenState extends State<FirstNameScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.data.firstName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isNextEnabled => _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              
              // Skip Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40), // Balance for back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: OnboardingColors.skipButton,
                      size: 24,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Title
              const Text(
                "What's your first name?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: OnboardingColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Text Field
              UnderlineTextField(
                controller: _controller,
                hint: "Your name",
                onChanged: (value) {
                  setState(() {});
                },
              ),
              
              const SizedBox(height: 16),
              
              // Helper Text
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: OnboardingColors.textSecondary,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: "This is how it'll appear on your profile. "),
                    const TextSpan(
                      text: "Can't change it later.",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OnboardingColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Next Button
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: NextButton(
                  label: "Next",
                  enabled: _isNextEnabled,
                  onPressed: () => widget.onNext(_controller.text.trim()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// SCREEN 2: Date of Birth
class DateOfBirthScreen extends StatefulWidget {
  final OnboardingData data;
  final Function(DateTime) onNext;

  const DateOfBirthScreen({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<DateOfBirthScreen> createState() => _DateOfBirthScreenState();
}

class _DateOfBirthScreenState extends State<DateOfBirthScreen> {
  DateTime? _selectedDate;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.data.dateOfBirth;
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
      _showError = false;
    });
  }

  void _validateAndProceed() {
    if (_selectedDate != null) {
      final now = DateTime.now();
      int age = now.year - _selectedDate!.year;
      
      if (now.month < _selectedDate!.month || 
          (now.month == _selectedDate!.month && now.day < _selectedDate!.day)) {
        age--;
      }
      
      if (age >= 18) {
        widget.onNext(_selectedDate!);
      } else {
        setState(() {
          _showError = true;
        });
      }
    }
  }

  String get _formattedDate {
    if (_selectedDate == null) return 'Select your date of birth';
    return '${_selectedDate!.day.toString().padLeft(2, '0')}/'
           '${_selectedDate!.month.toString().padLeft(2, '0')}/'
           '${_selectedDate!.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? DateTime(now.year - 25);
    final minimumDate = DateTime(now.year - 100);
    final maximumDate = DateTime(now.year - 18, now.month, now.day);

    return Scaffold(
      backgroundColor: OnboardingColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.arrow_back,
                        color: OnboardingColors.textPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 40),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.close,
                        color: OnboardingColors.skipButton,
                        size: 24,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Title
                const Text(
                  "Your date of birth?",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: OnboardingColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 32),

                // Scrollable Date Picker
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: OnboardingColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedDate != null
                          ? OnboardingColors.primaryGold
                          : OnboardingColors.unselectedBorder,
                      width: _selectedDate != null ? 2 : 1,
                    ),
                  ),
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: Brightness.dark,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          color: OnboardingColors.textPrimary,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: initialDate,
                      minimumDate: minimumDate,
                      maximumDate: maximumDate,
                      onDateTimeChanged: _onDateChanged,
                      dateOrder: DatePickerDateOrder.dmy,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Helper Text
                const Text(
                  "Your profile shows your age, not your birth date.",
                  style: TextStyle(
                    fontSize: 14,
                    color: OnboardingColors.textSecondary,
                  ),
                ),

                // Error Text
                if (_showError) ...[
                  const SizedBox(height: 8),
                  const Text(
                    "You must be at least 18 years old to use Swan Match.",
                    style: TextStyle(
                      fontSize: 14,
                      color: OnboardingColors.primaryGold,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Next Button
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: NextButton(
                    label: "Next",
                    enabled: _selectedDate != null && !_showError,
                    onPressed: _validateAndProceed,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// SCREEN 3: Gender
class GenderScreen extends StatefulWidget {
  final OnboardingData data;
  final Function(String) onNext;

  const GenderScreen({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String _selectedGender = '';

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.data.gender;
  }

  final List<String> _genders = ['Male', 'Female', 'Prefer not to say'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: OnboardingColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 40),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: OnboardingColors.skipButton,
                      size: 24,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Title
              const Text(
                "What's your gender?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: OnboardingColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Subtitle
              const Text(
                "This helps us show your profile to the right people.",
                style: TextStyle(
                  fontSize: 16,
                  color: OnboardingColors.textSecondary,
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Gender Cards
              ..._genders.map((gender) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGender = gender;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _selectedGender == gender 
                          ? OnboardingColors.primaryGold.withOpacity(0.1)
                          : OnboardingColors.cardBackground,
                      border: Border.all(
                        color: _selectedGender == gender 
                            ? OnboardingColors.selectedBorder
                            : OnboardingColors.unselectedBorder,
                        width: _selectedGender == gender ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          gender,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: OnboardingColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedGender == gender)
                          Icon(
                            Icons.check,
                            color: OnboardingColors.primaryGold,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              )).toList(),

              const SizedBox(height: 24),

              const Spacer(),

              // Next Button
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: NextButton(
                  label: "Next",
                  enabled: _selectedGender.isNotEmpty,
                  onPressed: () => widget.onNext(_selectedGender),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// SCREEN 4: Partner Preference
class PartnerPreferenceScreen extends StatefulWidget {
  final OnboardingData data;
  final Function(String) onNext;

  const PartnerPreferenceScreen({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<PartnerPreferenceScreen> createState() => _PartnerPreferenceScreenState();
}

class _PartnerPreferenceScreenState extends State<PartnerPreferenceScreen> {
  String _selectedPreference = '';

  @override
  void initState() {
    super.initState();
    _selectedPreference = widget.data.partnerPreference;
  }

  final List<String> _preferences = ['Men', 'Women', 'Everyone'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: OnboardingColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 40),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: OnboardingColors.skipButton,
                      size: 24,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Title
              const Text(
                "Who are you looking to match with?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: OnboardingColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Subtitle
              const Text(
                "Select to help us find the right profiles for you.",
                style: TextStyle(
                  fontSize: 16,
                  color: OnboardingColors.textSecondary,
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Preference Cards
              ..._preferences.map((preference) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPreference = preference;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _selectedPreference == preference 
                            ? OnboardingColors.primaryGold.withOpacity(0.1)
                            : OnboardingColors.cardBackground,
                      border: Border.all(
                        color: _selectedPreference == preference 
                              ? OnboardingColors.selectedBorder
                              : OnboardingColors.unselectedBorder,
                        width: _selectedPreference == preference ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          preference,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: OnboardingColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedPreference == preference)
                          Icon(
                            Icons.check,
                            color: OnboardingColors.primaryGold,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              )).toList(),
              
              const Spacer(),
              
              // Next Button
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: NextButton(
                  label: "Next",
                  enabled: _selectedPreference.isNotEmpty,
                  onPressed: () => widget.onNext(_selectedPreference),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// SCREEN 5: Location
class LocationScreen extends StatefulWidget {
  final OnboardingData data;
  final Function(String, String, String) onNext;

  const LocationScreen({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String _selectedCountry = '';
  String _selectedState = '';
  String _selectedCity = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with existing data if available
    _selectedCountry = widget.data.country;
    _selectedState = widget.data.state;
    _selectedCity = widget.data.city;
  }

  bool get _isNextEnabled => _selectedCountry.isNotEmpty && 
                           _selectedState.isNotEmpty && 
                           _selectedCity.isNotEmpty;

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled. Please enable them.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _selectedCountry = place.country ?? '';
          _selectedState = place.administrativeArea ??
                         place.subAdministrativeArea ??
                         place.locality ??
                         '';
          _selectedCity = place.locality ??
                        place.subAdministrativeArea ??
                        place.subLocality ??
                        '';
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: OnboardingColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 40),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: OnboardingColors.skipButton,
                      size: 24,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Title
              const Text(
                "Where are you from?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: OnboardingColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 32),

              // GPS Location Picker - Modern UI
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (_isNextEnabled)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location Icon with Gradient
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            OnboardingColors.primaryGold.withOpacity(0.2),
                            OnboardingColors.primaryGold.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: OnboardingColors.primaryGold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedCity,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: OnboardingColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "$_selectedState, $_selectedCountry",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: OnboardingColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Refresh Button
                    OutlinedButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text("Refresh Location"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OnboardingColors.primaryGold,
                        side: const BorderSide(color: OnboardingColors.primaryGold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                )
              else
                // Get Location Button
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        OnboardingColors.primaryGold,
                        OnboardingColors.primaryGold.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: OnboardingColors.primaryGold.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _getCurrentLocation,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Use GPS Location",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              
              // Helper Text
              const Text(
                "Helps us show you relevant matches nearby.",
                style: TextStyle(
                  fontSize: 14,
                  color: OnboardingColors.textSecondary,
                ),
              ),
              
              const Spacer(),
              
              // Next Button
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: NextButton(
                  label: "Next",
                  enabled: _isNextEnabled,
                  onPressed: () => widget.onNext(
                    _selectedCountry!,
                    _selectedState!,
                    _selectedCity!,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
