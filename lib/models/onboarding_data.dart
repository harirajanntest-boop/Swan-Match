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

  // ─── Legacy Fields (backward compat) ──────────────────────────────────────
  String partnerPreference;
  String state;
  int distanceKm;
  String highestQualification;
  String university;
  String workout;
  List<String> pets;
  String communicationStyle;
  String loveLanguage;
  String zodiac;

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
    this.profileVisibility = 'Curated Matches Only',
    this.partnerPreference = '',
    this.state = '',
    this.distanceKm = 50,
    this.highestQualification = '',
    this.university = '',
    this.workout = '',
    this.pets = const [],
    this.communicationStyle = '',
    this.loveLanguage = '',
    this.zodiac = '',
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

  double get completionPercentage {
    int completed = 0;
    const total = 8;

    // Step 1
    if (firstName.isNotEmpty && (selectedAge != null || dateOfBirth != null) &&
        gender.isNotEmpty && city.isNotEmpty && photos.length >= 3) completed++;
    // Step 2
    if (lookingFor.isNotEmpty && maritalStatus.isNotEmpty &&
        hasChildren != null && willingToRelocate != null) completed++;
    // Step 3
    if (educationLevel.isNotEmpty && profession.isNotEmpty &&
        incomeRange.isNotEmpty) completed++;
    // Step 4
    if (religion.isNotEmpty && primaryLanguage.isNotEmpty) completed++;
    // Step 5
    if (bio.isNotEmpty && personalityTraits.isNotEmpty &&
        interests.isNotEmpty) completed++;
    // Step 6
    if (minAgePreference > 0 && maxAgePreference > minAgePreference) completed++;
    // Step 7
    if (isVerified || verificationPhotoUrl.isNotEmpty) completed++;
    // Step 8
    if (profileVisibility.isNotEmpty) completed++;

    return completed / total;
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
      'partnerPreference': partnerPreference,
      'state': state,
      'distanceKm': distanceKm,
      'highestQualification': highestQualification,
      'university': university,
      'workout': workout,
      'pets': pets,
      'communicationStyle': communicationStyle,
      'loveLanguage': loveLanguage,
      'zodiac': zodiac,
      'onboardingStep': onboardingStep,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory OnboardingData.fromMap(Map<String, dynamic> map) {
    return OnboardingData(
      firstName: map['firstName'] ?? map['name'] ?? '',
      lastName: map['lastName'] ?? '',
      dateOfBirth: map['dateOfBirth'] != null
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
      lookingFor: map['lookingFor'] ?? '',
      maritalStatus: map['maritalStatus'] ?? '',
      hasChildren: map['hasChildren'],
      childrenDetails: map['childrenDetails'] ?? '',
      willingToRelocate: map['willingToRelocate'],
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
      familyValuesImportance: map['familyValuesImportance'] ?? 3,
      bio: map['bio'] ?? '',
      personalityTraits: List<String>.from(map['personalityTraits'] ?? []),
      interests: List<String>.from(map['interests'] ?? []),
      smoking: map['smoking'] ?? '',
      drinking: map['drinking'] ?? '',
      minAgePreference: map['minAgePreference'] ?? 18,
      maxAgePreference: map['maxAgePreference'] ?? 50,
      preferredLocation: map['preferredLocation'] ?? '',
      preferredEducation: map['preferredEducation'] ?? '',
      preferredProfession: map['preferredProfession'] ?? '',
      preferredLifestyle: List<String>.from(map['preferredLifestyle'] ?? []),
      preferredReligion: map['preferredReligion'] ?? '',
      idVerified: map['idVerified'] ?? false,
      idVerificationUrl: map['idVerificationUrl'] ?? '',
      verificationPhotoUrl: map['verificationPhotoUrl'] ?? '',
      isVerified: map['isVerified'] ?? false,
      incomeVerified: map['incomeVerified'] ?? false,
      professionalVerified: map['professionalVerified'] ?? false,
      profileApprovalStatus: map['profileApprovalStatus'] ?? 'pending',
      inviteCode: map['inviteCode'] ?? '',
      profileVisibility: map['profileVisibility'] ?? 'Curated Matches Only',
      partnerPreference: map['partnerPreference'] ?? '',
      state: map['state'] ?? '',
      distanceKm: map['distanceKm'] ?? 50,
      highestQualification: map['highestQualification'] ?? '',
      university: map['university'] ?? '',
      workout: map['workout'] ?? '',
      pets: List<String>.from(map['pets'] ?? []),
      communicationStyle: map['communicationStyle'] ?? '',
      loveLanguage: map['loveLanguage'] ?? '',
      zodiac: map['zodiac'] ?? '',
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
    int? distanceKm,
    String? highestQualification,
    String? university,
    String? workout,
    List<String>? pets,
    String? communicationStyle,
    String? loveLanguage,
    String? zodiac,
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
      distanceKm: distanceKm ?? this.distanceKm,
      highestQualification: highestQualification ?? this.highestQualification,
      university: university ?? this.university,
      workout: workout ?? this.workout,
      pets: pets ?? this.pets,
      communicationStyle: communicationStyle ?? this.communicationStyle,
      loveLanguage: loveLanguage ?? this.loveLanguage,
      zodiac: zodiac ?? this.zodiac,
      onboardingStep: onboardingStep ?? this.onboardingStep,
    );
  }
}
