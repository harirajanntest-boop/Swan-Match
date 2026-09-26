import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/stream_utils.dart';
import '../models/connection_model.dart';
import 'storage_service.dart';

/// Outcome of [ConnectionService.sendConnectionRequest]. Mirrors the style of
/// `InterestSendResult` in `interest_service.dart` so callers can branch on a
/// typed result instead of parsing exception strings.
enum ConnectionSendResult {
	sent,
	alreadyPending,
	alreadyConnected,
	dailyLimitReached,
	receiverNotEligible,
	failed,
}

/// Result wrapper carrying an optional human-readable reason alongside the
/// typed [ConnectionSendResult], e.g. for surfacing the callable's error
/// message verbatim when [ConnectionSendResult.failed] is returned.
class ConnectionSendOutcome {
	final ConnectionSendResult result;
	final String? message;

	const ConnectionSendOutcome(this.result, {this.message});
}

/// Video-first "connection" requests: sends a topic-based video response to
/// another user, and reacts to accept/decline. Mirrors `InterestService`'s
/// singleton/style, but the actual Firestore writes for submit/respond are
/// server-side (Cloud Functions), per the cross-repo contract — this service
/// only uploads the video, invokes the callable, and exposes read-only
/// stream watchers.
class ConnectionService {
	ConnectionService._();

	static final ConnectionService instance = ConnectionService._();

	final FirebaseFirestore _firestore = FirebaseFirestore.instance;
	final FirebaseAuth _auth = FirebaseAuth.instance;
	final FirebaseFunctions _functions = FirebaseFunctions.instance;

	CollectionReference<Map<String, dynamic>> get _connections =>
			_firestore.collection('connections');

	Stream<String?> get _uidStream =>
			_auth.authStateChanges().map((u) => u?.uid).distinct();

	/// Sorted-uid join, same convention as `ChatService.chatIdFor` and the
	/// existing `matches`/`chats` id convention.
	String connectionIdFor(String uidA, String uidB) {
		final ids = [uidA, uidB]..sort();
		return ids.join('_');
	}

	/// Uploads [videoFile] to the ephemeral `temp-connection-videos/{id}/...`
	/// path, then calls the `submitConnectionRequest` Cloud Function so the
	/// server can enforce the daily-Connects quota and write the `connections`
	/// doc. The client never writes the `connections` doc directly.
	Future<ConnectionSendOutcome> sendConnectionRequest({
		required String receiverId,
		required String topic,
		required File videoFile,
		File? thumbnailFile,
		void Function(double progress)? onProgress,
	}) async {
		final user = _auth.currentUser;
		if (user == null || receiverId.isEmpty || receiverId == user.uid) {
			return const ConnectionSendOutcome(ConnectionSendResult.failed);
		}

		final connectionId = connectionIdFor(user.uid, receiverId);

		String videoUrl;
		try {
			videoUrl = await StorageService.instance.uploadConnectionResponseVideo(
				uid: user.uid,
				connectionId: connectionId,
				file: videoFile,
				onProgress: onProgress,
			);
		} catch (e) {
			return ConnectionSendOutcome(
				ConnectionSendResult.failed,
				message: 'Could not upload your video. Please try again.',
			);
		}

		// Thumbnail upload is best-effort — a nice-to-have preview image, not
		// required for the connection request to send. Never block or fail
		// the overall send because of it.
		String? videoThumbnailUrl;
		if (thumbnailFile != null) {
			try {
				videoThumbnailUrl = await StorageService.instance
						.uploadConnectionResponseVideoThumbnail(
					connectionId: connectionId,
					file: thumbnailFile,
				);
			} catch (e) {
				debugPrint('Connection response video thumbnail upload error: $e');
			}
		}

		try {
			final callable = _functions.httpsCallable('submitConnectionRequest');
			await callable.call(<String, dynamic>{
				'receiverId': receiverId,
				'topic': topic,
				'videoUrl': videoUrl,
				if (videoThumbnailUrl != null && videoThumbnailUrl.isNotEmpty)
					'videoThumbnailUrl': videoThumbnailUrl,
			});
			return const ConnectionSendOutcome(ConnectionSendResult.sent);
		} on FirebaseFunctionsException catch (e) {
			return ConnectionSendOutcome(_mapFunctionsError(e), message: e.message);
		} catch (e) {
			return ConnectionSendOutcome(
				ConnectionSendResult.failed,
				message: 'Could not send your connection request. Please try again.',
			);
		}
	}

	/// Maps the callable's error `code`/`message` to a typed result. The
	/// backend is the source of truth for these strings (see
	/// `functions/index.js` `submitConnectionRequest`); this is a best-effort
	/// mapping so the UI can show a specific message instead of a generic one.
	ConnectionSendResult _mapFunctionsError(FirebaseFunctionsException e) {
		final code = e.code.toLowerCase();
		final message = (e.message ?? '').toLowerCase();

		if (code == 'resource-exhausted' || message.contains('limit') || message.contains('quota')) {
			return ConnectionSendResult.dailyLimitReached;
		}
		if (message.contains('pending')) {
			return ConnectionSendResult.alreadyPending;
		}
		if (message.contains('already connected') || message.contains('accepted')) {
			return ConnectionSendResult.alreadyConnected;
		}
		if (code == 'failed-precondition' ||
				message.contains('not eligible') ||
				message.contains('intro video')) {
			return ConnectionSendResult.receiverNotEligible;
		}
		return ConnectionSendResult.failed;
	}

	/// Calls the `respondToConnection` callable — the only supported path for
	/// accept/decline. Accept atomically creates the chat + deletes the temp
	/// video server-side.
	Future<void> respondToConnection({
		required String connectionId,
		required bool accept,
	}) async {
		final callable = _functions.httpsCallable('respondToConnection');
		await callable.call(<String, dynamic>{
			'connectionId': connectionId,
			'action': accept ? 'accept' : 'decline',
		});
	}

	/// Direct Firestore read — whether the current user has an accepted
	/// connection with [otherUserId]. Used by `SubscriptionLimitsService` as
	/// the chat-unlock gate (replaces `JourneyService.chatUnlockStatus`).
	Future<bool> hasAcceptedConnection(String otherUserId) async {
		final uid = _auth.currentUser?.uid;
		if (uid == null || otherUserId.isEmpty) return false;

		final id = connectionIdFor(uid, otherUserId);
		final doc = await _connections.doc(id).get();
		final data = doc.data();
		if (data == null) return false;
		return (data['status'] ?? '').toString().toLowerCase() == 'accepted';
	}

	Stream<List<ConnectionModel>> watchReceivedConnections() {
		return switchMap(_uidStream, (uid) {
			if (uid == null) return Stream.value(<ConnectionModel>[]);
			return _connections
					.where('receiverId', isEqualTo: uid)
					.snapshots()
					.map((snapshot) {
						final items = snapshot.docs
								.map((doc) => ConnectionModel.fromDoc(doc))
								.toList();
						items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
						return items;
					});
		});
	}

	Stream<List<ConnectionModel>> watchSentConnections() {
		return switchMap(_uidStream, (uid) {
			if (uid == null) return Stream.value(<ConnectionModel>[]);
			return _connections
					.where('senderId', isEqualTo: uid)
					.snapshots()
					.map((snapshot) {
						final items = snapshot.docs
								.map((doc) => ConnectionModel.fromDoc(doc))
								.toList();
						items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
						return items;
					});
		});
	}

	/// Accepted connections in either direction (sent or received).
	Stream<List<ConnectionModel>> watchAcceptedConnections() {
		return switchMap(_uidStream, (uid) {
			if (uid == null) return Stream.value(<ConnectionModel>[]);
			return switchMap(
				_connections.where('senderId', isEqualTo: uid).snapshots(),
				(sentSnapshot) {
					return _connections
							.where('receiverId', isEqualTo: uid)
							.snapshots()
							.map((receivedSnapshot) {
								final items = <ConnectionModel>[
									...sentSnapshot.docs.map((doc) => ConnectionModel.fromDoc(doc)),
									...receivedSnapshot.docs.map((doc) => ConnectionModel.fromDoc(doc)),
								].where((c) => c.status.toLowerCase() == 'accepted').toList();
								items.sort((a, b) =>
										(b.resolvedAt ?? b.createdAt).compareTo(a.resolvedAt ?? a.createdAt));
								return items;
							});
				},
			);
		});
	}

	/// Used by Discover to exclude cards the current user is already
	/// pending-with or connected-with, IN EITHER DIRECTION — combines sent
	/// and received connections (same "either direction" pattern as
	/// `watchAcceptedConnections()` above), since a card must be excluded
	/// from Discover regardless of who initiated the connection. The
	/// original version keyed only on `watchSentConnections()`, which left
	/// the RECEIVER of a request still seeing the sender in their own feed —
	/// fixed here.
	Stream<Set<String>> watchMyPendingOrAcceptedConnectionUserIds() {
		return switchMap(_uidStream, (uid) {
			if (uid == null) return Stream.value(<String>{});
			return switchMap(
				_connections.where('senderId', isEqualTo: uid).snapshots(),
				(sentSnapshot) {
					return _connections
							.where('receiverId', isEqualTo: uid)
							.snapshots()
							.map((receivedSnapshot) {
								final ids = <String>{};
								for (final doc in sentSnapshot.docs) {
									final c = ConnectionModel.fromDoc(doc);
									final s = c.status.toLowerCase();
									if (s == 'pending' || s == 'accepted') {
										ids.add(c.receiverId);
									}
								}
								for (final doc in receivedSnapshot.docs) {
									final c = ConnectionModel.fromDoc(doc);
									final s = c.status.toLowerCase();
									if (s == 'pending' || s == 'accepted') {
										ids.add(c.senderId);
									}
								}
								return ids;
							});
				},
			);
		});
	}
}
