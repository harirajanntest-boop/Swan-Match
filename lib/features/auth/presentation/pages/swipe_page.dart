import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/match_service.dart';
import '../../../../services/user_service.dart';
import '../../../../services/interest_service.dart';
import '../../../../models/interest_model.dart';
import '../../../../models/user_model.dart';
import '../../../../shared/widgets/linear_message.dart';
import '../../../../shared/helpers/deleted_user_helper.dart';
import '../../../../shared/helpers/profile_visibility_helper.dart';
import 'notifications_page.dart';
import 'match_profile_detail_page.dart';
import 'settings_page.dart';
import 'subscription_page.dart';
import 'edit_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/subscription_limits_service.dart';

class ScoredUser {
  final UserModel user;
  final int score;

  ScoredUser({required this.user, required this.score});
}

class SwipePage extends StatefulWidget {
  final void Function({Map<String, dynamic>? profile})? onOpenMatches;
  final VoidCallback? onOpenUpgrade;

  const SwipePage({super.key, this.onOpenMatches, this.onOpenUpgrade});

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<UserModel> _profiles = [];
  Set<String> likedUids = {};
  /// Prevents double-tap duplicate interest sends.
  final Set<String> _interestActionLocks = {};
  Set<String> blockedUids = {};
  bool _isLoading = false;
  UserModel? _currentUser;
  StreamSubscription<Map<String, dynamic>?>? _profileSubscription;
  StreamSubscription<Map<String, String>>? _sentInterestSub;
  StreamSubscription<Map<String, String>>? _recvInterestSub;
  Timer? _discoverReloadDebounce;
  String _lastProfileSignature = '';
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _discoverSubscription;
  bool _discoverStreamStarted = false;
  List<UserModel> _lastRawCandidates = [];

  late final Stream<Map<String, dynamic>?> _userProfileStream;
  late final Stream<Map<String, String>> _sentInterestStatusStream;
  late final Stream<Map<String, String>> _receivedInterestStatusStream;

  // Local filter states
  String _genderFilter = 'All';
  RangeValues _ageRange = const RangeValues(18, 70);
  // Selected interest tags (multi-select from onboarding options)
  List<String> _selectedInterestTags = [];
  // Selected mother tongue (single-select from onboarding language list)
  String _motherTongueFilter = '';
  DiscoverFilterAccess _filterAccess = DiscoverFilterAccess.free;

  // Interest options mirrored from onboarding_step5_personality
  static const List<Map<String, dynamic>> _kInterestOptions = [
    {'label': 'Travel', 'icon': Icons.flight},
    {'label': 'Reading', 'icon': Icons.menu_book},
    {'label': 'Music', 'icon': Icons.music_note},
    {'label': 'Cooking', 'icon': Icons.restaurant},
    {'label': 'Photography', 'icon': Icons.camera_alt},
    {'label': 'Sports', 'icon': Icons.sports_soccer},
    {'label': 'Art', 'icon': Icons.brush},
    {'label': 'Technology', 'icon': Icons.computer},
    {'label': 'Movies', 'icon': Icons.movie},
    {'label': 'Yoga & Meditation', 'icon': Icons.spa},
    {'label': 'Dancing', 'icon': Icons.nightlife},
    {'label': 'Hiking', 'icon': Icons.terrain},
    {'label': 'Gaming', 'icon': Icons.sports_esports},
    {'label': 'Volunteering', 'icon': Icons.volunteer_activism},
    {'label': 'Fashion', 'icon': Icons.checkroom},
    {'label': 'Gardening', 'icon': Icons.local_florist},
    {'label': 'Writing', 'icon': Icons.edit},
    {'label': 'Fitness', 'icon': Icons.fitness_center},
  ];

  // Language options mirrored from onboarding_step4_cultural
  static const List<String> _kLanguageOptions = [
    'English',
    'Spanish',
    'French',
    'Arabic',
    'Hindi',
    'Mandarin',
    'German',
    'Italian',
    'Tamil',
    'Telugu',
    'Turkish',
    'Urdu',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _userProfileStream = UserService.instance.watchCurrentUserProfile();
    _sentInterestStatusStream = InterestService.instance
        .watchMySentInterestStatusByUserId();
    _receivedInterestStatusStream = InterestService.instance
        .watchInterestsForMe()
        .map((items) {
          final latest = <String, InterestModel>{};
          for (final item in items) {
            final prev = latest[item.fromUserId];
            if (prev == null || item.updatedAt.isAfter(prev.updatedAt)) {
              latest[item.fromUserId] = item;
            }
          }
          return latest.map((k, v) => MapEntry(k, v.status.toLowerCase()));
        });
    _profileSubscription = _userProfileStream.listen(_handleProfileUpdate);
    _sentInterestSub = _sentInterestStatusStream.listen(
      (_) => _scheduleDiscoverReload(),
    );
    _recvInterestSub = _receivedInterestStatusStream.listen(
      (_) => _scheduleDiscoverReload(),
    );
    _loadProfiles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncDiscoverFilterLimits();
    });
  }

  Future<void> _syncDiscoverFilterLimits() async {
    final access =
        await SubscriptionLimitsService.instance.discoverFilterAccess();
    if (!mounted) return;

    final sanitized = access.sanitize(
      genderFilter: _genderFilter,
      ageRange: _ageRange,
      selectedInterestTags: _selectedInterestTags,
      motherTongueFilter: _motherTongueFilter,
    );

    final changed = _genderFilter != sanitized.genderFilter ||
        _ageRange != sanitized.ageRange ||
        !_listEquals(_selectedInterestTags, sanitized.selectedInterestTags) ||
        _motherTongueFilter != sanitized.motherTongueFilter;

    if (changed || _filterAccess.tier != access.tier) {
      setState(() {
        _filterAccess = access;
        _genderFilter = sanitized.genderFilter;
        _ageRange = sanitized.ageRange;
        _selectedInterestTags = sanitized.selectedInterestTags;
        _motherTongueFilter = sanitized.motherTongueFilter;
      });
    } else {
      _filterAccess = access;
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Refresh Discover list when interests change (e.g. after disconnect).
  void _scheduleDiscoverReload() {
    _discoverReloadDebounce?.cancel();
    _discoverReloadDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _loadExclusionLists().then((_) {
        if (mounted) _loadProfiles();
      });
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _sentInterestSub?.cancel();
    _recvInterestSub?.cancel();
    _discoverReloadDebounce?.cancel();
    _discoverSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handleProfileUpdate(Map<String, dynamic>? profile) {
    final signature = _profileSignature(profile);
    if (signature == _lastProfileSignature) return;
    _lastProfileSignature = signature;

    if (_currentUser == null) return;
    if (!mounted) return;
    _syncDiscoverFilterLimits().then((_) {
      if (mounted) _loadProfiles();
    });
  }

  String _profileSignature(Map<String, dynamic>? profile) {
    if (profile == null) return '';
    final sub = profile['subscription'];
    final subStatus = sub is Map ? (sub['status'] ?? '').toString() : '';
    final subPlan = (profile['subscriptionPlan'] ?? '').toString();
    final nestedPlan = sub is Map ? (sub['plan'] ?? '').toString() : '';
    final nestedPriceId = sub is Map ? (sub['priceId'] ?? '').toString() : '';
    return [
      subStatus,
      subPlan,
      nestedPlan,
      nestedPriceId,
      (profile['minAgePreference'] ?? '').toString(),
      (profile['maxAgePreference'] ?? '').toString(),
      (profile['preferredReligion'] ?? '').toString(),
      (profile['gender'] ?? '').toString(),
    ].join('|');
  }

  // ─── Pre-cache the next 3 profiles' photos so swipes feel instant ───
  void _precacheNext(List<Map<String, dynamic>> matches, int currentIndex) {
    // Pre-cache up to 3 upcoming profiles
    for (int offset = 1; offset <= 3; offset++) {
      final idx = currentIndex + offset;
      if (idx >= matches.length) break;
      final next = matches[idx];
      final photos = _photosOf(next);
      for (final url in photos.take(2)) {
        precacheImage(
          CachedNetworkImageProvider(url),
          context,
        );
      }
    }
  }

  List<String> _photosOf(Map<String, dynamic> m) {
    final photos = m['photos'];
    if (photos is List && photos.isNotEmpty) {
      return photos
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    // Check all known photo field names — Firestore uses 'profilePicture'
    final single =
        (m['profilePicture'] ??
                m['photoUrl'] ??
                m['profilePhoto'] ??
                m['profilePic'] ??
                '')
            .toString();
    return single.isNotEmpty ? [single] : [];
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> matches,
    Map<String, dynamic> profile,
    Map<String, dynamic> hiddenMap,
    Map<String, String> sentStatus,
    Map<String, String> receivedStatus,
  ) {
    final blocked = List<String>.from(profile['blockedUids'] ?? []);
    final now = DateTime.now().millisecondsSinceEpoch;

    final discoverFilters = _filterAccess.sanitize(
      genderFilter: _genderFilter,
      ageRange: _ageRange,
      selectedInterestTags: _selectedInterestTags,
      motherTongueFilter: _motherTongueFilter,
    );
    final genderFilter = discoverFilters.genderFilter;
    final ageRange = discoverFilters.ageRange;
    final interestTags = discoverFilters.selectedInterestTags;
    final motherTongueFilter = discoverFilters.motherTongueFilter;

    // Discover prefs from Edit Profile only — not Partner Preferences screen map.
    final ageMin = _parseInt(profile['minAgePreference']);
    final ageMax = _parseInt(profile['maxAgePreference']);
    final preferredReligion = (profile['preferredReligion'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    const noReligionPref = {'any', 'open to all', 'all', 'no preference', ''};

    // Opposite gender only (from the signed-in user's gender).
    List<String> allowedGenders = [];
    final myGenderRaw = (profile['gender'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (myGenderRaw == 'male' || myGenderRaw == 'man' || myGenderRaw == 'm') {
      allowedGenders = ['Female', 'female', 'woman', 'Woman'];
    } else if (myGenderRaw == 'female' ||
        myGenderRaw == 'woman' ||
        myGenderRaw == 'f') {
      allowedGenders = ['Male', 'male', 'man', 'Man'];
    }

    return matches.where((item) {
      final uid = (item['uid'] ?? '').toString();
      final itemGender = (item['gender'] ?? '').toString();

      // Skip profiles that are deleted, missing uid, or blocked
      if (uid.isEmpty ||
          blocked.contains(uid) ||
          DeletedUserHelper.isDeleted(item)) {
        return false;
      }

      // ─ Local Bottom Sheet Filters (tier-enforced) ─
      if (genderFilter != 'All') {
        final g = _normalizeGender(itemGender);
        final f = _normalizeGender(genderFilter);
        if (g != f) return false;
      }

      final rawDob = item['dateOfBirth'];
      int? ageLocal;
      if (rawDob is DateTime) {
        final nowDate = DateTime.now();
        ageLocal = nowDate.year - rawDob.year;
        if (nowDate.month < rawDob.month ||
            (nowDate.month == rawDob.month && nowDate.day < rawDob.day))
          ageLocal--;
      } else if (rawDob != null &&
          rawDob.runtimeType.toString() == 'Timestamp') {
        try {
          final dob = rawDob.toDate() as DateTime;
          final nowDate = DateTime.now();
          ageLocal = nowDate.year - dob.year;
          if (nowDate.month < dob.month ||
              (nowDate.month == dob.month && nowDate.day < dob.day))
            ageLocal--;
        } catch (_) {}
      }
      ageLocal ??= _parseInt(item['age'] ?? item['calculatedAge']);

      if (ageLocal != null) {
        if (ageMin != null && ageLocal < ageMin) return false;
        if (ageMax != null && ageLocal > ageMax) return false;
        if (ageLocal < ageRange.start || ageLocal > ageRange.end) return false;
      }

      if (interestTags.isNotEmpty) {
        final interestsList = item['interests'] as List<dynamic>? ?? [];
        final profileInterests = interestsList
            .map((i) => i.toString().trim().toLowerCase())
            .toSet();
        final hasAny = interestTags.any(
          (tag) => profileInterests.contains(tag.trim().toLowerCase()),
        );
        if (!hasAny) return false;
      }

      if (motherTongueFilter.isNotEmpty) {
        final mt = (item['primaryLanguage'] ?? item['motherTongue'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (mt != motherTongueFilter.trim().toLowerCase()) return false;
      }

      // ─ Gender (opposite of current user) ───────────────────────────────
      if (genderFilter == 'All' && allowedGenders.isNotEmpty) {
        final profileGenderNorm = _normalizeGender(itemGender);
        final allowedNorm = allowedGenders.map(_normalizeGender).toSet();
        if (!allowedNorm.contains(profileGenderNorm)) return false;
      }

      // ─ Religion (Edit Profile preferredReligion only) ──────────────────
      if (!noReligionPref.contains(preferredReligion)) {
        final r = (item['religion'] ?? '').toString().trim().toLowerCase();
        if (r != preferredReligion) return false;
      }

      // ─ Ignored / hidden ──────────────────────────────────────────────────
      final ignoredMatchIds =
          (profile['ignoredMatchIds'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toSet();
      if (ignoredMatchIds.contains(uid)) return false;

      final hidden = int.tryParse((hiddenMap[uid] ?? '').toString()) ?? 0;
      if (hidden > now) return false;

      // ─ Interest / like status ────────────────────────────────────────────
      final ss = sentStatus[uid]?.toLowerCase() ?? '';
      final rs = receivedStatus[uid]?.toLowerCase() ?? '';

      // After disconnect, interest is declined — show again on Discover.
      final isDisconnected =
          ss == 'declined' || rs == 'declined' || ss == 'blocked' || rs == 'blocked';

      if (!isDisconnected) {
        if (ss == 'accepted' || ss == 'replied' || ss == 'pending') {
          return false;
        }
        if (rs == 'accepted' || rs == 'replied' || rs == 'pending') {
          return false;
        }
        // Swipe "like" is stored separately from interests.
        if (likedUids.contains(uid)) return false;
      }

      return true;
    }).toList();
  }

  /// Safely parses an int from dynamic (supports int, double, String).
  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }

  /// Normalises gender strings so that 'Man'/'Male'/'m' all become 'male'
  /// and 'Woman'/'Female'/'f' all become 'female'.
  bool _interestStatusBlocksDiscover(
    String? sentStatus,
    String? receivedStatus,
  ) {
    final ss = (sentStatus ?? '').toLowerCase();
    final rs = (receivedStatus ?? '').toLowerCase();
    const blocked = {'pending', 'accepted', 'replied'};
    return blocked.contains(ss) || blocked.contains(rs);
  }

  String _normalizeGender(String raw) {
    final g = raw.trim().toLowerCase();
    if (g == 'male' || g == 'man' || g == 'm') return 'male';
    if (g == 'female' || g == 'woman' || g == 'f') return 'female';
    return g;
  }

  Future<void> _loadProfiles() async {
    if (!mounted) return;
    // Only show a loading spinner on the very first load when we have no profiles yet.
    // After that, updates happen silently so the UI stays responsive.
    if (!_discoverStreamStarted && _profiles.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      await _syncDiscoverFilterLimits();
      if (!mounted) return;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final meDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final meData = meDoc.data();
      if (meData == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _currentUser = UserModel.fromMap(<String, dynamic>{
        ...meData,
        'uid': uid,
      });

      await _loadExclusionLists();
      _startDiscoverStream();
      _refilterDiscoverFeed();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Load profiles error: $e');
    }
  }

  void _startDiscoverStream() {
    if (_discoverStreamStarted || _currentUser == null) return;
    _discoverStreamStarted = true;

    _discoverSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('registrationCompleted', isEqualTo: true)
        .limit(250)
        .snapshots()
        .listen(
      _onDiscoverSnapshot,
      onError: (e) {
        debugPrint('Discover stream error: $e');
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  void _onDiscoverSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted || _currentUser == null) return;

    final targetNorm = _getTargetGenders(_currentUser!)
        .map(_normalizeGender)
        .toSet();
    final fetched = <UserModel>[];
    final seen = <String>{};

    for (final doc in snapshot.docs) {
      if (doc.id == _currentUser!.uid) continue;
      final data = doc.data();
      if (DeletedUserHelper.isDeleted(data)) continue;

      UserModel user;
      try {
        user = UserModel.fromMap(<String, dynamic>{...data, 'uid': doc.id});
      } catch (e, st) {
        debugPrint('SwipePage: skip profile ${doc.id}: $e\n$st');
        continue;
      }
      if (!user.registrationCompleted) continue;
      if (user.isDeleted || user.status.toLowerCase() == 'deleted') continue;

      if (targetNorm.isNotEmpty) {
        final g = _normalizeGender(user.gender);
        if (!targetNorm.contains(g)) continue;
      }

      if (seen.add(user.uid)) fetched.add(user);
    }

    _lastRawCandidates = fetched;
    if (kDebugMode) {
      debugPrint('SwipePage: stream fetched=${fetched.length} candidates');
    }
    final filtered = _applyDartFilters(fetched, _currentUser!);
    final ranked = _rankUsers(filtered, _currentUser!);
    final boosted = _applySubscriptionBoost(ranked, _currentUser!);
    _mergeDiscoverProfiles(boosted);
  }

  void _refilterDiscoverFeed() {
    if (_currentUser == null || _lastRawCandidates.isEmpty) return;
    final filtered = _applyDartFilters(_lastRawCandidates, _currentUser!);
    final ranked = _rankUsers(filtered, _currentUser!);
    final boosted = _applySubscriptionBoost(ranked, _currentUser!);
    _mergeDiscoverProfiles(boosted);
  }

  /// Updates the swipe stack without resetting position when possible.
  void _mergeDiscoverProfiles(List<UserModel> incoming) {
    if (!mounted) return;

    if (incoming.isEmpty && _profiles.isEmpty) {
      setState(() {
        _profiles = [];
        _isLoading = false;
      });
      return;
    }

    final incomingByUid = {for (final p in incoming) p.uid: p};
    String? currentUid;
    if (_profiles.isNotEmpty && _currentPage < _profiles.length) {
      currentUid = _profiles[_currentPage].uid;
    }

    final kept = <UserModel>[];
    for (final p in _profiles) {
      final updated = incomingByUid[p.uid];
      if (updated != null) kept.add(updated);
    }

    final keptSet = kept.map((p) => p.uid).toSet();
    final added = incoming.where((p) => !keptSet.contains(p.uid)).toList();
    final merged = [...kept, ...added];

    var newPage = _currentPage;
    if (currentUid != null) {
      final idx = merged.indexWhere((p) => p.uid == currentUid);
      newPage = idx >= 0 ? idx : newPage.clamp(0, merged.isEmpty ? 0 : merged.length - 1);
    } else if (merged.isNotEmpty) {
      newPage = 0;
    }

    final pageChanged = newPage != _currentPage;
    setState(() {
      _profiles = merged;
      _isLoading = false;
      _currentPage = newPage;
    });

    // Eagerly pre-cache the first 3 cards as soon as we have data
    if (merged.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (int i = 0; i < merged.length && i < 3; i++) {
          final photos = _photosOf(merged[i].toMap()..['uid'] = merged[i].uid);
          for (final url in photos.take(2)) {
            precacheImage(
              CachedNetworkImageProvider(url),
              context,
            );
          }
        }
      });
    }

    if (pageChanged && _pageController.hasClients && merged.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        final safePage = newPage.clamp(0, merged.length - 1);
        _pageController.jumpToPage(safePage);
      });
    }
  }

  List<UserModel> _applyDartFilters(
    List<UserModel> users,
    UserModel currentUser,
  ) {
    if (kDebugMode) debugPrint('SwipePage: dartFilter in=${users.length}');
    int dropped = 0;
    // Guard: if maxAge is misconfigured (≤ minAge or ≤ 18), ignore age filter
    final minAge = currentUser.minAgePreference;
    final maxAge =
        currentUser.maxAgePreference <= minAge ||
            currentUser.maxAgePreference <= 18
        ? 99
        : currentUser.maxAgePreference;

    final result = users.where((user) {
      if (user.uid == currentUser.uid) {
        dropped++;
        debugPrint('  DROP self: ${user.uid}');
        return false;
      }
      if (user.uid.isEmpty) {
        dropped++;
        return false;
      }
      // Filter deleted profiles early
      if (user.isDeleted || user.status.toLowerCase() == 'deleted') {
        dropped++;
        debugPrint('  DROP deleted: ${user.uid}');
        return false;
      }
      // Hide private / non-discoverable profiles
      if (user.profileVisibility == 'Private' ||
          user.profileVisibility == 'Curated Matches Only') {
        dropped++;
        return false;
      }
      final userAge = user.age;
      if (userAge > 0 && (userAge < minAge || userAge > maxAge)) {
        dropped++;
        debugPrint(
          '  DROP age: ${user.uid} age=$userAge, range=$minAge-$maxAge',
        );
        return false;
      }

      final preferredReligion = currentUser.preferredReligion
          .trim()
          .toLowerCase();
      const _noReligionPref = {
        'any',
        'open to all',
        'all',
        'no preference',
        '',
      };
      if (!_noReligionPref.contains(preferredReligion)) {
        if (user.religion.trim().toLowerCase() != preferredReligion) {
          dropped++;
          if (kDebugMode)
            debugPrint(
              '  DROP religion: ${user.uid} religion=${user.religion}, pref=${currentUser.preferredReligion}',
            );
          return false;
        }
      }

      if (kDebugMode) debugPrint('  PASS: ${user.uid} name=${user.firstName}');
      return true;
    }).toList();
    if (kDebugMode)
      debugPrint(
        'SwipePage: dartFilter out=${result.length}, dropped=$dropped',
      );
    return result;
  }

  int _calculateScore(UserModel currentUser, UserModel otherUser) {
    var score = 0;

    final myInterests = currentUser.interests;
    final theirInterests = otherUser.interests;
    final commonInterests = myInterests
        .where((interest) => theirInterests.contains(interest))
        .length;
    score += (commonInterests * 8).clamp(0, 40).toInt();

    if (currentUser.drinking == otherUser.drinking) score += 10;
    if (currentUser.smoking == otherUser.smoking) score += 10;
    if (currentUser.workout == otherUser.workout) score += 10;

    if (currentUser.lookingFor == otherUser.lookingFor) score += 20;

    if (currentUser.city.trim().toLowerCase() ==
        otherUser.city.trim().toLowerCase()) {
      score += 10;
    }

    return score.clamp(0, 100);
  }

  List<UserModel> _rankUsers(List<UserModel> users, UserModel currentUser) {
    final scored = users
        .map(
          (user) =>
              ScoredUser(user: user, score: _calculateScore(currentUser, user)),
        )
        .toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((item) => item.user).toList();
  }

  Future<void> _loadExclusionLists() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final likesSnap = await FirebaseFirestore.instance
        .collection('likes')
        .doc(uid)
        .collection('likedUsers')
        .get();
    likedUids = likesSnap.docs.map((doc) => doc.id).toSet();
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = userDoc.data() ?? <String, dynamic>{};
    blockedUids = Set<String>.from(data['blockedUids'] ?? <String>[]);
  }

  Future<void> _onLike(String likedUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('likes')
        .doc(uid)
        .collection('likedUsers')
        .doc(likedUid)
        .set({'timestamp': FieldValue.serverTimestamp()});

    final reverseCheck = await FirebaseFirestore.instance
        .collection('likes')
        .doc(likedUid)
        .collection('likedUsers')
        .doc(uid)
        .get();

    if (reverseCheck.exists) {
      await _createMatch(uid, likedUid);
    }
  }

  Future<void> _createMatch(String uid1, String uid2) async {
    final chatId = uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';

    await FirebaseFirestore.instance.collection('matches').doc(chatId).set({
      'users': [uid1, uid2],
      'timestamp': FieldValue.serverTimestamp(),
      'chatId': chatId,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<UserModel> _applySubscriptionBoost(
    List<UserModel> ranked,
    UserModel currentUser,
  ) {
    final plan = currentUser.subscriptionPlan.toLowerCase();
    final isPremium = plan == 'trial' || plan == 'gold' || plan == 'premium';
    if (!isPremium) {
      return ranked.take(10).toList();
    }
    return ranked;
  }

  List<String> _getTargetGenders(UserModel currentUser) {
    final gender = currentUser.gender.trim().toLowerCase();
    if (gender == 'man' || gender == 'male' || gender == 'm') {
      return ['Woman'];
    }
    if (gender == 'woman' || gender == 'female' || gender == 'f') {
      return ['Man'];
    }
    return ['Man', 'Woman'];
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: const Text(
            'Discover',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              ),
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            IconButton(
              onPressed: _showAdvancedFilterSheet,
              icon: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: StreamBuilder<Map<String, dynamic>?>(
          stream: _userProfileStream,
          builder: (context, ps) {
            final profile = ps.data ?? {};
            final hiddenRaw = profile['hiddenMatches'];
            final hiddenMap = hiddenRaw is Map
                ? Map<String, dynamic>.from(hiddenRaw)
                : <String, dynamic>{};

            return StreamBuilder<Map<String, String>>(
              stream: _sentInterestStatusStream,
              builder: (context, ss) {
                final sentStatus = ss.data ?? {};
                return StreamBuilder<Map<String, String>>(
                  stream: _receivedInterestStatusStream,
                  builder: (context, rs) {
                    final recvStatus = rs.data ?? {};
                    final savedIds = ((profile['savedMatchIds'] ?? []) as List)
                        .map((e) => e.toString())
                        .where((e) => e.isNotEmpty)
                        .toSet();

                    // Show loading indicator only on fresh start with no profiles yet
                    if (_isLoading && _profiles.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.goldMedium,
                        ),
                      );
                    }

                    final rankedMaps = _profiles.map((u) {
                      final m = u.toMap();
                      m['uid'] = u
                          .uid; // toMap() doesn't include uid — add it explicitly
                      return m;
                    }).toList();
                    final matches = _applyFilters(
                      rankedMaps,
                      profile,
                      hiddenMap,
                      sentStatus,
                      recvStatus,
                    );

                    if (matches.isEmpty) return _EmptyDiscoverState();

                    return PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      physics: const PageScrollPhysics(),
                      onPageChanged: (i) async {
                        if (i > _currentPage) {
                          final swipeCheck =
                              await SubscriptionLimitsService.instance
                                  .canSwipe();
                          if (!swipeCheck.allowed) {
                            _showSwipeUpgradeSheet();
                            _pageController.jumpToPage(_currentPage);
                            return;
                          }
                          await SubscriptionLimitsService.instance
                              .recordSwipe();
                        }
                        setState(() => _currentPage = i);
                        _precacheNext(matches, i);
                        _checkEmailLinkPopup();
                      },
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final item = matches[index];
                        final uid = (item['uid'] ?? '').toString();
                        final interestLocked = _isInterestLocked(uid) ||
                            _interestStatusBlocksDiscover(
                              sentStatus[uid],
                              recvStatus[uid],
                            );
                        return _ReelCard(
                          key: ValueKey(uid),
                          match: item,
                          photos: _photosOf(item),
                          interestStatus: sentStatus[uid] ?? '',
                          interestLocked: interestLocked,
                          isSaved: savedIds.contains(uid),
                          onTap: () async {
                            if (uid.isNotEmpty) {
                              MatchService.instance.recordProfileView(
                                viewedUserId: uid,
                              );
                            }
                            final interestSent = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MatchProfileDetailPage(
                                  profile: item,
                                  popOnInterestSent: true,
                                ),
                              ),
                            );
                            if (interestSent == true && mounted) {
                              likedUids.add(uid);
                              _interestActionLocks.remove(uid);
                              _showMessage('Interest sent! 💛');
                              setState(() {});
                              _nextCard(matches);
                            }
                          },
                          onDismiss: () async {
                            if (uid.isEmpty) return;
                            final curIgnored =
                                ((profile['ignoredMatchIds'] ?? []) as List)
                                    .map((e) => e.toString())
                                    .toSet();
                            curIgnored.add(uid);
                            await UserService.instance.updateCurrentUserProfile(
                              {'ignoredMatchIds': curIgnored.toList()},
                            );
                            if (!mounted) return;
                            _showMessage('Profile ignored.');
                            _nextCard(matches);
                          },
                          onToggleSave: () async {
                            if (uid.isEmpty) return;
                            final cur =
                                ((profile['savedMatchIds'] ?? []) as List)
                                    .map((e) => e.toString())
                                    .toSet();
                            final wasSaved = cur.contains(uid);
                            if (wasSaved) {
                              cur.remove(uid);
                            } else {
                              cur.add(uid);
                            }
                            await UserService.instance.updateCurrentUserProfile(
                              {'savedMatchIds': cur.toList()},
                            );
                            if (!mounted) return;
                            _showMessage(
                              wasSaved
                                  ? 'Removed from saved.'
                                  : 'Profile saved!',
                            );
                          },
                          onLike: () => _sendInterestFromSwipe(
                            uid: uid,
                            matches: matches,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    showLinearMessage(context, message, isError: isError);
  }

  bool _isInterestLocked(String uid) {
    if (uid.isEmpty) return true;
    return likedUids.contains(uid) || _interestActionLocks.contains(uid);
  }

  Future<void> _sendInterestFromSwipe({
    required String uid,
    required List<Map<String, dynamic>> matches,
  }) async {
    if (_isInterestLocked(uid)) return;

    _interestActionLocks.add(uid);
    likedUids.add(uid);
    if (mounted) setState(() {});

    try {
      HapticFeedback.mediumImpact();
      final result =
          await InterestService.instance.sendInterest(toUserId: uid);
      if (!mounted) return;

      if (result == InterestSendResult.trialLimitReached) {
        likedUids.remove(uid);
        _showSwipeUpgradeSheet();
        return;
      }

      if (result == InterestSendResult.sent) {
        await _onLike(uid);
        if (!mounted) return;
        _showMessage('Interest sent! 💛');
      } else if (result == InterestSendResult.pending) {
        _showMessage('Interest already pending');
      } else if (result == InterestSendResult.alreadyAccepted) {
        _showMessage('Already connected! You can message now.');
      }

      _nextCard(matches);
    } catch (e) {
      likedUids.remove(uid);
      if (mounted) {
        _showMessage('Could not send interest. Please try again.', isError: true);
      }
    } finally {
      _interestActionLocks.remove(uid);
      if (mounted) setState(() {});
    }
  }

  void _nextCard(List<Map<String, dynamic>> matches) {
    if (_currentPage < matches.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _checkEmailLinkPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_email_link_popup') ?? false;

    if (hasSeen) return;

    final linkedProviders = AuthService.instance.getLinkedProviderIds();
    final hasEmailOrGoogle =
        linkedProviders.contains('password') ||
        linkedProviders.contains('google.com');

    if (hasEmailOrGoogle) {
      // Already linked, mark as seen and return
      await prefs.setBool('has_seen_email_link_popup', true);
      return;
    }

    // Show popup
    await prefs.setBool('has_seen_email_link_popup', true);
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ), // Linear, not modern rounded
          backgroundColor: const Color(0xFF141414),
          title: const Text(
            'Account Security',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Secure your account by linking an Email or Google account. This ensures you never lose access to your matches.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Later',
                style: TextStyle(color: Colors.white38),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldMedium,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ), // Linear look
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsPage(scrollToSecurity: true),
                  ),
                );
              },
              child: const Text(
                'Go to Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSwipeUpgradeSheet() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4A017), Color(0xFFC8960C)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldMedium.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.black,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Daily Limit Reached',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You\'ve used your 3 free daily connections.\n'
              'Upgrade to Premium for unlimited interests.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldMedium,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Upgrade to Premium',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe later',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterUpgradeSheet(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.tune_rounded,
              color: AppColors.goldMedium,
              size: 44,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldMedium,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Upgrade to Premium',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterLockBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.goldMedium.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldMedium.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.goldMedium, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedFilterSection({required Widget child}) {
    return Opacity(
      opacity: 0.45,
      child: IgnorePointer(
        child: Stack(
          children: [
            child,
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, color: AppColors.goldMedium, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: TextStyle(
                        color: AppColors.goldMedium,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdvancedFilterSheet() async {
    final access =
        await SubscriptionLimitsService.instance.discoverFilterAccess();
    if (!mounted) return;

    final openCheck =
        await SubscriptionLimitsService.instance.canOpenDiscoverFilters();
    if (!openCheck.allowed) {
      _showFilterUpgradeSheet(
        context,
        title: 'Discover Filters',
        message: openCheck.reason ?? access.filterUpgradeMessage,
      );
      return;
    }

    _filterAccess = access;
    final initial = access.sanitize(
      genderFilter: _genderFilter,
      ageRange: _ageRange,
      selectedInterestTags: _selectedInterestTags,
      motherTongueFilter: _motherTongueFilter,
    );

    RangeValues tempAge = initial.ageRange;
    String tempGender = initial.genderFilter;
    List<String> tempInterests = List.from(initial.selectedInterestTags);
    String tempMotherTongue = initial.motherTongueFilter;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.goldMedium,
                  secondary: AppColors.goldMedium,
                ),
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.88,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                builder: (_, scrollCtrl) {
                  return Column(
                    children: [
                      // ── drag handle ──
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // ── header ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Discover Filters',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: Colors.white10, height: 1),
                      // ── scrollable body ──
                      Expanded(
                        child: ListView(
                          controller: scrollCtrl,
                          padding: EdgeInsets.fromLTRB(
                            20,
                            16,
                            20,
                            MediaQuery.of(context).viewInsets.bottom + 20,
                          ),
                          children: [
                            if (access.tier == UserTier.trial)
                              _filterLockBanner(
                                'Trial includes Gender and Age filters only. '
                                'Upgrade for Interests and Mother Tongue.',
                              ),
                            // ──────────────────── SHOW (Gender) ────────────────────
                            const Text(
                              'SHOW',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ['All', 'Male', 'Female'].map((g) {
                                final sel = tempGender == g;
                                return GestureDetector(
                                  onTap: () =>
                                      setModalState(() => tempGender = g),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? AppColors.goldMedium
                                          : Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: sel
                                            ? AppColors.goldMedium
                                            : Colors.white.withOpacity(0.14),
                                      ),
                                    ),
                                    child: Text(
                                      g,
                                      style: TextStyle(
                                        color: sel
                                            ? Colors.black
                                            : Colors.white70,
                                        fontWeight: sel
                                            ? FontWeight.bold
                                            : FontWeight.w400,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),

                            // ──────────────────── AGE RANGE ────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'AGE RANGE',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  '${tempAge.start.round()} – ${tempAge.end.round()}',
                                  style: const TextStyle(
                                    color: AppColors.goldMedium,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            RangeSlider(
                              activeColor: AppColors.goldMedium,
                              inactiveColor: AppColors.goldMedium.withOpacity(
                                0.2,
                              ),
                              values: tempAge,
                              min: 18,
                              max: 70,
                              divisions: 52,
                              labels: RangeLabels(
                                '${tempAge.start.round()}',
                                '${tempAge.end.round()}',
                              ),
                              onChanged: (v) =>
                                  setModalState(() => tempAge = v),
                            ),
                            const SizedBox(height: 24),

                            // ──────────────────── INTERESTS ────────────────────
                            access.allowInterests
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'INTERESTS',
                                              style: TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ),
                                          if (tempInterests.isNotEmpty)
                                            Text(
                                              '${tempInterests.length} selected',
                                              style: const TextStyle(
                                                color: AppColors.goldMedium,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children:
                                            _kInterestOptions.map((opt) {
                                          final label = opt['label'] as String;
                                          final icon = opt['icon'] as IconData;
                                          final sel =
                                              tempInterests.contains(label);
                                          return GestureDetector(
                                            onTap: () => setModalState(() {
                                              if (sel) {
                                                tempInterests.remove(label);
                                              } else {
                                                tempInterests.add(label);
                                              }
                                            }),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 7,
                                              ),
                                              decoration: BoxDecoration(
                                                color: sel
                                                    ? AppColors.goldMedium
                                                        .withOpacity(0.18)
                                                    : Colors.white
                                                        .withOpacity(0.05),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: sel
                                                      ? AppColors.goldMedium
                                                      : Colors.white
                                                          .withOpacity(0.12),
                                                  width: sel ? 1.5 : 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    icon,
                                                    size: 14,
                                                    color: sel
                                                        ? AppColors.goldMedium
                                                        : Colors.white38,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    label,
                                                    style: TextStyle(
                                                      color: sel
                                                          ? AppColors.goldMedium
                                                          : Colors.white54,
                                                      fontSize: 13,
                                                      fontWeight: sel
                                                          ? FontWeight.w600
                                                          : FontWeight.w400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  )
                                : _buildLockedFilterSection(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'INTERESTS',
                                          style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: _kInterestOptions
                                              .take(6)
                                              .map((opt) {
                                            final label =
                                                opt['label'] as String;
                                            return Chip(
                                              label: Text(label),
                                              backgroundColor:
                                                  Colors.white10,
                                            );
                                          })
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                            const SizedBox(height: 24),

                            // ──────────────────── MOTHER TONGUE ────────────────────
                            access.allowMotherTongue
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'MOTHER TONGUE',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children:
                                            _kLanguageOptions.map((lang) {
                                          final sel = tempMotherTongue == lang;
                                          return GestureDetector(
                                            onTap: () => setModalState(() {
                                              tempMotherTongue =
                                                  sel ? '' : lang;
                                            }),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: sel
                                                    ? AppColors.goldMedium
                                                    : Colors.white
                                                        .withOpacity(0.06),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: sel
                                                      ? AppColors.goldMedium
                                                      : Colors.white
                                                          .withOpacity(0.14),
                                                ),
                                              ),
                                              child: Text(
                                                lang,
                                                style: TextStyle(
                                                  color: sel
                                                      ? Colors.black
                                                      : Colors.white60,
                                                  fontWeight: sel
                                                      ? FontWeight.bold
                                                      : FontWeight.w400,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  )
                                : _buildLockedFilterSection(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'MOTHER TONGUE',
                                          style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: _kLanguageOptions
                                              .take(6)
                                              .map(
                                                (lang) => Chip(
                                                  label: Text(lang),
                                                  backgroundColor:
                                                      Colors.white10,
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                            const SizedBox(height: 32),

                            // ──────────────────── ACTION BUTTONS ────────────────────
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: AppColors.goldMedium.withOpacity(
                                          0.6,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    onPressed: () {
                                      final reset = access.sanitize(
                                        genderFilter: 'All',
                                        ageRange: const RangeValues(18, 70),
                                        selectedInterestTags: const [],
                                        motherTongueFilter: '',
                                      );
                                      setState(() {
                                        _ageRange = reset.ageRange;
                                        _selectedInterestTags =
                                            reset.selectedInterestTags;
                                        _motherTongueFilter =
                                            reset.motherTongueFilter;
                                        _genderFilter = reset.genderFilter;
                                      });
                                      Navigator.pop(ctx);
                                      _loadProfiles();
                                    },
                                    child: const Text(
                                      'Reset',
                                      style: TextStyle(
                                        color: AppColors.goldMedium,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.goldMedium,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    onPressed: () {
                                      final applied = access.sanitize(
                                        genderFilter: tempGender,
                                        ageRange: tempAge,
                                        selectedInterestTags: tempInterests,
                                        motherTongueFilter: tempMotherTongue,
                                      );
                                      setState(() {
                                        _ageRange = applied.ageRange;
                                        _selectedInterestTags =
                                            applied.selectedInterestTags;
                                        _motherTongueFilter =
                                            applied.motherTongueFilter;
                                        _genderFilter = applied.genderFilter;
                                      });
                                      Navigator.pop(ctx);
                                      _loadProfiles();
                                    },
                                    child: const Text(
                                      'Apply',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── FULL-SCREEN REEL CARD (with horizontal photo PageView) ──────────────────
// ═══════════════════════════════════════════════════════════════════════════════
class _ReelCard extends StatefulWidget {
  final Map<String, dynamic> match;
  final List<String> photos;
  final String interestStatus;
  final bool interestLocked;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final VoidCallback onToggleSave;
  final Future<void> Function() onLike;

  const _ReelCard({
    super.key,
    required this.match,
    required this.photos,
    required this.interestStatus,
    this.interestLocked = false,
    required this.isSaved,
    required this.onTap,
    required this.onDismiss,
    required this.onToggleSave,
    required this.onLike,
  });

  @override
  State<_ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<_ReelCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  final PageController _photoController = PageController();
  int _photoIndex = 0;
  bool _sendingInterest = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _heartScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 50),
        ]).animate(
          CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _heartController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  int? _age() {
    final dob = widget.match['dateOfBirth'];
    if (dob == null) return null;
    try {
      final d = (dob as dynamic).toDate() as DateTime;
      final now = DateTime.now();
      int a = now.year - d.year;
      if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
      return a;
    } catch (_) {
      return null;
    }
  }

  bool _isVerifiedMatch() {
    final p = widget.match;
    return p['isVerified'] == true ||
        p['idVerified'] == true ||
        p['profileVerified'] == true ||
        (p['verificationStatus']?.toString().toLowerCase() == 'approved');
  }

  List<String> _traits() {
    final tags =
        widget.match['lifestyleTags'] ??
        widget.match['personalityTraits'] ??
        widget.match['interests'];
    if (tags is List && tags.isNotEmpty) {
      return tags.take(3).map((e) => e.toString()).toList();
    }
    final out = <String>[];
    final r = (widget.match['religion'] ?? '').toString().trim();
    if (r.isNotEmpty) out.add(r);
    final p = (widget.match['profession'] ?? widget.match['occupation'] ?? '')
        .toString()
        .trim();
    if (p.isNotEmpty && out.length < 3) out.add(p);
    return out;
  }

  // Effective pages: real photos + upgrade prompt if photos > 0
  int get _totalPages => widget.photos.isEmpty ? 1 : widget.photos.length + 1;

  bool get _isUpgradePage =>
      widget.photos.isNotEmpty && _photoIndex == widget.photos.length;

  @override
  Widget build(BuildContext context) {
    final name = (widget.match['name'] ?? 'Unknown').toString();
    final age = _age();
    final city = (widget.match['city'] ?? '').toString().trim();
    final country = (widget.match['country'] ?? '').toString().trim();
    final location = [city, country].where((s) => s.isNotEmpty).join(', ');
    final bio = (widget.match['bio'] ?? widget.match['shortBio'] ?? '')
        .toString()
        .trim();
    final traits = _traits();
    final isVerified = _isVerifiedMatch();
    final status = widget.interestStatus.toLowerCase();
    final hasLiked = widget.interestLocked ||
        _sendingInterest ||
        ['pending', 'sent', 'accepted', 'replied'].contains(status);

    final hidePhotos = widget.match['showPhotosToEveryone'] == false;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ─── Horizontal photo PageView ───
        PageView.builder(
          controller: _photoController,
          scrollDirection: Axis.horizontal,
          physics: hidePhotos
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          onPageChanged: (i) => setState(() => _photoIndex = i),
          itemCount: hidePhotos ? 1 : _totalPages,
          itemBuilder: (ctx, i) {
            if (hidePhotos) {
              return GestureDetector(
                onTap: widget.onTap,
                child: ProfileVisibilityHelper.hiddenPhotoPlaceholder(
                  iconSize: 100,
                ),
              );
            }
            // Last page = upgrade prompt
            if (widget.photos.isNotEmpty && i == widget.photos.length) {
              return _UpgradePhotoPage();
            }
            // Photo page
            final url = widget.photos.isNotEmpty ? widget.photos[i] : '';
            return GestureDetector(
              onTap: widget.onTap,
              child: url.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      // Very fast fade so the transition feels polished
                      fadeInDuration: const Duration(milliseconds: 150),
                      fadeOutDuration: const Duration(milliseconds: 50),
                      // Shimmer-style placeholder — no spinner, no blank white
                      placeholder: (_, __) => _ShimmerPlaceholder(),
                      errorWidget: (_, __, ___) => _noPhoto(),
                    )
                  : _noPhoto(),
            );
          },
        ),

        // ─── Gradient overlays ───
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.72),
                  Colors.black.withOpacity(0.95),
                ],
                stops: const [0.0, 0.15, 0.45, 0.62, 0.78, 1.0],
              ),
            ),
          ),
        ),

        // ─── Photo dot indicators (top) ───
        if (_totalPages > 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (i) {
                final isUpgrade =
                    widget.photos.isNotEmpty && i == widget.photos.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _photoIndex == i ? 20 : 6,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _photoIndex == i
                        ? (isUpgrade ? AppColors.goldMedium : Colors.white)
                        : Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),

        // ─── Bottom info (hidden on upgrade page) ───
        if (!_isUpgradePage)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            age != null ? '$name, $age' : name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(blurRadius: 8, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.verified,
                            color: AppColors.goldMedium,
                            size: 22,
                          ),
                        ],
                      ],
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 15,
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black45),
                          ],
                        ),
                      ),
                    ],
                    if (traits.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: traits
                            .map((t) => _TraitChip(label: t))
                            .toList(),
                      ),
                    ],
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        bio.length > 100 ? '${bio.substring(0, 100)}… ›' : bio,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 14,
                          height: 1.45,
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black45),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 22),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ActionBtn(
                          icon: Icons.close_rounded,
                          iconColor: const Color(0xFFE74C3C),
                          bgColor: Colors.white.withOpacity(0.12),
                          size: 58,
                          iconSize: 26,
                          onTap: widget.onDismiss,
                        ),
                        _ActionBtn(
                          icon: widget.isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          iconColor: widget.isSaved
                              ? AppColors.goldMedium
                              : Colors.white.withOpacity(0.85),
                          bgColor: Colors.white.withOpacity(0.12),
                          size: 58,
                          iconSize: 24,
                          onTap: widget.onToggleSave,
                        ),
                        ScaleTransition(
                          scale: _heartScale,
                          child: _ActionBtn(
                            icon: hasLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            iconColor: Colors.white,
                            bgColor: AppColors.goldMedium,
                            size: 58,
                            iconSize: 26,
                            glowing: true,
                            onTap: () async {
                              if (hasLiked) return;
                              setState(() => _sendingInterest = true);
                              _heartController.forward(from: 0);
                              try {
                                await widget.onLike();
                              } finally {
                                if (mounted) {
                                  setState(() => _sendingInterest = false);
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ─── Scroll-down hint ───
        Positioned(
          bottom: 6,
          left: 0,
          right: 0,
          child: Center(
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(0.25),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _noPhoto() => Container(
    color: const Color(0xFF111111),
    child: const Icon(Icons.person, color: Colors.white12, size: 100),
  );
}

// ─── Upgrade prompt (last horizontal page) ───
class _UpgradePhotoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D0D),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.goldMedium.withOpacity(0.1),
                  border: Border.all(
                    color: AppColors.goldMedium.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppColors.goldMedium,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Want to see more?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add more photos of yourself to unlock\nexclusive profile views.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () {
                  // Navigate to Edit Profile so the user can upload photos
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC8960C), AppColors.goldMedium],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldMedium.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Add My Photos',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Trait chip ───
class _TraitChip extends StatelessWidget {
  final String label;
  const _TraitChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.25)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

// ─── Action button ───
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final double size, iconSize;
  final bool glowing;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.size,
    required this.iconSize,
    required this.onTap,
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: glowing
            ? [
                BoxShadow(
                  color: AppColors.goldMedium.withOpacity(0.4),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    ),
  );
}

// ─── Shimmer placeholder — shown while an image is loading — no spinner — ───
class _ShimmerPlaceholder extends StatefulWidget {
  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1A1A),
              Color.lerp(
                const Color(0xFF1A1A1A),
                const Color(0xFF2E2E2E),
                _anim.value,
              )!,
              const Color(0xFF1A1A1A),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ───
class _EmptyDiscoverState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.favorite_outline_rounded,
          color: AppColors.goldMedium.withOpacity(0.35),
          size: 72,
        ),
        const SizedBox(height: 24),
        const Text(
          'No profiles right now',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Check back soon for new matches',
          style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14),
        ),
      ],
    ),
  );
}
