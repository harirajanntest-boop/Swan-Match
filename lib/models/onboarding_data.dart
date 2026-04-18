class OnboardingData {
  // Screen 1: First Name
  String firstName;
  
  // Screen 2: Date of Birth
  DateTime? dateOfBirth;
  
  // Screen 3: Gender
  String gender;
  bool showGender;
  
  // Screen 4: Partner Preference
  String partnerPreference;
  
  // Screen 5: Location
  String city;
  String state;
  String country;
  
  // Screen 6: Distance Preference
  int distanceKm;
  
  // Screen 7: What Are You Looking For?
  String lookingFor;
  
  // Screen 8: Education & Profession
  String highestQualification;
  String university;
  String profession;
  
  // Screen 9: Lifestyle Habits
  String drinking;
  String smoking;
  String workout;
  List<String> pets;
  
  // Screen 10: Values & Identity
  String communicationStyle;
  String loveLanguage;
  String educationLevel;
  String zodiac;
  
  // Screen 11: Interests
  List<String> interests;
  
  // Screen 12: Photos
  List<String> photos;
  String profilePicture; // First image from photos list
  
  // Screen 13: Bio
  String bio;
  
  // Metadata
  DateTime createdAt;

  OnboardingData({
    this.firstName = '',
    this.dateOfBirth,
    this.gender = '',
    this.showGender = true,
    this.partnerPreference = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.distanceKm = 50,
    this.lookingFor = '',
    this.highestQualification = '',
    this.university = '',
    this.profession = '',
    this.drinking = '',
    this.smoking = '',
    this.workout = '',
    this.pets = const [],
    this.communicationStyle = '',
    this.loveLanguage = '',
    this.educationLevel = '',
    this.zodiac = '',
    this.interests = const [],
    this.photos = const [],
    this.profilePicture = '',
    this.bio = '',
  }) : createdAt = DateTime.now();

  // Calculate age from date of birth
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month || 
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  // Check if user is 18+ years old
  bool get isAdult {
    final userAge = age;
    return userAge != null && userAge >= 18;
  }

  // Helper to get completion percentage for progress
  double get completionPercentage {
    int completedFields = 0;
    int totalFields = 14; // Total number of main sections
    
    if (firstName.isNotEmpty) completedFields++;
    if (dateOfBirth != null) completedFields++;
    if (gender.isNotEmpty) completedFields++;
    if (partnerPreference.isNotEmpty) completedFields++;
    if (city.isNotEmpty && country.isNotEmpty) completedFields++;
    if (lookingFor.isNotEmpty) completedFields++;
    if (highestQualification.isNotEmpty) completedFields++;
    if (drinking.isNotEmpty && smoking.isNotEmpty && workout.isNotEmpty && pets.isNotEmpty) completedFields++;
    if (communicationStyle.isNotEmpty && loveLanguage.isNotEmpty && 
        educationLevel.isNotEmpty && zodiac.isNotEmpty) completedFields++;
    if (interests.isNotEmpty) completedFields++;
    if (photos.isNotEmpty) completedFields++;
    if (bio.isNotEmpty) completedFields++;
    
    return completedFields / totalFields;
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'showGender': showGender,
      'partnerPreference': partnerPreference,
      'city': city,
      'state': state,
      'country': country,
      'distanceKm': distanceKm,
      'lookingFor': lookingFor,
      'highestQualification': highestQualification,
      'university': university,
      'profession': profession,
      'drinking': drinking,
      'smoking': smoking,
      'workout': workout,
      'pets': pets,
      'communicationStyle': communicationStyle,
      'loveLanguage': loveLanguage,
      'educationLevel': educationLevel,
      'zodiac': zodiac,
      'interests': interests,
      'photos': photos,
      'profilePicture': profilePicture,
      'bio': bio,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from map (for loading saved data)
  factory OnboardingData.fromMap(Map<String, dynamic> map) {
    return OnboardingData(
      firstName: map['firstName'] ?? '',
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.parse(map['dateOfBirth'])
          : null,
      gender: map['gender'] ?? '',
      showGender: map['showGender'] ?? true,
      partnerPreference: map['partnerPreference'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      country: map['country'] ?? '',
      distanceKm: map['distanceKm'] ?? 50,
      lookingFor: map['lookingFor'] ?? '',
      highestQualification: map['highestQualification'] ?? '',
      university: map['university'] ?? '',
      profession: map['profession'] ?? '',
      drinking: map['drinking'] ?? '',
      smoking: map['smoking'] ?? '',
      workout: map['workout'] ?? '',
      pets: List<String>.from(map['pets'] ?? []),
      communicationStyle: map['communicationStyle'] ?? '',
      loveLanguage: map['loveLanguage'] ?? '',
      educationLevel: map['educationLevel'] ?? '',
      zodiac: map['zodiac'] ?? '',
      interests: List<String>.from(map['interests'] ?? []),
      photos: List<String>.from(map['photos'] ?? []),
      profilePicture: map['profilePicture'] ?? '',
      bio: map['bio'] ?? '',
    );
  }

  // Copy with for updates
  OnboardingData copyWith({
    String? firstName,
    DateTime? dateOfBirth,
    String? gender,
    bool? showGender,
    String? partnerPreference,
    String? city,
    String? state,
    String? country,
    int? distanceKm,
    String? lookingFor,
    String? highestQualification,
    String? university,
    String? profession,
    String? drinking,
    String? smoking,
    String? workout,
    List<String>? pets,
    String? communicationStyle,
    String? loveLanguage,
    String? educationLevel,
    String? zodiac,
    List<String>? interests,
    List<String>? photos,
    String? profilePicture,
    String? bio,
  }) {
    return OnboardingData(
      firstName: firstName ?? this.firstName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      showGender: showGender ?? this.showGender,
      partnerPreference: partnerPreference ?? this.partnerPreference,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      distanceKm: distanceKm ?? this.distanceKm,
      lookingFor: lookingFor ?? this.lookingFor,
      highestQualification: highestQualification ?? this.highestQualification,
      university: university ?? this.university,
      profession: profession ?? this.profession,
      drinking: drinking ?? this.drinking,
      smoking: smoking ?? this.smoking,
      workout: workout ?? this.workout,
      pets: pets ?? this.pets,
      communicationStyle: communicationStyle ?? this.communicationStyle,
      loveLanguage: loveLanguage ?? this.loveLanguage,
      educationLevel: educationLevel ?? this.educationLevel,
      zodiac: zodiac ?? this.zodiac,
      interests: interests ?? this.interests,
      photos: photos ?? this.photos,
      profilePicture: profilePicture ?? this.profilePicture,
      bio: bio ?? this.bio,
    );
  }
}
