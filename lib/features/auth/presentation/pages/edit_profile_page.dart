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

class _EditProfilePageState extends State<EditProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Track which accordion is currently open
  String? _expandedSection = 'Basic Details';
  bool _isUploadingPhoto = false;

  final Map<String, IconData> _sectionIcons = {
    "Basic Details": Icons.person_outline,
    "Status & Intent": Icons.favorite_outline,
    "Location": Icons.location_on_outlined,
    "Education & Profession": Icons.work_outline,
    "Socioeconomic": Icons.attach_money_outlined,
    "Lifestyle": Icons.fitness_center_outlined,
    "Cultural & Language": Icons.language_outlined,
    "Personality": Icons.emoji_emotions_outlined,
    "Partner Preferences": Icons.tune_rounded,
    "Interests": Icons.interests_outlined,
    "Bio": Icons.edit_note_outlined,
  };

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
        curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
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
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.white, letterSpacing: 1, fontSize: 18),
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
                          const SizedBox(height: 20),
                          // ── Photo Manager is always second ──
                          _PhotoManagerSection(
                            profile: profile,
                            isUploadingPhoto: _isUploadingPhoto,
                            isOpen: _expandedSection == 'Photos',
                            onTap: () => setState(() {
                              _expandedSection = _expandedSection == 'Photos'
                                  ? null
                                  : 'Photos';
                            }),
                            onAdd: () => _uploadProfilePhoto(profile),
                            onDelete: (index) =>
                                _deletePhotoAtIndex(profile, index),
                            onSetMain: (index) =>
                                _setPhotoAsMain(profile, index),
                          ),
                          const SizedBox(height: 4),
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
                                  _expandedSection =
                                      _expandedSection == sectionName
                                      ? null
                                      : sectionName;
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
    final emailController = TextEditingController(
      text: (profile['email'] ?? '').toString(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.onyx,
          title: const Text(
            'Edit Contact',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: emailController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Save',
                style: TextStyle(color: AppColors.goldMedium),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final currentEmail = (profile['email'] ?? '').toString();
    final newEmailRaw = emailController.text.trim();
    final emailChanged = newEmailRaw.isNotEmpty && newEmailRaw != currentEmail;

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
        if (authEmail.isEmpty ||
            authEmail.toLowerCase() != newEmailRaw.toLowerCase()) {
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
        if (!mounted) return;
        showLinearMessage(context, 'Email updated successfully.');
      } else {
        if (!mounted) return;
        showLinearMessage(context, 'No changes to update.');
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

  Future<bool> _reauthenticateForEmailUpdate(
    Map<String, dynamic> profile,
  ) async {
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
        showLinearMessage(
          context,
          'We could not find your phone number. Please contact support.',
          isError: true,
        );
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

    showLinearMessage(
      context,
      'Please connect at least one login method (Google, Phone, or Email) before making changes.',
      isError: true,
    );
    return false;
  }

  Future<String?> _promptPassword() async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.onyx,
        title: const Text(
          'Confirm Password',
          style: TextStyle(color: Colors.white),
        ),
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Confirm',
              style: TextStyle(color: AppColors.goldMedium),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return null;
    return controller.text.trim();
  }

  Future<void> _manageHoroscope(Map<String, dynamic> profile) async {
    final starController = TextEditingController(
      text: (profile['star'] ?? '').toString(),
    );
    final rassiController = TextEditingController(
      text: (profile['rassi'] ?? '').toString(),
    );
    final doshamController = TextEditingController(
      text: (profile['dosham'] ?? '').toString(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.onyx,
          title: const Text(
            'Manage Horoscope',
            style: TextStyle(color: Colors.white),
          ),
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
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Save',
                style: TextStyle(color: AppColors.goldMedium),
              ),
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

  /// Promotes [index] to position 0 in the photos array so it becomes the
  /// profile picture visible to all other users.
  Future<void> _setPhotoAsMain(Map<String, dynamic> profile, int index) async {
    final existing = profile['photos'];
    if (existing is! List || index <= 0 || index >= existing.length) return;

    final photos = existing.map((e) => e.toString()).toList();
    final chosen = photos.removeAt(index);
    photos.insert(0, chosen);

    setState(() => _isUploadingPhoto = true);
    try {
      await UserService.instance.updateCurrentUserProfile({
        'photos': photos,
        'profilePicture': chosen,
        'photoUrl': chosen,
      });
      if (mounted) {
        showLinearMessage(context, 'Profile picture updated!');
      }
    } catch (e) {
      if (mounted) {
        showLinearMessage(context, 'Failed to update: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _uploadProfilePhoto(Map<String, dynamic> profile) async {
    if (_isUploadingPhoto) return;

    final uid = (profile['uid'] ?? '').toString();
    if (uid.isEmpty) {
      showLinearMessage(
        context,
        'Your session has expired. Please log out and log back in.',
        isError: true,
      );
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
        file: file.path.isEmpty
            ? throw Exception('Invalid selected file')
            : File(file.path),
      );

      // Get existing photos array
      final existingPhotos = profile['photos'] is List
          ? List<String>.from(profile['photos'] as List)
          : <String>[];

      // Add new photo at the beginning of the array
      existingPhotos.insert(0, photoUrl);

      await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
        'photos': existingPhotos,
        'profilePicture': photoUrl,
      });

      if (!mounted) return;
      showLinearMessage(context, 'Profile photo updated successfully.');
    } catch (_) {
      if (!mounted) return;
      showLinearMessage(
        context,
        'Failed to upload photo. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  /// Delete a photo at a specific index in the photos array.
  Future<void> _deletePhotoAtIndex(
    Map<String, dynamic> profile,
    int index,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.onyx,
        title: const Text(
          'Remove Photo?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to remove this photo?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final existingPhotos = profile['photos'] is List
        ? List<String>.from(profile['photos'] as List)
        : <String>[];
    if (index < 0 || index >= existingPhotos.length) return;
    existingPhotos.removeAt(index);

    // If we removed the first photo, update profilePicture too
    final updates = <String, dynamic>{'photos': existingPhotos};
    if (index == 0) {
      updates['profilePicture'] = existingPhotos.isNotEmpty
          ? existingPhotos.first
          : null;
    }

    setState(() => _isUploadingPhoto = true);
    try {
      await UserService.instance.updateCurrentUserProfile(updates);
      if (!mounted) return;
      showLinearMessage(context, 'Photo removed.');
    } catch (_) {
      if (!mounted) return;
      showLinearMessage(context, 'Failed to remove photo.', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _deleteProfilePhoto(Map<String, dynamic> profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.onyx,
        title: const Text(
          "Delete Photo?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Your profile will look better with a photo. Are you sure?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
        case 'Show Gender':
          return const ['Yes', 'No'];
      }
    }

    if (section == 'Location') {
      switch (label) {
        case 'Distance Preference':
          return ['10', '25', '50', '100', '150', '200'];
      }
    }

    if (section == 'Education & Profession') {
      switch (label) {
        case 'Highest Qualification':
          return const [
            'High School',
            'Bachelor\'s Degree',
            'Master\'s Degree',
            'PhD',
            'Other',
          ];
        case 'What Are You Looking For?':
          return const [
            'Serious Relationship',
            'Casual Dating',
            'Friendship',
            'Marriage',
          ];
      }
    }

    if (section == 'Lifestyle') {
      switch (label) {
        case 'Drinking':
          return const ['Never', 'Socially', 'Regularly'];
        case 'Smoking':
          return const ['Never', 'Socially', 'Regularly'];
        case 'Workout':
          return const [
            'Never',
            '1-2 times/week',
            '3-4 times/week',
            '5+ times/week',
          ];
      }
    }

    if (section == 'Values & Identity') {
      switch (label) {
        case 'Communication Style':
          return const ['Direct', 'Diplomatic', 'Reserved', 'Expressive'];
        case 'Love Language':
          return const [
            'Words of Affirmation',
            'Acts of Service',
            'Receiving Gifts',
            'Quality Time',
            'Physical Touch',
          ];
        case 'Education Level':
          return const [
            'High School',
            'Undergraduate',
            'Postgraduate',
            'Doctorate',
          ];
        case 'Zodiac':
          return const [
            'Aries',
            'Taurus',
            'Gemini',
            'Cancer',
            'Leo',
            'Virgo',
            'Libra',
            'Scorpio',
            'Sagittarius',
            'Capricorn',
            'Aquarius',
            'Pisces',
          ];
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
                              color: isSelected
                                  ? AppColors.obsidian
                                  : Colors.white,
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
                        hintText: options.isNotEmpty
                            ? 'Or enter custom value'
                            : 'Enter value',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                        ),
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
      multiLine: label == 'About You',
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
    if (section == 'Bio' && label == 'About You') return {'key': 'bio'};

    if (section == 'Basic Details') {
      switch (label) {
        case 'First Name':
          return {'key': 'firstName'};
        case 'Last Name':
          return {'key': 'lastName'};
        case 'Gender':
          return {'key': 'gender'};
        case 'Show Gender on Profile':
          return {'key': 'showGender'};
      }
    }

    if (section == 'Status & Intent') {
      switch (label) {
        case 'Looking For':
          return {'key': 'lookingFor'};
        case 'Marital Status':
          return {'key': 'maritalStatus'};
        case 'Has Children':
          return {'key': 'hasChildren'};
        case 'Children Details':
          return {'key': 'childrenDetails'};
        case 'Willing to Relocate':
          return {'key': 'willingToRelocate'};
      }
    }

    if (section == 'Location') {
      switch (label) {
        case 'City':
          return {'key': 'city'};
        case 'Country':
          return {'key': 'country'};
        case 'Distance Preference':
          return {'key': 'distanceKm'};
      }
    }

    if (section == 'Education & Profession') {
      switch (label) {
        case 'Education Level':
          return {'key': 'educationLevel'};
        case 'Highest Qualification':
          return {'key': 'highestQualification'};
        case 'Profession':
          return {'key': 'profession'};
        case 'Industry':
          return {'key': 'industry'};
      }
    }

    if (section == 'Socioeconomic') {
      switch (label) {
        case 'Income Range':
          return {'key': 'incomeRange'};
        case 'Net Worth Range':
          return {'key': 'netWorthRange'};
        case 'Lifestyle Tags':
          return {'key': 'lifestyleTags'};
      }
    }

    if (section == 'Lifestyle') {
      switch (label) {
        case 'Drinking':
          return {'key': 'drinking'};
        case 'Smoking':
          return {'key': 'smoking'};
        case 'Workout':
          return {'key': 'workout'};
        case 'Pets':
          return {'key': 'pets'};
      }
    }

    if (section == 'Cultural & Language') {
      switch (label) {
        case 'Religion':
          return {'key': 'religion'};
        case 'Spiritual Level':
          return {'key': 'spiritualLevel'};
        case 'Ethnicity':
          return {'key': 'ethnicity'};
        case 'Primary Language':
          return {'key': 'primaryLanguage'};
        case 'Other Languages':
          return {'key': 'otherLanguages'};
        case 'Family Values Importance':
          return {'key': 'familyValuesImportance'};
      }
    }

    if (section == 'Values & Identity') {
      switch (label) {
        case 'Communication Style':
          return {'key': 'communicationStyle'};
        case 'Love Language':
          return {'key': 'loveLanguage'};
        case 'Zodiac':
          return {'key': 'zodiac'};
      }
    }

    if (section == 'Personality') {
      switch (label) {
        case 'Personality Traits':
          return {'key': 'personalityTraits'};
      }
    }

    if (section == 'Partner Preferences') {
      switch (label) {
        case 'Min Age Preference':
          return {'key': 'minAgePreference'};
        case 'Max Age Preference':
          return {'key': 'maxAgePreference'};
        case 'Preferred Location':
          return {'key': 'preferredLocation'};
        case 'Preferred Education':
          return {'key': 'preferredEducation'};
        case 'Preferred Profession':
          return {'key': 'preferredProfession'};
        case 'Preferred Religion':
          return {'key': 'preferredReligion'};
        case 'Preferred Lifestyle':
          return {'key': 'preferredLifestyle'};
      }
    }

    if (section == 'Interests') {
      switch (label) {
        case 'Your Interests':
          return {'key': 'interests'};
      }
    }

    if (section == 'Visibility') {
      switch (label) {
        case 'Profile Visibility':
          return {'key': 'profileVisibility'};
      }
    }

    if (section == 'Photos') {
      switch (label) {
        case 'Profile Picture':
          return {'key': 'profilePicture'};
      }
    }

    return {'key': null};
  }

  Map<String, Map<String, String>> _buildProfileData(
    Map<String, dynamic> profile,
  ) {
    String value(String key, {String fallback = '+ Add Details'}) {
      final raw = profile[key];
      if (raw == null) return fallback;
      final text = raw.toString().trim();
      return text.isEmpty ? fallback : text;
    }

    String listValue(String key) {
      final raw = profile[key];
      if (raw == null) return '+ Add Details';
      if (raw is List && raw.isNotEmpty) return raw.join(', ');
      return '+ Add Details';
    }

    String boolValue(String key) {
      final raw = profile[key];
      if (raw == null) return '+ Add Details';
      if (raw is bool) return raw ? 'Yes' : 'No';
      return raw.toString();
    }

    return {
      // ── Step 1: Basic Identity ──────────────────────────────────────────────
      "Basic Details": {
        "First Name": value('firstName', fallback: 'Member'),
        "Last Name": value('lastName'),
        "Gender": value('gender'),
        "Show Gender on Profile": value('showGender') == 'true' ? 'Yes' : 'No',
        "Age": _formatAge(profile['dateOfBirth'], fallbackAge: profile['age']),
      },
      // ── Step 2: Status & Intent ──────────────────────────────────────────────
      "Status & Intent": {
        "Looking For": value('lookingFor'),
        "Marital Status": value('maritalStatus'),
        "Has Children": boolValue('hasChildren'),
        "Children Details": value('childrenDetails'),
        "Willing to Relocate": boolValue('willingToRelocate'),
      },
      // ── Location ─────────────────────────────────────────────────────────────
      "Location": {
        "City": value('city'),
        "Country": value('country'),
        "Distance Preference": '${value('distanceKm', fallback: '50')} km',
      },
      // ── Step 3: Education & Profession ────────────────────────────────────────
      "Education & Profession": {
        "Education Level": value('educationLevel'),
        "Highest Qualification": value('highestQualification'),
        "Profession": value('profession'),
        "Industry": value('industry'),
      },
      // ── Step 3: Socioeconomic ─────────────────────────────────────────────────
      "Socioeconomic": {
        "Income Range": value('incomeRange'),
        "Net Worth Range": value('netWorthRange'),
        "Lifestyle Tags": listValue('lifestyleTags'),
      },
      // ── Step 5: Lifestyle ─────────────────────────────────────────────────────
      "Lifestyle": {"Drinking": value('drinking'), "Smoking": value('smoking')},
      // ── Step 4: Cultural & Language ───────────────────────────────────────────
      "Cultural & Language": {
        "Religion": value('religion'),
        "Spiritual Level": value('spiritualLevel'),
        "Ethnicity": value('ethnicity'),
        "Primary Language": value('primaryLanguage'),
        "Other Languages": listValue('otherLanguages'),
        "Family Values Importance":
            '${value('familyValuesImportance', fallback: '3')} / 5',
      },
      // ── Step 5: Personality ───────────────────────────────────────────────────
      "Personality": {"Personality Traits": listValue('personalityTraits')},
      // ── Step 6: Partner Preferences ──────────────────────────────────────────
      "Partner Preferences": {
        "Min Age Preference": value('minAgePreference', fallback: '18'),
        "Max Age Preference": value('maxAgePreference', fallback: '50'),
        "Preferred Location": value('preferredLocation'),
        "Preferred Education": value('preferredEducation'),
        "Preferred Profession": value('preferredProfession'),
        "Preferred Religion": value('preferredReligion'),
        "Preferred Lifestyle": listValue('preferredLifestyle'),
      },
      // ── Interests ─────────────────────────────────────────────────────────────
      "Interests": {"Your Interests": listValue('interests')},
      "Bio": {"About You": value('bio', fallback: 'No bio yet')},
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
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
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
                const Text(
                  "Profile Completeness",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  progressLabel,
                  style: TextStyle(
                    color: AppColors.goldMedium.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.goldMedium,
                ),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _QuickActionPill(
            icon: _isUploadingPhoto
                ? Icons.hourglass_top
                : Icons.camera_alt_outlined,
            label: _isUploadingPhoto ? "Uploading..." : "Add Photo",
            isHighlight: true,
            onTap: _isUploadingPhoto
                ? null
                : () => _uploadProfilePhoto(profile),
          ),
          _QuickActionPill(
            icon: Icons.contact_phone_outlined,
            label: "Edit Contact",
            onTap: () => _editContact(profile),
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
                    border: Border.all(
                      color: AppColors.goldMedium.withOpacity(0.6),
                    ),
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
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Photo Manager Section ───────────────────────────────────────────────────
class _PhotoManagerSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool isUploadingPhoto;
  final bool isOpen;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final void Function(int index) onDelete;
  final void Function(int index) onSetMain;

  const _PhotoManagerSection({
    required this.profile,
    required this.isUploadingPhoto,
    required this.isOpen,
    required this.onTap,
    required this.onAdd,
    required this.onDelete,
    required this.onSetMain,
  });

  List<String> get _photos {
    final raw = profile['photos'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    // Fall back to single profilePicture
    final single =
        (profile['profilePicture'] ??
                profile['photoUrl'] ??
                profile['profileImageUrl'] ??
                '')
            .toString()
            .trim();
    return single.isNotEmpty ? [single] : [];
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isOpen
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isOpen
            ? [
                BoxShadow(
                  color: AppColors.goldMedium.withOpacity(0.05),
                  blurRadius: 20,
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    color: isOpen ? AppColors.goldMedium : Colors.white54,
                    size: 22,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Photos',
                      style: TextStyle(
                        color: isOpen ? AppColors.goldLight : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Badge showing photo count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldMedium.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${photos.length}',
                      style: const TextStyle(
                        color: AppColors.goldMedium,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable photo grid
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: isOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (photos.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'No photos yet. Tap + to add your first photo.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.75,
                              ),
                          itemCount: photos.length + 1, // +1 for Add tile
                          itemBuilder: (ctx, i) {
                            // Last tile = "Add Photo" button
                            if (i == photos.length) {
                              return GestureDetector(
                                onTap: isUploadingPhoto ? null : onAdd,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.goldMedium.withOpacity(
                                      0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.goldMedium.withOpacity(
                                        0.35,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isUploadingPhoto
                                      ? const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.goldMedium,
                                            ),
                                          ),
                                        )
                                      : const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
                                              color: AppColors.goldMedium,
                                              size: 28,
                                            ),
                                            SizedBox(height: 6),
                                            Text(
                                              'Add Photo',
                                              style: TextStyle(
                                                color: AppColors.goldMedium,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              );
                            }

                            // Photo tile — tap to set as main, X to delete
                            return GestureDetector(
                              onTap: i == 0 ? null : () => onSetMain(i),
                              child: Stack(
                                children: [
                                  // Photo
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      photos[i],
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (_, child, progress) =>
                                          progress == null
                                          ? child
                                          : Container(
                                              color: const Color(0xFF1A1A1A),
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 1.5,
                                                      color:
                                                          AppColors.goldMedium,
                                                    ),
                                              ),
                                            ),
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFF1A1A1A),
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.white24,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // "Main" badge on first photo
                                  if (i == 0)
                                    Positioned(
                                      left: 6,
                                      bottom: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.goldMedium,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          'Main',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  // "Tap to set main" hint on non-main photos
                                  if (i != 0)
                                    Positioned(
                                      left: 6,
                                      bottom: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.star_outline,
                                              color: AppColors.goldMedium,
                                              size: 9,
                                            ),
                                            SizedBox(width: 2),
                                            Text(
                                              'Set main',
                                              style: TextStyle(
                                                color: AppColors.goldMedium,
                                                fontSize: 8,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  // Delete button
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => onDelete(i),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap any photo to set it as your profile picture. Tap ✕ to remove.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
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
        color: isOpen
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isOpen
            ? [
                BoxShadow(
                  color: AppColors.goldMedium.withOpacity(0.05),
                  blurRadius: 20,
                ),
              ]
            : [],
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
                  Icon(
                    icon,
                    color: isOpen ? AppColors.goldMedium : Colors.white54,
                    size: 22,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isOpen ? AppColors.goldLight : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0, // Rotates the arrow
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withOpacity(0.5),
                    ),
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

  const _ProfileDataRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isMissing =
        value.contains("+ Add Details") || value.contains("Not Specified");

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
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 13,
                  ),
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
                          color: isMissing
                              ? AppColors.goldMedium
                              : Colors.white,
                          fontSize: 13,
                          fontWeight: isMissing
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit,
                      color: Colors.white.withOpacity(0.15),
                      size: 14,
                    ),
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

  const _QuickActionPill({
    required this.icon,
    required this.label,
    this.isHighlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isHighlight
              ? AppColors.goldMedium.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlight
                ? AppColors.goldMedium
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isHighlight ? AppColors.goldMedium : Colors.white70,
              size: 16,
            ),
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
