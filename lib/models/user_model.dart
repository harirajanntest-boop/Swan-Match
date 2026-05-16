import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
	final String uid;
	final String name;
	final String firstName;
	final String lastName;
	final String email;
	final String phoneNumber;
	final String gender;
	final bool showGender;
	final DateTime? dateOfBirth;
	final String bio;
	final List<String> photos;
	final List<String> images;
	final String profilePicture;
	final List<String> interests;
	final String location;
	final String city;
	final String state;
	final String country;
	final int age;
	final String subscriptionPlan;
	final bool profileVerified;
	final String verificationPhotoUrl;
	final bool registrationCompleted;
	final String partnerPreference;
	final int minAgePreference;
	final int maxAgePreference;
	final int distanceKm;
	final String lookingFor;
	final String highestQualification;
	final String university;
	final String profession;
	final String drinking;
	final String smoking;
	final String workout;
	final List<String> pets;
	final String communicationStyle;
	final String loveLanguage;
	final String educationLevel;
	final String zodiac;

	// ─── New Premium Onboarding Fields ─────────────────────────────────────
	final String maritalStatus;
	final bool? hasChildren;
	final String childrenDetails;
	final bool? willingToRelocate;
	final String industry;
	final String incomeRange;
	final String netWorthRange;
	final List<String> lifestyleTags;
	final String religion;
	final String spiritualLevel;
	final String ethnicity;
	final String primaryLanguage;
	final List<String> otherLanguages;
	final Map<String, String> languageFluency;
	final int familyValuesImportance;
	final List<String> personalityTraits;
	final String preferredLocation;
	final String preferredEducation;
	final String preferredProfession;
	final List<String> preferredLifestyle;
	final String preferredReligion;
	final bool idVerified;
	final String idVerificationUrl;
	final bool incomeVerified;
	final bool professionalVerified;
	final String profileApprovalStatus;
	final String inviteCode;
	final String profileVisibility;
	final int onboardingStep;

	final DateTime createdAt;
	final DateTime updatedAt;

	const UserModel({
		required this.uid,
		this.name = '',
		this.firstName = '',
		this.lastName = '',
		this.email = '',
		this.phoneNumber = '',
		this.gender = '',
		this.showGender = true,
		this.dateOfBirth,
		this.bio = '',
		this.photos = const [],
		this.images = const [],
		this.profilePicture = '',
		this.interests = const [],
		this.location = '',
		this.city = '',
		this.state = '',
		this.country = '',
		this.age = 0,
		this.subscriptionPlan = 'free',
		this.profileVerified = false,
		this.verificationPhotoUrl = '',
		this.registrationCompleted = false,
		this.partnerPreference = '',
		this.minAgePreference = 18,
		this.maxAgePreference = 99,
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
		// New fields
		this.maritalStatus = '',
		this.hasChildren,
		this.childrenDetails = '',
		this.willingToRelocate,
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
		this.personalityTraits = const [],
		this.preferredLocation = '',
		this.preferredEducation = '',
		this.preferredProfession = '',
		this.preferredLifestyle = const [],
		this.preferredReligion = '',
		this.idVerified = false,
		this.idVerificationUrl = '',
		this.incomeVerified = false,
		this.professionalVerified = false,
		this.profileApprovalStatus = 'pending',
		this.inviteCode = '',
		this.profileVisibility = 'Public',
		this.onboardingStep = 0,
		required this.createdAt,
		required this.updatedAt,
	});

	factory UserModel.create(String uid) {
		final now = DateTime.now();
		return UserModel(uid: uid, createdAt: now, updatedAt: now);
	}

	UserModel copyWith({
		String? uid,
		String? name,
		String? firstName,
		String? lastName,
		String? email,
		String? phoneNumber,
		String? gender,
		bool? showGender,
		DateTime? dateOfBirth,
		String? bio,
		List<String>? photos,
		List<String>? images,
		String? profilePicture,
		List<String>? interests,
		String? location,
		String? city,
		String? state,
		String? country,
		int? age,
		String? subscriptionPlan,
		bool? profileVerified,
		String? verificationPhotoUrl,
		bool? registrationCompleted,
		String? partnerPreference,
		int? minAgePreference,
		int? maxAgePreference,
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
		String? maritalStatus,
		bool? hasChildren,
		String? childrenDetails,
		bool? willingToRelocate,
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
		List<String>? personalityTraits,
		String? preferredLocation,
		String? preferredEducation,
		String? preferredProfession,
		List<String>? preferredLifestyle,
		String? preferredReligion,
		bool? idVerified,
		String? idVerificationUrl,
		bool? incomeVerified,
		bool? professionalVerified,
		String? profileApprovalStatus,
		String? inviteCode,
		String? profileVisibility,
		int? onboardingStep,
		DateTime? createdAt,
		DateTime? updatedAt,
	}) {
		return UserModel(
			uid: uid ?? this.uid,
			name: name ?? this.name,
			firstName: firstName ?? this.firstName,
			lastName: lastName ?? this.lastName,
			email: email ?? this.email,
			phoneNumber: phoneNumber ?? this.phoneNumber,
			gender: gender ?? this.gender,
			showGender: showGender ?? this.showGender,
			dateOfBirth: dateOfBirth ?? this.dateOfBirth,
			bio: bio ?? this.bio,
			photos: photos ?? this.photos,
			images: images ?? this.images,
			profilePicture: profilePicture ?? this.profilePicture,
			interests: interests ?? this.interests,
			location: location ?? this.location,
			city: city ?? this.city,
			state: state ?? this.state,
			country: country ?? this.country,
			age: age ?? this.age,
			subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
			profileVerified: profileVerified ?? this.profileVerified,
			verificationPhotoUrl: verificationPhotoUrl ?? this.verificationPhotoUrl,
			registrationCompleted: registrationCompleted ?? this.registrationCompleted,
			partnerPreference: partnerPreference ?? this.partnerPreference,
			minAgePreference: minAgePreference ?? this.minAgePreference,
			maxAgePreference: maxAgePreference ?? this.maxAgePreference,
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
			maritalStatus: maritalStatus ?? this.maritalStatus,
			hasChildren: hasChildren ?? this.hasChildren,
			childrenDetails: childrenDetails ?? this.childrenDetails,
			willingToRelocate: willingToRelocate ?? this.willingToRelocate,
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
			personalityTraits: personalityTraits ?? this.personalityTraits,
			preferredLocation: preferredLocation ?? this.preferredLocation,
			preferredEducation: preferredEducation ?? this.preferredEducation,
			preferredProfession: preferredProfession ?? this.preferredProfession,
			preferredLifestyle: preferredLifestyle ?? this.preferredLifestyle,
			preferredReligion: preferredReligion ?? this.preferredReligion,
			idVerified: idVerified ?? this.idVerified,
			idVerificationUrl: idVerificationUrl ?? this.idVerificationUrl,
			incomeVerified: incomeVerified ?? this.incomeVerified,
			professionalVerified: professionalVerified ?? this.professionalVerified,
			profileApprovalStatus: profileApprovalStatus ?? this.profileApprovalStatus,
			inviteCode: inviteCode ?? this.inviteCode,
			profileVisibility: profileVisibility ?? this.profileVisibility,
			onboardingStep: onboardingStep ?? this.onboardingStep,
			createdAt: createdAt ?? this.createdAt,
			updatedAt: updatedAt ?? this.updatedAt,
		);
	}

	Map<String, dynamic> toMap() {
		return {
			'uid': uid,
			'name': name,
			'firstName': firstName,
			'lastName': lastName,
			'email': email,
			'phoneNumber': phoneNumber,
			'gender': gender,
			'showGender': showGender,
			'dateOfBirth': dateOfBirth == null ? null : Timestamp.fromDate(dateOfBirth!),
			'bio': bio,
			'photos': photos,
			'images': images,
			'profilePicture': profilePicture,
			'interests': interests,
			'location': location,
			'city': city,
			'state': state,
			'country': country,
			'age': age,
			'subscriptionPlan': subscriptionPlan,
			'profileVerified': profileVerified,
			'verificationPhotoUrl': verificationPhotoUrl,
			'registrationCompleted': registrationCompleted,
			'partnerPreference': partnerPreference,
			'minAgePreference': minAgePreference,
			'maxAgePreference': maxAgePreference,
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
			// New fields
			'maritalStatus': maritalStatus,
			'hasChildren': hasChildren,
			'childrenDetails': childrenDetails,
			'willingToRelocate': willingToRelocate,
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
			'personalityTraits': personalityTraits,
			'preferredLocation': preferredLocation,
			'preferredEducation': preferredEducation,
			'preferredProfession': preferredProfession,
			'preferredLifestyle': preferredLifestyle,
			'preferredReligion': preferredReligion,
			'idVerified': idVerified,
			'idVerificationUrl': idVerificationUrl,
			'incomeVerified': incomeVerified,
			'professionalVerified': professionalVerified,
			'profileApprovalStatus': profileApprovalStatus,
			'inviteCode': inviteCode,
			'profileVisibility': profileVisibility,
			'onboardingStep': onboardingStep,
			'createdAt': Timestamp.fromDate(createdAt),
			'updatedAt': Timestamp.fromDate(updatedAt),
		};
	}

	factory UserModel.fromMap(Map<String, dynamic> map) {
		DateTime? readDate(dynamic value) {
			if (value is Timestamp) return value.toDate();
			return null;
		}

		return UserModel(
			uid: map['uid'] as String,
			name: (map['name'] ?? '') as String,
			firstName: (map['firstName'] ?? '') as String,
			lastName: (map['lastName'] ?? '') as String,
			email: (map['email'] ?? '') as String,
			phoneNumber: (map['phoneNumber'] ?? '') as String,
			gender: (map['gender'] ?? '') as String,
			showGender: (map['showGender'] ?? true) as bool,
			dateOfBirth: readDate(map['dateOfBirth']),
			bio: (map['bio'] ?? '') as String,
			photos: ((map['photos'] ?? <dynamic>[]) as List<dynamic>)
					.map((item) => item.toString())
					.toList(),
			images: ((map['images'] ?? <dynamic>[]) as List<dynamic>)
					.map((item) => item.toString())
					.toList(),
			profilePicture: (map['profilePicture'] ?? '') as String,
			interests: ((map['interests'] ?? <dynamic>[]) as List<dynamic>)
					.map((item) => item.toString())
					.toList(),
			location: (map['location'] ?? '') as String,
			city: (map['city'] ?? '') as String,
			state: (map['state'] ?? '') as String,
			country: (map['country'] ?? '') as String,
			age: (map['age'] ?? 0) as int,
			subscriptionPlan: (map['subscriptionPlan'] ?? 'free') as String,
			profileVerified: (map['profileVerified'] ?? map['isVerified'] ?? false) as bool,
			verificationPhotoUrl: (map['verificationPhotoUrl'] ?? '') as String,
			registrationCompleted: (map['registrationCompleted'] ?? false) as bool,
			partnerPreference: (map['partnerPreference'] ?? '') as String,
			minAgePreference: (map['minAgePreference'] ?? 18) as int,
			maxAgePreference: (map['maxAgePreference'] ?? 99) as int,
			distanceKm: (map['distanceKm'] ?? 50) as int,
			lookingFor: (map['lookingFor'] ?? '') as String,
			highestQualification: (map['highestQualification'] ?? '') as String,
			university: (map['university'] ?? '') as String,
			profession: (map['profession'] ?? '') as String,
			drinking: (map['drinking'] ?? '') as String,
			smoking: (map['smoking'] ?? '') as String,
			workout: (map['workout'] ?? '') as String,
			pets: ((map['pets'] ?? <dynamic>[]) as List<dynamic>)
					.map((item) => item.toString())
					.toList(),
			communicationStyle: (map['communicationStyle'] ?? '') as String,
			loveLanguage: (map['loveLanguage'] ?? '') as String,
			educationLevel: (map['educationLevel'] ?? '') as String,
			zodiac: (map['zodiac'] ?? '') as String,
			// New fields
			maritalStatus: (map['maritalStatus'] ?? '') as String,
			hasChildren: map['hasChildren'] as bool?,
			childrenDetails: (map['childrenDetails'] ?? '') as String,
			willingToRelocate: map['willingToRelocate'] as bool?,
			industry: (map['industry'] ?? '') as String,
			incomeRange: (map['incomeRange'] ?? '') as String,
			netWorthRange: (map['netWorthRange'] ?? '') as String,
			lifestyleTags: ((map['lifestyleTags'] ?? <dynamic>[]) as List<dynamic>)
					.map((item) => item.toString())
					.toList(),
			religion: (map['religion'] ?? '') as String,
			spiritualLevel: (map['spiritualLevel'] ?? '') as String,
			ethnicity: (map['ethnicity'] ?? '') as String,
			primaryLanguage: (map['primaryLanguage'] ?? '') as String,
			otherLanguages: ((map['otherLanguages'] ?? <dynamic>[]) as List<dynamic>)
					.map((item) => item.toString())
					.toList(),
			languageFluency: ((map['languageFluency'] ?? <String, dynamic>{}) as Map<String, dynamic>)
					.map((k, v) => MapEntry(k, v.toString())),
			familyValuesImportance: (map['familyValuesImportance'] ?? 3) as int,
			personalityTraits: ((map['personalityTraits'] ?? <dynamic>[]) as List<dynamic>)
					.map((item) => item.toString())
					.toList(),
			preferredLocation: (map['preferredLocation'] ?? '') as String,
			preferredEducation: (map['preferredEducation'] ?? '') as String,
			preferredProfession: (map['preferredProfession'] ?? '') as String,
			preferredLifestyle: ((map['preferredLifestyle'] ?? <dynamic>[]) as List<dynamic>)
					.map((item) => item.toString())
					.toList(),
			preferredReligion: (map['preferredReligion'] ?? '') as String,
			idVerified: (map['idVerified'] ?? false) as bool,
			idVerificationUrl: (map['idVerificationUrl'] ?? '') as String,
			incomeVerified: (map['incomeVerified'] ?? false) as bool,
			professionalVerified: (map['professionalVerified'] ?? false) as bool,
			profileApprovalStatus: (map['profileApprovalStatus'] ?? 'pending') as String,
			inviteCode: (map['inviteCode'] ?? '') as String,
			profileVisibility: (map['profileVisibility'] ?? 'Public') as String,
			onboardingStep: (map['onboardingStep'] ?? 0) as int,
			createdAt: readDate(map['createdAt']) ?? DateTime.now(),
			updatedAt: readDate(map['updatedAt']) ?? DateTime.now(),
		);
	}
}
