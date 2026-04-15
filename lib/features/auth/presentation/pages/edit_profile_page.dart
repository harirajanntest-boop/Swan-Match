import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/storage_service.dart';
import '../../../../services/user_service.dart';
import '../../../../services/auth_service.dart';
import 'otp_verification_page.dart';
import '../../../../shared/widgets/linear_message.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Track which accordion is currently open
  String? _expandedSection = 'Basic Details';
  bool _isUploadingPhoto = false;

  final Map<String, IconData> _sectionIcons = {
    "Basic Details": Icons.person_outline,
    "Religious Information": Icons.menu_book_outlined,
    "Professional Information": Icons.work_outline,
    "Location": Icons.location_on_outlined,
    "Family Details": Icons.family_restroom_outlined,
  };

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.1, 1.0, curve: Curves.easeOut)));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)));

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
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.goldMedium, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.white, fontFamily: 'serif', letterSpacing: 1, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: UserService.instance.watchCurrentUserProfile(),
        builder: (context, snapshot) {
          final profile = snapshot.data ?? <String, dynamic>{};
          final profileData = _buildProfileData(profile);
          final aboutMe = (profile['aboutMe'] ?? '').toString().trim();

          return FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Column(
                        children: [
                          _buildProgressHeader(profile),
                          _buildQuickActions(profile),
                          _buildBioSection(aboutMe),
                          const SizedBox(height: 20),
                          ...profileData.keys.map((sectionName) {
                            return _PremiumAccordion(
                              title: sectionName,
                              icon: _sectionIcons[sectionName]!,
                              data: profileData[sectionName]!,
                              isOpen: _expandedSection == sectionName,
                              onEdit: (label, value) => _editProfileField(
                                profile: profile,
                                section: sectionName,
                                label: label,
                                currentValue: value,
                              ),
                              onTap: () {
                                setState(() {
                                  _expandedSection = _expandedSection == sectionName ? null : sectionName;
                                });
                              },
                            );
                          }),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editContact(Map<String, dynamic> profile) async {
    final phoneController = TextEditingController(
      text: (profile['phoneNumber'] ?? '').toString(),
    );
    final emailController = TextEditingController(
      text: (profile['email'] ?? '').toString(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.onyx,
          title: const Text('Edit Contact', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save', style: TextStyle(color: AppColors.goldMedium)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final currentPhone = (profile['phoneNumber'] ?? '').toString();
    final currentEmail = (profile['email'] ?? '').toString();

    final newPhoneRaw = phoneController.text.trim();
    final newEmailRaw = emailController.text.trim();

    final emailChanged = newEmailRaw.isNotEmpty && newEmailRaw != currentEmail;
    final phoneChanged = newPhoneRaw.isNotEmpty && newPhoneRaw != currentPhone;

    try {
      if (emailChanged) {
        try {
          await AuthService.instance.updateEmail(newEmailRaw);
        } on FirebaseAuthException catch (error) {
          if (error.code == 'requires-recent-login') {
            final reauthed = await _reauthenticateForEmailUpdate(profile);
            if (!reauthed) return;
            await AuthService.instance.updateEmail(newEmailRaw);
          } else {
            rethrow;
          }
        }

        final authEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        if (authEmail.isEmpty || authEmail.toLowerCase() != newEmailRaw.toLowerCase()) {
          showLinearMessage(
            context,
            'Email update pending verification. Please verify the email before it updates in your profile.',
            isError: true,
          );
          return;
        }

        await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
          'email': authEmail,
        });
      }

      if (phoneChanged) {
        final formattedPhone = AuthService.instance.normalizePhoneE164(
          newPhoneRaw,
          defaultCountryCode: '+1',
        );

        await AuthService.instance.sendOtp(phoneNumber: formattedPhone);

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationPage(
              flowType: OtpFlowType.updatePhone,
              phoneNumber: formattedPhone,
              otpDeliveryChannel: OtpDeliveryChannel.sms,
              destination: formattedPhone,
            ),
          ),
        );
      }

      if (!mounted) return;
      if (!emailChanged && !phoneChanged) {
        showLinearMessage(context, 'No changes to update.');
      } else if (!phoneChanged) {
        showLinearMessage(context, 'Contact details updated.');
      }
    } catch (error) {
      if (!mounted) return;
      showLinearMessage(
        context,
        AuthService.instance.readableAuthError(error),
        isError: true,
      );
    }
  }

  Future<bool> _reauthenticateForEmailUpdate(Map<String, dynamic> profile) async {
    final linkedIds = AuthService.instance.getLinkedProviderIds();

    if (linkedIds.contains('password')) {
      final password = await _promptPassword();
      if (password == null || password.isEmpty) return false;
      await AuthService.instance.reauthenticateWithPassword(password);
      return true;
    }

    if (linkedIds.contains('google.com')) {
      await AuthService.instance.reauthenticateWithGoogle();
      return true;
    }

    if (linkedIds.contains('phone')) {
      final currentPhone = (profile['phoneNumber'] ?? '').toString();
      if (currentPhone.isEmpty) {
        showLinearMessage(context, 'We could not find your phone number. Please contact support.', isError: true);
        return false;
      }

      await AuthService.instance.sendOtp(phoneNumber: currentPhone);
      if (!mounted) return false;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationPage(
            flowType: OtpFlowType.reauthPhone,
            phoneNumber: currentPhone,
            otpDeliveryChannel: OtpDeliveryChannel.sms,
            destination: currentPhone,
          ),
        ),
      );

      return result == true;
    }

    showLinearMessage(context, 'Please connect at least one login method (Google, Phone, or Email) before making changes.', isError: true);
    return false;
  }

  Future<String?> _promptPassword() async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.onyx,
        title: const Text('Confirm Password', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm', style: TextStyle(color: AppColors.goldMedium)),
          ),
        ],
      ),
    );

    if (confirmed != true) return null;
    return controller.text.trim();
  }

  Future<void> _manageHoroscope(Map<String, dynamic> profile) async {
    final starController = TextEditingController(text: (profile['star'] ?? '').toString());
    final rassiController = TextEditingController(text: (profile['rassi'] ?? '').toString());
    final doshamController = TextEditingController(text: (profile['dosham'] ?? '').toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.onyx,
          title: const Text('Manage Horoscope', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: starController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Star',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rassiController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Rassi',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: doshamController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Dosham',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save', style: TextStyle(color: AppColors.goldMedium)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
      'star': starController.text.trim(),
      'rassi': rassiController.text.trim(),
      'dosham': doshamController.text.trim(),
    });

    if (!mounted) return;
    setState(() => _expandedSection = 'Religious Information');
    showLinearMessage(context, 'Horoscope details updated.');
  }

  Future<void> _uploadProfilePhoto(Map<String, dynamic> profile) async {
    if (_isUploadingPhoto) return;

    final uid = (profile['uid'] ?? '').toString();
    if (uid.isEmpty) {
      showLinearMessage(context, 'Your session has expired. Please log out and log back in.', isError: true);
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1440,
    );
    if (file == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final photoUrl = await StorageService.instance.uploadProfilePhoto(
        uid: uid,
        file: file.path.isEmpty ? throw Exception('Invalid selected file') : File(file.path),
      );

      await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
        'photoUrl': photoUrl,
      });

      if (!mounted) return;
      showLinearMessage(context, 'Profile photo updated successfully.');
    } catch (_) {
      if (!mounted) return;
      showLinearMessage(context, 'Failed to upload photo. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _deleteProfilePhoto(Map<String, dynamic> profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.onyx,
        title: const Text("Delete Photo?", style: TextStyle(color: Colors.white)),
        content: const Text("Your profile will look better with a photo. Are you sure?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirmed != true) return;

    setState(() => _isUploadingPhoto = true);
    try {
      await UserService.instance.updateCurrentUserProfile({'photoUrl': null});
      if (!mounted) return;
      showLinearMessage(context, 'Profile photo removed.');
    } catch (e) {
      if (!mounted) return;
      showLinearMessage(context, 'Failed to delete photo.', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ─── Sub-Components ───

  String _cleanValue(String value) {
    if (value.contains('+ Add Details') || value.contains('Not Specified')) {
      return '';
    }
    return value;
  }

  List<String> _optionsForField(String section, String label) {
    if (section == 'Basic Details') {
      switch (label) {
        case 'Gender':
          return const ['Male', 'Female', 'Other'];
        case 'Marital Status':
          return const ['Never married', 'Divorced', 'Widowed', 'Awaiting divorce'];
        case 'Physical Status':
          return const ['Normal', 'Physically Challenged'];
        case 'Body Type':
          return const ['Slim', 'Average', 'Athletic', 'Heavy'];
        case 'Profile Created by':
          return const ['Self', 'Parents', 'Sibling', 'Relative', 'Friend'];
        case 'Eating Habits':
          return const ['Vegetarian', 'Non Vegetarian', 'Eggetarian', 'Vegan'];
        case 'Drinking Habits':
          return const ['Never', 'Occasionally', 'Regularly'];
        case 'Smoking Habits':
          return const ['Never', 'Occasionally', 'Regularly'];
      }
    }

    if (section == 'Religious Information') {
      switch (label) {
        case 'Religion':
          return const ['Hindu', 'Muslim', 'Christian', 'Sikh', 'Jain', 'Buddhist', 'Other'];
        case 'Having Dosham?':
          return const ['Yes', 'No', "Don't know"];
      }
    }

    if (section == 'Family Details') {
      switch (label) {
        case 'Family Values':
          return const ['Traditional', 'Moderate', 'Liberal'];
        case 'Family Type':
          return const ['Joint Family', 'Nuclear Family'];
        case 'Family Status':
          return const ['Middle Class', 'Upper Middle Class', 'Rich / Affluent'];
      }
    }

    return const <String>[];
  }

  Future<String?> _chooseOrTypeValue({
    required String title,
    required String initial,
    required List<String> options,
    bool multiLine = false,
  }) async {
    final controller = TextEditingController(text: initial);

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
                      maxLines: multiLine ? 5 : 1,
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

  Future<void> _editProfileField({
    required Map<String, dynamic> profile,
    required String section,
    required String label,
    required String currentValue,
  }) async {
    final initial = _cleanValue(currentValue);
    final updated = await _chooseOrTypeValue(
      title: label,
      initial: initial,
      options: _optionsForField(section, label),
      multiLine: label == 'In My Own Words',
    );

    if (updated == null) return;

    final updates = <String, dynamic>{};
    final map = _fieldMap(section, label);
    final key = map['key'] as String?;
    final nested = map['nested'] as String?;

    if (key == null) return;

    if (nested != null) {
      final existing = profile[nested];
      final nextNested = existing is Map<String, dynamic>
          ? Map<String, dynamic>.from(existing)
          : existing is Map
              ? Map<String, dynamic>.from(existing)
              : <String, dynamic>{};
      nextNested[key] = updated;
      updates[nested] = nextNested;
    } else {
      updates[key] = updated;
    }

    await UserService.instance.updateCurrentUserProfile(updates);
  }

  Map<String, Object?> _fieldMap(String section, String label) {
    if (section == 'Bio' && label == 'In My Own Words') {
      return {'key': 'aboutMe'};
    }

    if (section == 'Basic Details') {
      switch (label) {
        case 'Name':
          return {'key': 'name'};
        case 'Gender':
          return {'key': 'gender'};
        case 'Age':
          return {'key': 'age'};
        case 'Height':
          return {'key': 'height'};
        case 'Weight':
          return {'key': 'weight'};
        case 'Marital Status':
          return {'key': 'maritalStatus'};
        case 'Mother Tongue':
          return {'key': 'motherTongue'};
        case 'Physical Status':
          return {'key': 'physicalStatus'};
        case 'Body Type':
          return {'key': 'bodyType'};
        case 'Profile Created by':
          return {'key': 'profileFor'};
        case 'Eating Habits':
          return {'key': 'eatingHabits', 'nested': 'lifestyle'};
        case 'Drinking Habits':
          return {'key': 'drinkingHabits', 'nested': 'lifestyle'};
        case 'Smoking Habits':
          return {'key': 'smokingHabits', 'nested': 'lifestyle'};
      }
    }

    if (section == 'Religious Information') {
      switch (label) {
        case 'Religion':
          return {'key': 'religion'};
        case 'Caste':
          return {'key': 'caste'};
        case 'Sub caste':
          return {'key': 'subCaste'};
        case 'Gothram':
          return {'key': 'gothram'};
        case 'Zodiac':
          return {'key': 'zodiac'};
        case 'Star':
          return {'key': 'star'};
        case 'Rassi':
          return {'key': 'rassi'};
        case 'Having Dosham?':
          return {'key': 'dosham'};
      }
    }

    if (section == 'Professional Information') {
      switch (label) {
        case 'Education':
          return {'key': 'educationDegree'};
        case 'College / Institution':
          return {'key': 'collegeName'};
        case 'Occupation':
          return {'key': 'occupation'};
        case 'Employed In':
          return {'key': 'employmentSector'};
        case 'Annual Income':
          return {'key': 'annualIncome'};
      }
    }

    if (section == 'Location') {
      switch (label) {
        case 'Country':
          return {'key': 'country'};
        case 'State':
          return {'key': 'state'};
        case 'City':
          return {'key': 'city'};
        case 'Citizenship':
          return {'key': 'citizenship'};
      }
    }

    if (section == 'Family Details') {
      switch (label) {
        case 'Family Values':
          return {'key': 'familyValues'};
        case 'Family Type':
          return {'key': 'familyType'};
        case 'Family Status':
          return {'key': 'familyStatus'};
        case 'Father Occupation':
          return {'key': 'fatherOccupation'};
        case 'Mother Occupation':
          return {'key': 'motherOccupation'};
      }
    }

    return {'key': null};
  }

  Map<String, Map<String, String>> _buildProfileData(Map<String, dynamic> profile) {
    final lifestyleRaw = profile['lifestyle'];
    final lifestyle = lifestyleRaw is Map<String, dynamic>
        ? lifestyleRaw
        : lifestyleRaw is Map
            ? Map<String, dynamic>.from(lifestyleRaw)
            : <String, dynamic>{};

    String value(String key, {String fallback = '+ Add Details'}) {
      final raw = profile[key];
      if (raw == null) return fallback;
      final text = raw.toString().trim();
      return text.isEmpty ? fallback : text;
    }

    String lifestyleValue(String key) {
      final raw = lifestyle[key];
      if (raw == null) return '+ Add Details';
      final text = raw.toString().trim();
      return text.isEmpty ? '+ Add Details' : text;
    }

    return {
      "Basic Details": {
        "Name": value('name', fallback: 'Member'),
        "Gender": value('gender'),
        "Age": _formatAge(profile['dateOfBirth'], fallbackAge: profile['age']),
        "Height": value('height'),
        "Weight": value('weight'),
        "Marital Status": value('maritalStatus'),
        "Mother Tongue": value('motherTongue'),
        "Physical Status": value('physicalStatus'),
        "Body Type": value('bodyType'),
        "Profile Created by": value('profileFor', fallback: 'Self'),
        "Eating Habits": lifestyleValue('eatingHabits'),
        "Drinking Habits": lifestyleValue('drinkingHabits'),
        "Smoking Habits": lifestyleValue('smokingHabits'),
      },
      "Religious Information": {
        "Religion": value('religion'),
        "Caste": value('caste'),
        "Sub caste": value('subCaste'),
        "Gothram": value('gothram'),
        "Zodiac": value('zodiac'),
        "Star": value('star'),
        "Rassi": value('rassi'),
        "Having Dosham?": value('dosham', fallback: "Don't know"),
      },
      "Professional Information": {
        "Education": value('educationDegree'),
        "College / Institution": value('collegeName'),
        "Occupation": value('occupation'),
        "Employed In": value('employmentSector'),
        "Annual Income": value('annualIncome'),
      },
      "Location": {
        "Country": value('country'),
        "State": value('state'),
        "City": value('city'),
        "Citizenship": value('citizenship', fallback: value('country', fallback: '+ Add Details')),
      },
      "Family Details": {
        "Family Values": value('familyValues', fallback: 'Not Specified'),
        "Family Type": value('familyType', fallback: 'Not Specified'),
        "Family Status": value('familyStatus', fallback: 'Not Specified'),
        "Father Occupation": value('fatherOccupation'),
        "Mother Occupation": value('motherOccupation'),
      }
    };
  }

  String _formatAge(dynamic rawDob, {dynamic fallbackAge}) {
    DateTime? dob;
    if (rawDob is DateTime) {
      dob = rawDob;
    } else if (rawDob != null && rawDob.runtimeType.toString() == 'Timestamp') {
      try {
        dob = rawDob.toDate() as DateTime;
      } catch (_) {
        dob = null;
      }
    }

    if (dob == null) {
      final fallback = (fallbackAge ?? '').toString().trim();
      return fallback.isEmpty ? '+ Add Details' : fallback;
    }

    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return '$age';
  }

  Widget _buildProgressHeader(Map<String, dynamic> profile) {
    final progress = UserService.instance.calculateProfileCompletion(profile);
    final progressValue = progress;
    final progressLabel = '${(progress * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Profile Completeness", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(progressLabel, style: TextStyle(color: AppColors.goldMedium.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.goldMedium),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(Map<String, dynamic> profile) {
    final photoUrl = (profile['photoUrl'] ?? '').toString();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _QuickActionPill(
            icon: _isUploadingPhoto ? Icons.hourglass_top : Icons.camera_alt_outlined,
            label: _isUploadingPhoto ? "Uploading..." : "Add Photo",
            isHighlight: true,
            onTap: _isUploadingPhoto ? null : () => _uploadProfilePhoto(profile),
          ),
          _QuickActionPill(
            icon: Icons.contact_phone_outlined,
            label: "Edit Contact",
            onTap: () => _editContact(profile),
          ),
          _QuickActionPill(
            icon: Icons.explore_outlined,
            label: "Manage Horoscope",
            onTap: () => _manageHoroscope(profile),
          ),
          if (photoUrl.isNotEmpty)
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  margin: const EdgeInsets.only(left: 4, right: 8),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.goldMedium.withOpacity(0.6)),
                  ),
                  child: ClipOval(
                    child: Image.network(photoUrl, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _deleteProfilePhoto(profile),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 10),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBioSection(String aboutMe) {
    final bio = aboutMe.isEmpty ? 'Add a short introduction about yourself.' : aboutMe;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _editProfileField(
          profile: <String, dynamic>{'aboutMe': aboutMe},
          section: 'Bio',
          label: 'In My Own Words',
          currentValue: aboutMe,
        ),
        child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.goldMedium.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.goldMedium.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_note, color: AppColors.goldMedium, size: 20),
                    SizedBox(width: 8),
                    Text("In My Own Words", style: TextStyle(color: AppColors.goldLight, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                  ],
                ),
                Icon(Icons.edit, color: Colors.white.withOpacity(0.3), size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              bio,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ─── Custom Animated Glassmorphic Accordion ───
class _PremiumAccordion extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, String> data;
  final bool isOpen;
  final VoidCallback onTap;
  final void Function(String label, String value) onEdit;

  const _PremiumAccordion({
    required this.title,
    required this.icon,
    required this.data,
    required this.isOpen,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isOpen ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpen ? AppColors.goldMedium.withOpacity(0.4) : Colors.white.withOpacity(0.05),
        ),
        boxShadow: isOpen ? [BoxShadow(color: AppColors.goldMedium.withOpacity(0.05), blurRadius: 20)] : [],
      ),
      child: Column(
        children: [
          // Header (Clickable)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(icon, color: isOpen ? AppColors.goldMedium : Colors.white54, size: 22),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isOpen ? AppColors.goldLight : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0, // Rotates the arrow
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Content
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: Container(
              height: isOpen ? null : 0,
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Column(
                children: data.entries.map((entry) {
                  return _ProfileDataRow(
                    label: entry.key,
                    value: entry.value,
                    onTap: () => onEdit(entry.key, entry.value),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data Row Item ───
class _ProfileDataRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ProfileDataRow({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    bool isMissing = value.contains("+ Add Details") || value.contains("Not Specified");

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                ),
              ),
              const Text(" :  ", style: TextStyle(color: Colors.white24)),
              Expanded(
                flex: 3,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: isMissing ? AppColors.goldMedium : Colors.white,
                          fontSize: 13,
                          fontWeight: isMissing ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    Icon(Icons.edit, color: Colors.white.withOpacity(0.15), size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick Action Pill ───
class _QuickActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isHighlight;
  final VoidCallback? onTap;

  const _QuickActionPill({required this.icon, required this.label, this.isHighlight = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isHighlight ? AppColors.goldMedium.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isHighlight ? AppColors.goldMedium : Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: isHighlight ? AppColors.goldMedium : Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isHighlight ? AppColors.goldLight : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}