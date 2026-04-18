import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
	final String uid;
	final String name;
	final String email;
	final String phoneNumber;
	final String gender;
	final DateTime? dateOfBirth;
	final String bio;
	final List<String> photos;
	final List<String> images;
	final List<String> interests;
	final String location;
	final int age;
	final String subscriptionPlan;
	final bool profileVerified;
	final bool registrationCompleted;
	final DateTime createdAt;
	final DateTime updatedAt;

	const UserModel({
		required this.uid,
		this.name = '',
		this.email = '',
		this.phoneNumber = '',
		this.gender = '',
		this.dateOfBirth,
		this.bio = '',
		this.photos = const [],
		this.images = const [],
		this.interests = const [],
		this.location = '',
		this.age = 0,
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
		String? name,
		String? email,
		String? phoneNumber,
		String? gender,
		DateTime? dateOfBirth,
		String? bio,
		List<String>? photos,
		List<String>? images,
		List<String>? interests,
		String? location,
		int? age,
		String? subscriptionPlan,
		bool? profileVerified,
		bool? registrationCompleted,
		DateTime? createdAt,
		DateTime? updatedAt,
	}) {
		return UserModel(
			uid: uid ?? this.uid,
			name: name ?? this.name,
			email: email ?? this.email,
			phoneNumber: phoneNumber ?? this.phoneNumber,
			gender: gender ?? this.gender,
			dateOfBirth: dateOfBirth ?? this.dateOfBirth,
			bio: bio ?? this.bio,
			photos: photos ?? this.photos,
			images: images ?? this.images,
			interests: interests ?? this.interests,
			location: location ?? this.location,
			age: age ?? this.age,
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
			'name': name,
			'email': email,
			'phoneNumber': phoneNumber,
			'gender': gender,
			'dateOfBirth': dateOfBirth == null ? null : Timestamp.fromDate(dateOfBirth!),
			'bio': bio,
			'photos': photos,
			'images': images,
			'interests': interests,
			'location': location,
			'age': age,
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
			name: (map['name'] ?? '') as String,
			email: (map['email'] ?? '') as String,
			phoneNumber: (map['phoneNumber'] ?? '') as String,
			gender: (map['gender'] ?? '') as String,
			dateOfBirth: readDate(map['dateOfBirth']),
			bio: (map['bio'] ?? '') as String,
			photos: ((map['photos'] ?? <dynamic>[]) as List<dynamic>)
					.map((item) => item.toString())
					.toList(),
			images: ((map['images'] ?? <dynamic>[]) as List<dynamic>)
					.map((item) => item.toString())
					.toList(),
			interests: ((map['interests'] ?? <dynamic>[]) as List<dynamic>)
					.map((item) => item.toString())
					.toList(),
			location: (map['location'] ?? '') as String,
			age: (map['age'] ?? 0) as int,
			subscriptionPlan: (map['subscriptionPlan'] ?? 'free') as String,
			profileVerified: (map['profileVerified'] ?? false) as bool,
			registrationCompleted: (map['registrationCompleted'] ?? false) as bool,
			createdAt: readDate(map['createdAt']) ?? DateTime.now(),
			updatedAt: readDate(map['updatedAt']) ?? DateTime.now(),
		);
	}
}
