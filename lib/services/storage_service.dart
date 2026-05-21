import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
	StorageService._();

	static final StorageService instance = StorageService._();

	final FirebaseStorage _storage = FirebaseStorage.instance;

	Future<String> uploadProfilePhoto({
		required String uid,
		required File file,
	}) async {
		final ref = _storage
				.ref()
				.child('users')
				.child(uid)
				.child('profile')
				.child('photo_${DateTime.now().millisecondsSinceEpoch}.jpg');

		await ref.putFile(
				file,
				SettableMetadata(contentType: 'image/jpeg'),
		);

		return ref.getDownloadURL();
	}

	Future<String> uploadVerificationFile({
		required String uid,
		required File file,
		required String kind,
	}) async {
		final ref = _storage
				.ref()
				.child('users')
				.child(uid)
				.child('verification')
				.child('${kind}_${DateTime.now().millisecondsSinceEpoch}.jpg');

		await ref.putFile(
				file,
				SettableMetadata(contentType: 'image/jpeg'),
		);

		return ref.getDownloadURL();
	}
}
