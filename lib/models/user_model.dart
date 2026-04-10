import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
	final String uid;
	final String profileFor;
	final String motherTongue;
	final String name;
	final String email;
	final String phoneNumber;
	final String gender;
	final DateTime? dateOfBirth;
	final String height;
	final String physicalStatus;
	final String maritalStatus;
	final String religion;
	final String caste;
	final String subCaste;
	final String dosham;
	final String country;
	final String state;
	final String city;
	final String educationDegree;
	final String employmentSector;
	final String occupation;
	final String annualIncome;
	final String currency;
	final String familyStatus;
	final String aboutMe;
	final Map<String, dynamic> partnerPreferences;
	final Map<String, dynamic> lifestyle;
	final List<String> interests;
	final String subscriptionPlan;
	final bool profileVerified;
	final bool registrationCompleted;
	final DateTime createdAt;
	final DateTime updatedAt;

	const UserModel({
		required this.uid,
		this.profileFor = '',
		this.motherTongue = '',
		this.name = '',
		this.email = '',
		this.phoneNumber = '',
		this.gender = '',
		this.dateOfBirth,
		this.height = '',
		this.physicalStatus = '',
		this.maritalStatus = '',
		this.religion = '',
		this.caste = '',
		this.subCaste = '',
		this.dosham = '',
		this.country = '',
		this.state = '',
		this.city = '',
		this.educationDegree = '',
		this.employmentSector = '',
		this.occupation = '',
		this.annualIncome = '',
		this.currency = '',
		this.familyStatus = '',
		this.aboutMe = '',
		this.partnerPreferences = const {},
		this.lifestyle = const {},
		this.interests = const [],
		this.subscriptionPlan = 'free',
		this.profileVerified = false,
		this.registrationCompleted = false,
		required this.createdAt,
		required this.updatedAt,
	});

	factory UserModel.create(String uid) {
		final now = DateTime.now();
		return UserModel(uid: uid, createdAt: now, updatedAt: now);
	}

	UserModel copyWith({
		String? uid,
		String? profileFor,
		String? motherTongue,
		String? name,
		String? email,
		String? phoneNumber,
		String? gender,
		DateTime? dateOfBirth,
		String? height,
		String? physicalStatus,
		String? maritalStatus,
		String? religion,
		String? caste,
		String? subCaste,
		String? dosham,
		String? country,
		String? state,
		String? city,
		String? educationDegree,
		String? employmentSector,
		String? occupation,
		String? annualIncome,
		String? currency,
		String? familyStatus,
		String? aboutMe,
		Map<String, dynamic>? partnerPreferences,
		Map<String, dynamic>? lifestyle,
		List<String>? interests,
		String? subscriptionPlan,
		bool? profileVerified,
		bool? registrationCompleted,
		DateTime? createdAt,
		DateTime? updatedAt,
	}) {
		return UserModel(
			uid: uid ?? this.uid,
			profileFor: profileFor ?? this.profileFor,
			motherTongue: motherTongue ?? this.motherTongue,
			name: name ?? this.name,
			email: email ?? this.email,
			phoneNumber: phoneNumber ?? this.phoneNumber,
			gender: gender ?? this.gender,
			dateOfBirth: dateOfBirth ?? this.dateOfBirth,
			height: height ?? this.height,
			physicalStatus: physicalStatus ?? this.physicalStatus,
			maritalStatus: maritalStatus ?? this.maritalStatus,
			religion: religion ?? this.religion,
			caste: caste ?? this.caste,
			subCaste: subCaste ?? this.subCaste,
			dosham: dosham ?? this.dosham,
			country: country ?? this.country,
			state: state ?? this.state,
			city: city ?? this.city,
			educationDegree: educationDegree ?? this.educationDegree,
			employmentSector: employmentSector ?? this.employmentSector,
			occupation: occupation ?? this.occupation,
			annualIncome: annualIncome ?? this.annualIncome,
			currency: currency ?? this.currency,
			familyStatus: familyStatus ?? this.familyStatus,
			aboutMe: aboutMe ?? this.aboutMe,
			partnerPreferences: partnerPreferences ?? this.partnerPreferences,
			lifestyle: lifestyle ?? this.lifestyle,
			interests: interests ?? this.interests,
			subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
			profileVerified: profileVerified ?? this.profileVerified,
			registrationCompleted: registrationCompleted ?? this.registrationCompleted,
			createdAt: createdAt ?? this.createdAt,
			updatedAt: updatedAt ?? this.updatedAt,
		);
	}

	Map<String, dynamic> toMap() {
		return {
			'uid': uid,
			'profileFor': profileFor,
			'motherTongue': motherTongue,
			'name': name,
			'email': email,
			'phoneNumber': phoneNumber,
			'gender': gender,
			'dateOfBirth': dateOfBirth == null ? null : Timestamp.fromDate(dateOfBirth!),
			'height': height,
			'physicalStatus': physicalStatus,
			'maritalStatus': maritalStatus,
			'religion': religion,
			'caste': caste,
			'subCaste': subCaste,
			'dosham': dosham,
			'country': country,
			'state': state,
			'city': city,
			'educationDegree': educationDegree,
			'employmentSector': employmentSector,
			'occupation': occupation,
			'annualIncome': annualIncome,
			'currency': currency,
			'familyStatus': familyStatus,
			'aboutMe': aboutMe,
			'partnerPreferences': partnerPreferences,
			'lifestyle': lifestyle,
			'interests': interests,
			'subscriptionPlan': subscriptionPlan,
			'profileVerified': profileVerified,
			'registrationCompleted': registrationCompleted,
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
			profileFor: (map['profileFor'] ?? '') as String,
			motherTongue: (map['motherTongue'] ?? '') as String,
			name: (map['name'] ?? '') as String,
			email: (map['email'] ?? '') as String,
			phoneNumber: (map['phoneNumber'] ?? '') as String,
			gender: (map['gender'] ?? '') as String,
			dateOfBirth: readDate(map['dateOfBirth']),
			height: (map['height'] ?? '') as String,
			physicalStatus: (map['physicalStatus'] ?? '') as String,
			maritalStatus: (map['maritalStatus'] ?? '') as String,
			religion: (map['religion'] ?? '') as String,
			caste: (map['caste'] ?? '') as String,
			subCaste: (map['subCaste'] ?? '') as String,
			dosham: (map['dosham'] ?? '') as String,
			country: (map['country'] ?? '') as String,
			state: (map['state'] ?? '') as String,
			city: (map['city'] ?? '') as String,
			educationDegree: (map['educationDegree'] ?? '') as String,
			employmentSector: (map['employmentSector'] ?? '') as String,
			occupation: (map['occupation'] ?? '') as String,
			annualIncome: (map['annualIncome'] ?? '') as String,
			currency: (map['currency'] ?? '') as String,
			familyStatus: (map['familyStatus'] ?? '') as String,
			aboutMe: (map['aboutMe'] ?? '') as String,
			partnerPreferences: Map<String, dynamic>.from(
				(map['partnerPreferences'] ?? <String, dynamic>{}) as Map,
			),
			lifestyle: Map<String, dynamic>.from(
				(map['lifestyle'] ?? <String, dynamic>{}) as Map,
			),
			interests: ((map['interests'] ?? <dynamic>[]) as List<dynamic>)
					.map((item) => item.toString())
					.toList(),
			subscriptionPlan: (map['subscriptionPlan'] ?? 'free') as String,
			profileVerified: (map['profileVerified'] ?? false) as bool,
			registrationCompleted: (map['registrationCompleted'] ?? false) as bool,
			createdAt: readDate(map['createdAt']) ?? DateTime.now(),
			updatedAt: readDate(map['updatedAt']) ?? DateTime.now(),
		);
	}
}
