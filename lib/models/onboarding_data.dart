class OnboardingData {
  // ─── Step 1: Basic Identity ──────────────────────────────────────────────
  String firstName;
  String lastName;
  DateTime? dateOfBirth;
  int? selectedAge;
  String gender;
  bool showGender;
  String city;
  String country;
  String phone; // Pre-filled from auth (read-only)
  String email; // Pre-filled from auth (read-only)
  List<String> photos; // Min 3, max 6
  String profilePicture; // First photo

  // ─── Step 2: Status & Intent ─────────────────────────────────────────────
  String lookingFor; // Marriage / Long-term
  String maritalStatus; // Never Married / Divorced / Widowed
  bool? hasChildren;
  String childrenDetails;
  bool? willingToRelocate;

  // ─── Step 3: Lifestyle & Socioeconomic ───────────────────────────────────
  String educationLevel;
  String profession;
  String industry;
  String incomeRange; // Banded: "50K–75K", etc.
  String netWorthRange; // Optional
  List<String> lifestyleTags; // Multi-select: travel, fitness, luxury, etc.

  // ─── Step 4: Cultural & Language ─────────────────────────────────────────
  String religion;
  String spiritualLevel; // Not Religious / Somewhat / Very / Deeply
  String ethnicity;
  String primaryLanguage;
  List<String> otherLanguages;
  Map<String, String> languageFluency; // language → Basic/Conversational/Fluent/Native
  int familyValuesImportance; // 1–5

  // ─── Step 5: Personality & Profile ───────────────────────────────────────
  String bio; // Max 300 words
  List<String> personalityTraits;
  List<String> interests;
  String smoking;
  String drinking;

  // ─── Step 6: Partner Preferences ─────────────────────────────────────────
  int minAgePreference;
  int maxAgePreference;
  String preferredLocation;
  String preferredEducation;
  String preferredProfession;
  List<String> preferredLifestyle;
  String preferredReligion;

  // ─── Step 7: Verification ────────────────────────────────────────────────
  bool idVerified;
  String idVerificationUrl;
  String verificationPhotoUrl; // Selfie
  bool isVerified; // Selfie verified
  bool incomeVerified;
  bool professionalVerified;
  String profileApprovalStatus; // pending / approved / rejected

  // ─── Step 8: Exclusivity Controls ────────────────────────────────────────
  String inviteCode;
  String profileVisibility; // Public / Private / Curated Matches Only

  // ─── New Marriage-Focused Assessment Fields ─────────────────────────────
  String height;
  String marriageTimeline; // "Within 1 year", "1–3 years", "Flexible"
  String childrenPreference; // "Yes", "No", "Undecided"
  String preferredFamilySize; // "Small", "Medium", "Large"
  String relocatePreference; // "Yes", "No", "Depends"
  String financialStyle; // "Saver", "Balanced", "Spender"
  String decisionMakingStyle; // "Logical", "Emotional", "Balanced"
  String religionPreferenceMode; // "No Preference", "Same Religion", "Specific Religion"
  String specificReligion;
  List<String> rankedPartnerPriorities;

  /// Marriage dealbreaker IDs (see DealbreakerCatalog). Top-level user field.
  List<String> dealbreakers;

  // ─── Legacy Fields (backward compat) ──────────────────────────────────────
  String partnerPreference;
  String state;
  String highestQualification;
  String university;
  String workout;
  List<String> pets;
  String communicationStyle;
  String loveLanguage;
  String zodiac;

  // ─── Legal ───────────────────────────────────────────────────────────────
  bool termsAccepted;
  DateTime? termsAcceptedAt;

  // ─── Video-First Redesign Fields ─────────────────────────────────────────
  String introVideoUrl;
  String introVideoThumbnailUrl;
  String introVideoStatus; // '' | 'pending' | 'approved' | 'rejected'
  String? introVideoRejectionReason;
  DateTime? introVideoSubmittedAt;
  List<String> skills; // new, parallel to `interests`
  String datingIntention; // flat mirror of lookingFor (see marriageProfile.intent)
  Map<String, dynamic>? datingPreferences; // flat mirror of partner preferences

  /// Local filesystem path to the just-recorded intro video, held here only
  /// until `_completeOnboarding()` uploads it via `StorageService.uploadIntroVideo`.
  /// Never persisted to Firestore (not read/written in toMap/fromMap), mirroring
  /// how `photos` holds local file paths pre-upload.
  String? introVideoLocalPath;

  /// Local filesystem path to the JPEG thumbnail generated alongside the
  /// intro video recording, held here only until `_completeOnboarding()`
  /// best-effort-uploads it via `StorageService.uploadIntroVideoThumbnail`.
  /// Never persisted to Firestore (not read/written in toMap/fromMap), same
  /// transient treatment as `introVideoLocalPath` above.
  String? introVideoThumbnailLocalPath;

  // ─── Metadata ────────────────────────────────────────────────────────────
  int onboardingStep; // Current step for resume
  DateTime createdAt;

  OnboardingData({
    this.firstName = '',
    this.lastName = '',
    this.dateOfBirth,
    this.selectedAge,
    this.gender = '',
    this.showGender = true,
    this.city = '',
    this.country = '',
    this.phone = '',
    this.email = '',
    this.photos = const [],
    this.profilePicture = '',
    this.lookingFor = '',
    this.maritalStatus = '',
    this.hasChildren,
    this.childrenDetails = '',
    this.willingToRelocate,
    this.educationLevel = '',
    this.profession = '',
    this.industry = '',
    this.incomeRange = '',
    this.netWorthRange = '',
    this.lifestyleTags = const [],
    this.religion = '',
    this.spiritualLevel = '',
    this.ethnicity = '',
    this.primaryLanguage = '',
    this.otherLanguages = const [],
    this.languageFluency = const {},
    this.familyValuesImportance = 3,
    this.bio = '',
    this.personalityTraits = const [],
    this.interests = const [],
    this.smoking = '',
    this.drinking = '',
    this.minAgePreference = 18,
    this.maxAgePreference = 50,
    this.preferredLocation = '',
    this.preferredEducation = '',
    this.preferredProfession = '',
    this.preferredLifestyle = const [],
    this.preferredReligion = '',
    this.idVerified = false,
    this.idVerificationUrl = '',
    this.verificationPhotoUrl = '',
    this.isVerified = false,
    this.incomeVerified = false,
    this.professionalVerified = false,
    this.profileApprovalStatus = 'pending',
    this.inviteCode = '',
    this.profileVisibility = 'Public',
    this.height = '',
    this.marriageTimeline = '',
    this.childrenPreference = '',
    this.preferredFamilySize = '',
    this.relocatePreference = '',
    this.financialStyle = '',
    this.decisionMakingStyle = '',
    this.religionPreferenceMode = 'No Preference',
    this.specificReligion = '',
    this.rankedPartnerPriorities = const [
      'Family Values',
      'Communication',
      'Lifestyle Alignment',
      'Career Ambition',
      'Financial Maturity'
    ],
    this.dealbreakers = const [],
    this.partnerPreference = '',
    this.state = '',
    this.highestQualification = '',
    this.university = '',
    this.workout = '',
    this.pets = const [],
    this.communicationStyle = '',
    this.loveLanguage = '',
    this.zodiac = '',
    this.termsAccepted = false,
    this.termsAcceptedAt,
    this.introVideoUrl = '',
    this.introVideoThumbnailUrl = '',
    this.introVideoStatus = '',
    this.introVideoRejectionReason,
    this.introVideoSubmittedAt,
    this.skills = const [],
    this.datingIntention = '',
    this.datingPreferences,
    this.introVideoLocalPath,
    this.introVideoThumbnailLocalPath,
    this.onboardingStep = 0,
  }) : createdAt = DateTime.now();

  // ─── Computed Properties ─────────────────────────────────────────────────

  String get fullName => '$firstName $lastName'.trim();

  int? get age {
    if (selectedAge != null) return selectedAge;
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int a = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      a--;
    }
    return a;
  }

  bool get isAdult {
    final userAge = age;
    return userAge != null && userAge >= 18;
  }

  String get location {
    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    if (city.isNotEmpty) return city;
    if (country.isNotEmpty) return country;
    return '';
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  /// Reflects the 7-step required onboarding flow: Welcome → Basic Info →
  /// Intent & Preferences → Bio & Interests → Intro Video → Verification →
  /// Review. "Bio & Interests" was added as a step (collecting the optional
  /// `bio`/`interests` fields) after the prior 6-step structure (which itself
  /// added Verification — selfie + government ID — after the original 5-step
  /// simplification), per user-feedback follow-ups.
  /// Profession/education/values/dealbreakers etc. are still not required to
  /// complete onboarding (deferred to optional profile editing) so they don't
  /// factor into this percentage.
  double get completionPercentage {
    int completed = 0;
    const total = 7;

    // Step 1: Welcome
    completed++;
    // Step 2: Basic Info (name, age, gender, location)
    if (firstName.isNotEmpty && (selectedAge != null || dateOfBirth != null) &&
        gender.isNotEmpty && city.isNotEmpty) completed++;
    // Step 3: Intent & Preferences (dating intention + basic age range)
    if (lookingFor.isNotEmpty &&
        minAgePreference > 0 &&
        maxAgePreference > minAgePreference) completed++;
    // Step 4: Bio & Interests (both optional — count as soon as this step has
    // been reached/passed, mirroring how Step 7/Review below uses
    // onboardingStep rather than requiring the fields themselves to be set)
    if (onboardingStep >= 3 || bio.isNotEmpty || interests.isNotEmpty) {
      completed++;
    }
    // Step 5: Intro Video (recorded locally, or already submitted/reviewed)
    if ((introVideoLocalPath != null && introVideoLocalPath!.isNotEmpty) ||
        introVideoUrl.isNotEmpty ||
        introVideoStatus.isNotEmpty) completed++;
    // Step 6: Verification (selfie required; government ID optional)
    if (verificationPhotoUrl.isNotEmpty) {
      completed++;
    }
    // Step 7: Review & Generate
    if (onboardingStep >= 6) completed++;

    return (completed / total).clamp(0.0, 1.0);
  }

  // ─── AI Marriage Profile Serialization ───────────────────────────────────

  Map<String, dynamic> toMarriageProfileMap() {
    return {
      'intent': {
        'lookingFor': lookingFor,
        'marriageTimeline': marriageTimeline,
        'relocatePreference': relocatePreference,
        'willingToRelocate': willingToRelocate,
      },
      'lifestyleValues': {
        'height': height,
        'familyImportance': familyValuesImportance,
        'childrenPreference': childrenPreference,
        'preferredFamilySize': preferredFamilySize,
        'financialStyle': financialStyle,
        'decisionMakingStyle': decisionMakingStyle,
        'smoking': smoking,
        'drinking': drinking,
        'workout': workout,
        'languages': [
          if (primaryLanguage.isNotEmpty) primaryLanguage,
          ...otherLanguages.where((l) => l != primaryLanguage),
        ],
      },
      'partnerPreferences': {
        'minAge': minAgePreference,
        'maxAge': maxAgePreference,
        'religionPreferenceMode': religionPreferenceMode,
        'preferredReligion': preferredReligion,
        'specificReligion': specificReligion,
        'rankedPriorities': rankedPartnerPriorities,
      },
      'aiMetaData': {
        'version': '1.0',
        'assessmentCompletedAt': DateTime.now().toIso8601String(),
      },
    };
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'selectedAge': selectedAge,
      'gender': gender,
      'showGender': showGender,
      'city': city,
      'country': country,
      'phone': phone,
      'email': email,
      'photos': photos,
      'profilePicture': profilePicture,
      'lookingFor': lookingFor,
      'maritalStatus': maritalStatus,
      'hasChildren': hasChildren,
      'childrenDetails': childrenDetails,
      'willingToRelocate': willingToRelocate,
      'educationLevel': educationLevel,
      'profession': profession,
      'industry': industry,
      'incomeRange': incomeRange,
      'netWorthRange': netWorthRange,
      'lifestyleTags': lifestyleTags,
      'religion': religion,
      'spiritualLevel': spiritualLevel,
      'ethnicity': ethnicity,
      'primaryLanguage': primaryLanguage,
      'otherLanguages': otherLanguages,
      'languageFluency': languageFluency,
      'familyValuesImportance': familyValuesImportance,
      'bio': bio,
      'personalityTraits': personalityTraits,
      'interests': interests,
      'smoking': smoking,
      'drinking': drinking,
      'minAgePreference': minAgePreference,
      'maxAgePreference': maxAgePreference,
      'preferredLocation': preferredLocation,
      'preferredEducation': preferredEducation,
      'preferredProfession': preferredProfession,
      'preferredLifestyle': preferredLifestyle,
      'preferredReligion': preferredReligion,
      'idVerified': idVerified,
      'idVerificationUrl': idVerificationUrl,
      'verificationPhotoUrl': verificationPhotoUrl,
      'isVerified': isVerified,
      'incomeVerified': incomeVerified,
      'professionalVerified': professionalVerified,
      'profileApprovalStatus': profileApprovalStatus,
      'inviteCode': inviteCode,
      'profileVisibility': profileVisibility,
      'height': height,
      'marriageTimeline': marriageTimeline,
      'childrenPreference': childrenPreference,
      'preferredFamilySize': preferredFamilySize,
      'relocatePreference': relocatePreference,
      'financialStyle': financialStyle,
      'decisionMakingStyle': decisionMakingStyle,
      'religionPreferenceMode': religionPreferenceMode,
      'specificReligion': specificReligion,
      'rankedPartnerPriorities': rankedPartnerPriorities,
      'dealbreakers': dealbreakers,
      'marriageProfile': toMarriageProfileMap(),
      'partnerPreference': partnerPreference,
      'state': state,
      'highestQualification': highestQualification,
      'university': university,
      'workout': workout,
      'pets': pets,
      'communicationStyle': communicationStyle,
      'loveLanguage': loveLanguage,
      'zodiac': zodiac,
      'termsAccepted': termsAccepted,
      'termsAcceptedAt': termsAcceptedAt?.toIso8601String(),
      'introVideoUrl': introVideoUrl,
      'introVideoThumbnailUrl': introVideoThumbnailUrl,
      'introVideoStatus': introVideoStatus,
      'introVideoRejectionReason': introVideoRejectionReason,
      'introVideoSubmittedAt': introVideoSubmittedAt?.toIso8601String(),
      'skills': skills,
      'datingIntention': datingIntention,
      'datingPreferences': datingPreferences,
      // NOTE: introVideoLocalPath is intentionally NOT included — it is a
      // transient local-only field, same treatment as local photo paths
      // pre-upload (see `photos`, which is only ever a remote URL once saved).
      'onboardingStep': onboardingStep,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory OnboardingData.fromMap(Map<String, dynamic> map) {
    final mp = map['marriageProfile'] as Map<String, dynamic>? ?? {};
    final intentMap = mp['intent'] as Map<String, dynamic>? ?? {};
    final lifestyleMap = mp['lifestyleValues'] as Map<String, dynamic>? ?? {};
    final partnerMap = mp['partnerPreferences'] as Map<String, dynamic>? ?? {};

    return OnboardingData(
      firstName: map['firstName'] ?? map['name'] ?? '',
      lastName: map['lastName'] ?? '',
      dateOfBirth: map['dob'] != null 
          ? DateTime.tryParse(map['dob'].toString())
          : map['dateOfBirth'] != null
              ? DateTime.tryParse(map['dateOfBirth'].toString())
              : null,
      selectedAge: map['selectedAge'] ?? map['age'],
      gender: map['gender'] ?? '',
      showGender: map['showGender'] ?? true,
      city: map['city'] ?? '',
      country: map['country'] ?? '',
      phone: map['phone'] ?? map['phoneNumber'] ?? '',
      email: map['email'] ?? '',
      photos: List<String>.from(map['photos'] ?? []),
      profilePicture: map['profilePicture'] ?? '',
      lookingFor: map['lookingFor'] ?? intentMap['lookingFor'] ?? '',
      maritalStatus: map['maritalStatus'] ?? '',
      hasChildren: map['hasChildren'],
      childrenDetails: map['childrenDetails'] ?? '',
      willingToRelocate: map['willingToRelocate'] ?? intentMap['willingToRelocate'],
      educationLevel: map['educationLevel'] ?? map['highestQualification'] ?? '',
      profession: map['profession'] ?? '',
      industry: map['industry'] ?? '',
      incomeRange: map['incomeRange'] ?? '',
      netWorthRange: map['netWorthRange'] ?? '',
      lifestyleTags: List<String>.from(map['lifestyleTags'] ?? []),
      religion: map['religion'] ?? '',
      spiritualLevel: map['spiritualLevel'] ?? '',
      ethnicity: map['ethnicity'] ?? '',
      primaryLanguage: map['primaryLanguage'] ?? '',
      otherLanguages: List<String>.from(map['otherLanguages'] ?? []),
      languageFluency: Map<String, String>.from(map['languageFluency'] ?? {}),
      familyValuesImportance: map['familyValuesImportance'] ?? lifestyleMap['familyImportance'] ?? 3,
      bio: map['bio'] ?? '',
      personalityTraits: List<String>.from(map['personalityTraits'] ?? []),
      interests: List<String>.from(map['interests'] ?? []),
      smoking: map['smoking'] ?? lifestyleMap['smoking'] ?? '',
      drinking: map['drinking'] ?? lifestyleMap['drinking'] ?? '',
      minAgePreference: map['minAgePreference'] ?? partnerMap['minAge'] ?? 18,
      maxAgePreference: map['maxAgePreference'] ?? partnerMap['maxAge'] ?? 50,
      preferredLocation: map['preferredLocation'] ?? '',
      preferredEducation: map['preferredEducation'] ?? '',
      preferredProfession: map['preferredProfession'] ?? '',
      preferredLifestyle: List<String>.from(map['preferredLifestyle'] ?? []),
      preferredReligion: map['preferredReligion'] ?? partnerMap['preferredReligion'] ?? '',
      idVerified: map['idVerified'] ?? false,
      idVerificationUrl: map['idVerificationUrl'] ?? '',
      verificationPhotoUrl: map['verificationPhotoUrl'] ?? '',
      isVerified: map['isVerified'] ?? false,
      incomeVerified: map['incomeVerified'] ?? false,
      professionalVerified: map['professionalVerified'] ?? false,
      profileApprovalStatus: map['profileApprovalStatus'] ?? 'pending',
      inviteCode: map['inviteCode'] ?? '',
      profileVisibility: map['profileVisibility'] ?? 'Public',
      height: map['height'] ?? lifestyleMap['height'] ?? '',
      marriageTimeline: map['marriageTimeline'] ?? intentMap['marriageTimeline'] ?? '',
      childrenPreference: map['childrenPreference'] ?? lifestyleMap['childrenPreference'] ?? '',
      preferredFamilySize: map['preferredFamilySize'] ?? lifestyleMap['preferredFamilySize'] ?? '',
      relocatePreference: map['relocatePreference'] ?? intentMap['relocatePreference'] ?? '',
      financialStyle: map['financialStyle'] ?? lifestyleMap['financialStyle'] ?? '',
      decisionMakingStyle: map['decisionMakingStyle'] ?? lifestyleMap['decisionMakingStyle'] ?? '',
      religionPreferenceMode: map['religionPreferenceMode'] ?? partnerMap['religionPreferenceMode'] ?? 'No Preference',
      specificReligion: map['specificReligion'] ?? partnerMap['specificReligion'] ?? '',
      rankedPartnerPriorities: List<String>.from(map['rankedPartnerPriorities'] ?? partnerMap['rankedPriorities'] ?? [
        'Family Values',
        'Communication',
        'Lifestyle Alignment',
        'Career Ambition',
        'Financial Maturity'
      ]),
      dealbreakers: List<String>.from(map['dealbreakers'] ?? const []),
      partnerPreference: map['partnerPreference'] ?? '',
      state: map['state'] ?? '',
      highestQualification: map['highestQualification'] ?? '',
      university: map['university'] ?? '',
      workout: map['workout'] ?? lifestyleMap['workout'] ?? '',
      pets: List<String>.from(map['pets'] ?? []),
      communicationStyle: map['communicationStyle'] ?? '',
      loveLanguage: map['loveLanguage'] ?? '',
      zodiac: map['zodiac'] ?? '',
      termsAccepted: map['termsAccepted'] ?? false,
      termsAcceptedAt: map['termsAcceptedAt'] != null
          ? DateTime.tryParse(map['termsAcceptedAt'].toString())
          : null,
      introVideoUrl: map['introVideoUrl'] ?? '',
      introVideoThumbnailUrl: map['introVideoThumbnailUrl'] ?? '',
      introVideoStatus: map['introVideoStatus'] ?? '',
      introVideoRejectionReason: map['introVideoRejectionReason'],
      introVideoSubmittedAt: map['introVideoSubmittedAt'] != null
          ? DateTime.tryParse(map['introVideoSubmittedAt'].toString())
          : null,
      skills: List<String>.from(map['skills'] ?? []),
      datingIntention: map['datingIntention'] ?? map['lookingFor'] ?? '',
      datingPreferences: map['datingPreferences'] as Map<String, dynamic>?,
      onboardingStep: map['onboardingStep'] ?? 0,
    );
  }

  OnboardingData copyWith({
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    int? selectedAge,
    String? gender,
    bool? showGender,
    String? city,
    String? country,
    String? phone,
    String? email,
    List<String>? photos,
    String? profilePicture,
    String? lookingFor,
    String? maritalStatus,
    bool? hasChildren,
    String? childrenDetails,
    bool? willingToRelocate,
    String? educationLevel,
    String? profession,
    String? industry,
    String? incomeRange,
    String? netWorthRange,
    List<String>? lifestyleTags,
    String? religion,
    String? spiritualLevel,
    String? ethnicity,
    String? primaryLanguage,
    List<String>? otherLanguages,
    Map<String, String>? languageFluency,
    int? familyValuesImportance,
    String? bio,
    List<String>? personalityTraits,
    List<String>? interests,
    String? smoking,
    String? drinking,
    int? minAgePreference,
    int? maxAgePreference,
    String? preferredLocation,
    String? preferredEducation,
    String? preferredProfession,
    List<String>? preferredLifestyle,
    String? preferredReligion,
    bool? idVerified,
    String? idVerificationUrl,
    String? verificationPhotoUrl,
    bool? isVerified,
    bool? incomeVerified,
    bool? professionalVerified,
    String? profileApprovalStatus,
    String? inviteCode,
    String? profileVisibility,
    String? partnerPreference,
    String? state,
    String? highestQualification,
    String? university,
    String? workout,
    List<String>? pets,
    String? communicationStyle,
    String? loveLanguage,
    String? zodiac,
    bool? termsAccepted,
    DateTime? termsAcceptedAt,
    String? introVideoUrl,
    String? introVideoThumbnailUrl,
    String? introVideoStatus,
    String? introVideoRejectionReason,
    DateTime? introVideoSubmittedAt,
    List<String>? skills,
    String? datingIntention,
    Map<String, dynamic>? datingPreferences,
    String? introVideoLocalPath,
    String? introVideoThumbnailLocalPath,
    int? onboardingStep,
  }) {
    return OnboardingData(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      selectedAge: selectedAge ?? this.selectedAge,
      gender: gender ?? this.gender,
      showGender: showGender ?? this.showGender,
      city: city ?? this.city,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photos: photos ?? this.photos,
      profilePicture: profilePicture ?? this.profilePicture,
      lookingFor: lookingFor ?? this.lookingFor,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      hasChildren: hasChildren ?? this.hasChildren,
      childrenDetails: childrenDetails ?? this.childrenDetails,
      willingToRelocate: willingToRelocate ?? this.willingToRelocate,
      educationLevel: educationLevel ?? this.educationLevel,
      profession: profession ?? this.profession,
      industry: industry ?? this.industry,
      incomeRange: incomeRange ?? this.incomeRange,
      netWorthRange: netWorthRange ?? this.netWorthRange,
      lifestyleTags: lifestyleTags ?? this.lifestyleTags,
      religion: religion ?? this.religion,
      spiritualLevel: spiritualLevel ?? this.spiritualLevel,
      ethnicity: ethnicity ?? this.ethnicity,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      otherLanguages: otherLanguages ?? this.otherLanguages,
      languageFluency: languageFluency ?? this.languageFluency,
      familyValuesImportance: familyValuesImportance ?? this.familyValuesImportance,
      bio: bio ?? this.bio,
      personalityTraits: personalityTraits ?? this.personalityTraits,
      interests: interests ?? this.interests,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      minAgePreference: minAgePreference ?? this.minAgePreference,
      maxAgePreference: maxAgePreference ?? this.maxAgePreference,
      preferredLocation: preferredLocation ?? this.preferredLocation,
      preferredEducation: preferredEducation ?? this.preferredEducation,
      preferredProfession: preferredProfession ?? this.preferredProfession,
      preferredLifestyle: preferredLifestyle ?? this.preferredLifestyle,
      preferredReligion: preferredReligion ?? this.preferredReligion,
      idVerified: idVerified ?? this.idVerified,
      idVerificationUrl: idVerificationUrl ?? this.idVerificationUrl,
      verificationPhotoUrl: verificationPhotoUrl ?? this.verificationPhotoUrl,
      isVerified: isVerified ?? this.isVerified,
      incomeVerified: incomeVerified ?? this.incomeVerified,
      professionalVerified: professionalVerified ?? this.professionalVerified,
      profileApprovalStatus: profileApprovalStatus ?? this.profileApprovalStatus,
      inviteCode: inviteCode ?? this.inviteCode,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      partnerPreference: partnerPreference ?? this.partnerPreference,
      state: state ?? this.state,
      highestQualification: highestQualification ?? this.highestQualification,
      university: university ?? this.university,
      workout: workout ?? this.workout,
      pets: pets ?? this.pets,
      communicationStyle: communicationStyle ?? this.communicationStyle,
      loveLanguage: loveLanguage ?? this.loveLanguage,
      zodiac: zodiac ?? this.zodiac,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      introVideoUrl: introVideoUrl ?? this.introVideoUrl,
      introVideoThumbnailUrl: introVideoThumbnailUrl ?? this.introVideoThumbnailUrl,
      introVideoStatus: introVideoStatus ?? this.introVideoStatus,
      introVideoRejectionReason: introVideoRejectionReason ?? this.introVideoRejectionReason,
      introVideoSubmittedAt: introVideoSubmittedAt ?? this.introVideoSubmittedAt,
      skills: skills ?? this.skills,
      datingIntention: datingIntention ?? this.datingIntention,
      datingPreferences: datingPreferences ?? this.datingPreferences,
      introVideoLocalPath: introVideoLocalPath ?? this.introVideoLocalPath,
      introVideoThumbnailLocalPath:
          introVideoThumbnailLocalPath ?? this.introVideoThumbnailLocalPath,
      onboardingStep: onboardingStep ?? this.onboardingStep,
    );
  }
}
