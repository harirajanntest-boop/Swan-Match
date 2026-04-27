import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/utils/stream_utils.dart';

class MatchService {
  MatchService._();

  static final MatchService instance = MatchService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _profileViews =>
      _firestore.collection('profileViews');

  /// Returns a stream of the current user's UID that de-dupes consecutive
  /// identical values, used as the outer stream for all switchMap calls.
  Stream<String?> get _uidStream =>
      _auth.authStateChanges().map((u) => u?.uid).distinct();

  Stream<List<Map<String, dynamic>>> watchRecommendedMatches({int limit = 25}) {
    return switchMap(_uidStream, (uid) {
      if (uid == null) {
        return Stream.value(<Map<String, dynamic>>[]);
      }

      return _firestore.collection('users').doc(uid).snapshots().asyncMap((
        userDoc,
      ) async {
        final myProfile = userDoc.data() ?? <String, dynamic>{};

        // Fetch ALL registered users — gender filtering is handled
        // entirely client-side in SwipePage._applyFilters so that the
        // Discover filter chips (All / Male / Female) work correctly.
        final snapshot = await _firestore
            .collection('users')
            .where('registrationCompleted', isEqualTo: true)
            .get();

        final blockedUids = List<String>.from(myProfile['blockedUids'] ?? []);
        final ignoredMap = Map<String, dynamic>.from(
          myProfile['ignoredProfiles'] ?? {},
        );
        final now = DateTime.now();

        return snapshot.docs
            .map((doc) => <String, dynamic>{...doc.data(), 'uid': doc.id})
            .where((profile) {
              final pUid = (profile['uid'] ?? '').toString();
              if (pUid == uid) return false;
              if (blockedUids.contains(pUid)) return false;

              final ignoreExpiry = ignoredMap[pUid];
              if (ignoreExpiry is Timestamp &&
                  ignoreExpiry.toDate().isAfter(now)) {
                return false;
              }
              return true;
            })
            .where(_isVisibleToEveryone)
            .take(limit)
            .toList();
      });
    });
  }

  Stream<List<Map<String, dynamic>>> watchAllMatches() {
    return switchMap(_uidStream, (uid) {
      if (uid == null) {
        return Stream.value(<Map<String, dynamic>>[]);
      }

      return _firestore.collection('users').doc(uid).snapshots().asyncMap((
        userDoc,
      ) async {
        final myProfile = userDoc.data() ?? <String, dynamic>{};

        // Get all registered users
        final snapshot = await _firestore
            .collection('users')
            .where('registrationCompleted', isEqualTo: true)
            .get();

        final blockedUids = List<String>.from(myProfile['blockedUids'] ?? []);
        final ignoredMap = Map<String, dynamic>.from(
          myProfile['ignoredProfiles'] ?? {},
        );
        final now = DateTime.now();

        return snapshot.docs
            .map((doc) => <String, dynamic>{...doc.data(), 'uid': doc.id})
            .where((profile) {
              final pUid = (profile['uid'] ?? '').toString();
              if (pUid == uid) return false;
              if (blockedUids.contains(pUid)) return false;

              final ignoreExpiry = ignoredMap[pUid];
              if (ignoreExpiry is Timestamp &&
                  ignoreExpiry.toDate().isAfter(now)) {
                return false;
              }
              return true;
            })
            .where(_isVisibleToEveryone)
            .toList();
      });
    });
  }

  Stream<List<Map<String, dynamic>>> watchNewMatches({int days = 7}) {
    return switchMap(_uidStream, (uid) {
      if (uid == null) {
        return Stream.value(<Map<String, dynamic>>[]);
      }

      final cutoff = DateTime.now().subtract(Duration(days: days));

      return _firestore.collection('users').doc(uid).snapshots().asyncMap((
        userDoc,
      ) async {
        final myProfile = userDoc.data() ?? <String, dynamic>{};
        final myPrefs = Map<String, dynamic>.from(
          myProfile['partnerPreference'] ??
              myProfile['partnerPreferences'] ??
              <String, dynamic>{},
        );

        // Get all registered users
        final snapshot = await _firestore
            .collection('users')
            .where('registrationCompleted', isEqualTo: true)
            .get();

        final blockedUids = List<String>.from(myProfile['blockedUids'] ?? []);
        final ignoredMap = Map<String, dynamic>.from(
          myProfile['ignoredProfiles'] ?? {},
        );
        final now = DateTime.now();

        final items = snapshot.docs
            .map((doc) => <String, dynamic>{...doc.data(), 'uid': doc.id})
            .where((profile) {
              final pUid = (profile['uid'] ?? '').toString();
              if (pUid == uid) return false;
              if (blockedUids.contains(pUid)) return false;

              final ignoreExpiry = ignoredMap[pUid];
              if (ignoreExpiry is Timestamp &&
                  ignoreExpiry.toDate().isAfter(now)) {
                return false;
              }
              return true;
            })
            .where(_isVisibleToEveryone)
            .where(
              (profile) => _calculateMatchScore(profile, myPrefs) < 0.5,
            ) // Less than 50% match
            .where((profile) {
              final createdAt = profile['createdAt'];
              if (createdAt == null) return true;
              if (createdAt.runtimeType.toString() == 'Timestamp') {
                try {
                  return (createdAt.toDate() as DateTime).isAfter(cutoff);
                } catch (_) {
                  return true;
                }
              }
              if (createdAt is DateTime) {
                return createdAt.isAfter(cutoff);
              }
              return true;
            })
            .toList();

        items.sort((a, b) {
          DateTime parse(dynamic raw) {
            if (raw is DateTime) return raw;
            if (raw != null && raw.runtimeType.toString() == 'Timestamp') {
              try {
                return raw.toDate() as DateTime;
              } catch (_) {
                return DateTime.fromMillisecondsSinceEpoch(0);
              }
            }
            return DateTime.fromMillisecondsSinceEpoch(0);
          }

          return parse(b['createdAt']).compareTo(parse(a['createdAt']));
        });

        return items;
      });
    });
  }

  bool _isVisibleToEveryone(Map<String, dynamic> profile) {
    return profile['showProfileToEveryone'] != false;
  }

  double _calculateMatchScore(
    Map<String, dynamic> candidate,
    Map<String, dynamic> myPrefs,
  ) {
    int matches = 0;
    int totalFields = 0;

    bool listMatch(dynamic candidateVal, dynamic prefVal) {
      if (prefVal == null) return true;
      if (prefVal is List) {
        if (prefVal.isEmpty) return true;
        return prefVal
            .map((e) => e.toString().toLowerCase())
            .contains(candidateVal?.toString().toLowerCase());
      }
      return prefVal.toString().toLowerCase() ==
          candidateVal?.toString().toLowerCase();
    }

    // 1. Age
    totalFields++;
    final dob = candidate['dateOfBirth'];
    if (dob != null) {
      int age = 0;
      if (dob is DateTime)
        age = DateTime.now().year - dob.year;
      else if (dob.runtimeType.toString() == 'Timestamp')
        age = DateTime.now().year - (dob as Timestamp).toDate().year;
      final min = int.tryParse(myPrefs['ageMin']?.toString() ?? '18') ?? 18;
      final max = int.tryParse(myPrefs['ageMax']?.toString() ?? '70') ?? 70;
      if (age >= min && age <= max) matches++;
    }

    // 2. Religion
    totalFields++;
    if (listMatch(
      candidate['religion'],
      myPrefs['religions'] ?? myPrefs['religion'],
    ))
      matches++;

    // 3. Mother Tongue
    totalFields++;
    if (listMatch(
      candidate['motherTongue'],
      myPrefs['motherTongues'] ?? myPrefs['motherTongue'],
    ))
      matches++;

    // 4. Education
    totalFields++;
    if (listMatch(
      candidate['education'],
      myPrefs['educations'] ?? myPrefs['education'],
    ))
      matches++;

    // 5. Country
    totalFields++;
    if (listMatch(
      candidate['country'],
      myPrefs['countries'] ?? myPrefs['country'],
    ))
      matches++;

    // 6. Height (In CM)
    totalFields++;
    final h = double.tryParse(candidate['height']?.toString() ?? '0') ?? 0;
    final hMin = double.tryParse(myPrefs['heightMin']?.toString() ?? '0') ?? 0;
    final hMax =
        double.tryParse(myPrefs['heightMax']?.toString() ?? '300') ?? 300;
    if (h >= hMin && h <= hMax) matches++;

    if (totalFields == 0) return 1.0;
    return matches / totalFields;
  }

  Future<void> recordProfileView({required String viewedUserId}) async {
    final user = _auth.currentUser;
    if (user == null || viewedUserId.isEmpty || viewedUserId == user.uid)
      return;

    final id = '${user.uid}_$viewedUserId';
    await _profileViews.doc(id).set(<String, dynamic>{
      'id': id,
      'fromUserId': user.uid,
      'toUserId': viewedUserId,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> watchViewedYouMatches() {
    return switchMap(_uidStream, (uid) {
      if (uid == null) {
        return Stream.value(<Map<String, dynamic>>[]);
      }

      return _firestore.collection('users').doc(uid).snapshots().asyncMap((
        userDoc,
      ) async {
        final myProfile = userDoc.data() ?? <String, dynamic>{};
        final blockedUids = List<String>.from(myProfile['blockedUids'] ?? []);
        final ignoredMap = Map<String, dynamic>.from(
          myProfile['ignoredProfiles'] ?? {},
        );
        final now = DateTime.now();

        final snapshot = await _profileViews
            .where('toUserId', isEqualTo: uid)
            .orderBy('updatedAt', descending: true)
            .get();

        final viewerIds = snapshot.docs
            .map((doc) => (doc.data()['fromUserId'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList();

        if (viewerIds.isEmpty) return <Map<String, dynamic>>[];

        final usersSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: viewerIds.take(10).toList())
            .get();

        final usersById = {
          for (final doc in usersSnapshot.docs)
            doc.id: <String, dynamic>{...doc.data(), 'uid': doc.id},
        };

        final ordered = <Map<String, dynamic>>[];
        for (final id in viewerIds) {
          final profile = usersById[id];
          if (profile != null) {
            if (blockedUids.contains(id)) continue;
            final ignoreExpiry = ignoredMap[id];
            if (ignoreExpiry is Timestamp && ignoreExpiry.toDate().isAfter(now))
              continue;

            if (_isVisibleToEveryone(profile)) {
              ordered.add(profile);
            }
          }
        }
        return ordered;
      });
    });
  }

  /// Get matches filtered by relationship goal (lookingFor field)
  Stream<List<Map<String, dynamic>>> watchMatchesByRelationshipGoal(String goalTitle) {
    return switchMap(_uidStream, (uid) {
      if (uid == null) {
        return Stream.value(<Map<String, dynamic>>[]);
      }

      return _firestore.collection('users').doc(uid).snapshots().asyncMap((
        userDoc,
      ) async {
        final myProfile = userDoc.data() ?? <String, dynamic>{};
        final partnerPreference = (myProfile['partnerPreference'] ?? '').toString().trim().toLowerCase();

        // Determine which genders to show based on partnerPreference
        List<String> genderValues = [];
        if (partnerPreference == 'female' || partnerPreference == 'women') {
          genderValues = ['Female', 'female'];
        } else if (partnerPreference == 'male' || partnerPreference == 'men') {
          genderValues = ['Male', 'male'];
        } else if (partnerPreference == 'both') {
          genderValues = ['Male', 'male', 'Female', 'female'];
        }

        // Build query with gender filter if partnerPreference is set
        Query<Map<String, dynamic>> query = _firestore
            .collection('users')
            .where('registrationCompleted', isEqualTo: true);

        if (genderValues.isNotEmpty) {
          query = query.where('gender', whereIn: genderValues);
        }

        // Get all registered users
        final snapshot = await query.get();

        final blockedUids = List<String>.from(myProfile['blockedUids'] ?? []);
        final ignoredMap = Map<String, dynamic>.from(
          myProfile['ignoredProfiles'] ?? {},
        );
        final now = DateTime.now();

        // Convert goal title to lowercase for matching
        final goalLower = goalTitle.toLowerCase();

        return snapshot.docs
            .map((doc) => <String, dynamic>{...doc.data(), 'uid': doc.id})
            .where((profile) {
              final pUid = (profile['uid'] ?? '').toString();
              if (pUid == uid) return false;
              if (blockedUids.contains(pUid)) return false;

              final ignoreExpiry = ignoredMap[pUid];
              if (ignoreExpiry is Timestamp &&
                  ignoreExpiry.toDate().isAfter(now)) {
                return false;
              }

              // Filter by relationship goal
              final lookingFor = profile['lookingFor']?.toString();
              if (lookingFor == null) return false;
              final normalized = lookingFor.toLowerCase().trim();

              bool matches = false;
              if (goalLower.contains('ready to marry') && 
                  (normalized == 'ready to marry' || normalized == 'ready to Marry')) {
                matches = true;
              } else if (goalLower.contains('something serious') && 
                  normalized == 'something serious') {
                matches = true;
              } else if (goalLower.contains('long-term') && 
                  (normalized == 'long-term partner' || normalized == 'long term partner')) {
                matches = true;
              } else if (goalLower.contains('just browsing') && 
                  normalized == 'just browsing') {
                matches = true;
              } else if (goalLower.contains('let love lead') && 
                  normalized == 'let love lead') {
                matches = true;
              }

              return matches;
            })
            .where(_isVisibleToEveryone)
            .toList();
      });
    });
  }
}
