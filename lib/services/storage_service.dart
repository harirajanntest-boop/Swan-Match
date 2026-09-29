import 'dart:io';
import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
	StorageService._();

	static final StorageService instance = StorageService._();

	final FirebaseStorage _storage = FirebaseStorage.instance;

	Future<String> uploadProfilePhoto({
		required String uid,
		required File file,
	}) async {
		// Random suffix guards against filename collisions when several photos
		// are uploaded in parallel within the same millisecond.
		final random = Random().nextInt(1000000);
		final ref = _storage
				.ref()
				.child('users')
				.child(uid)
				.child('profile')
				.child('photo_${DateTime.now().millisecondsSinceEpoch}_$random.jpg');

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

		// Returns the STORAGE PATH, never a download URL. A download URL carries
		// a token that opens the file for anyone who has the link, and the
		// profile doc it's saved in is readable by every signed-in user —
		// selfies and government IDs must only be viewable by admins, which
		// storage.rules enforce for users/{uid}/verification/** when the file
		// is opened by path (admin panel: getDownloadURL(ref(storage, path))).
		return ref.fullPath;
	}

	/// Uploads a user's intro video to `intro-videos/{uid}/intro.mp4` — this
	/// exact path (including the fixed filename, no timestamp) is required to
	/// match the deployed Storage rules, which grant write access only at
	/// `intro-videos/{userId}/intro.mp4` specifically. A previous version of
	/// this method used `users/{uid}/intro_video/...`, which instead matched
	/// the older image-only fallback rule and was rejected by Storage with a
	/// 403 for every video upload. Re-uploading (e.g. "Replace intro video")
	/// naturally overwrites the same object, which is the desired behavior.
	///
	/// NOTE: hardcoded to `video/mp4` — this matches Android's native recording
	/// format, but iOS records `.mov` (QuickTime). The plan flags this as a
	/// known cross-platform quirk to watch for; if iOS uploads need an accurate
	/// content-type, branch on `file.path`'s extension here (e.g. `video/quicktime`
	/// for `.mov`) rather than hardcoding — left as-is for now since `video_player`
	/// plays both fine client-side, and this only affects how the file is served/
	/// interpreted by other consumers (e.g. the admin web `<video>` tag).
	Future<String> uploadIntroVideo({
		required String uid,
		required File file,
		void Function(double progress)? onProgress,
	}) async {
		final ref = _storage
				.ref()
				.child('intro-videos')
				.child(uid)
				.child('intro.mp4');

		final task = ref.putFile(
				file,
				SettableMetadata(contentType: 'video/mp4'),
		);

		if (onProgress != null) {
			task.snapshotEvents.listen((snapshot) {
				if (snapshot.totalBytes > 0) {
					onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
				}
			});
		}

		await task;

		return ref.getDownloadURL();
	}

	/// Uploads the JPEG thumbnail generated locally alongside the intro video
	/// to `intro-videos/{uid}/thumbnail.jpg` — a sibling object next to
	/// `intro.mp4` under the same already-permitted Storage rule path.
	Future<String> uploadIntroVideoThumbnail({
		required String uid,
		required File file,
	}) async {
		final ref = _storage
				.ref()
				.child('intro-videos')
				.child(uid)
				.child('thumbnail.jpg');

		await ref.putFile(
				file,
				SettableMetadata(contentType: 'image/jpeg'),
		);

		return ref.getDownloadURL();
	}

	/// Uploads a connection's video response to the ephemeral top-level
	/// `temp-connection-videos/{connectionId}/...` path (NOT `users/{uid}/...`)
	/// per the Storage rules design: read/write is restricted to the two
	/// participants on the connection, never publicly/generally readable.
	Future<String> uploadConnectionResponseVideo({
		required String uid,
		required String connectionId,
		required File file,
		void Function(double progress)? onProgress,
	}) async {
		final ref = _storage
				.ref()
				.child('temp-connection-videos')
				.child(connectionId)
				.child('response.mp4');

		final task = ref.putFile(
				file,
				SettableMetadata(contentType: 'video/mp4'),
		);

		if (onProgress != null) {
			task.snapshotEvents.listen((snapshot) {
				if (snapshot.totalBytes > 0) {
					onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
				}
			});
		}

		await task;

		return ref.getDownloadURL();
	}

	/// Uploads a connection response video's JPEG thumbnail to the same
	/// ephemeral `temp-connection-videos/{connectionId}/...` path as the video
	/// itself. NOTE: relies on a Storage rule (added separately) permitting
	/// this path/content-type — the video rule at this path predates it.
	Future<String> uploadConnectionResponseVideoThumbnail({
		required String connectionId,
		required File file,
	}) async {
		final ref = _storage
				.ref()
				.child('temp-connection-videos')
				.child(connectionId)
				.child('thumbnail.jpg');

		await ref.putFile(
				file,
				SettableMetadata(contentType: 'image/jpeg'),
		);

		return ref.getDownloadURL();
	}
}
