import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/navigation/app_route_observer.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/match_service.dart';
import '../../../../services/user_service.dart';
import '../../../../services/connection_service.dart';
import '../../../../models/user_model.dart';
import '../../../../shared/widgets/linear_message.dart';
import '../../../../shared/helpers/deleted_user_helper.dart';
import '../../../../shared/helpers/profile_visibility_helper.dart';
import '../../../../shared/helpers/dealbreaker_matcher.dart';
import 'notifications_page.dart';
import 'match_profile_detail_page.dart';
import 'connect_record_page.dart';
import 'settings_page.dart';
import 'subscription_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/subscription_limits_service.dart';

// Both the main per-card video init and the next-card preload wrap
// `VideoPlayerController.initialize()` in this timeout. Without it, a
// slow/dropped network connection can leave `initialize()` hanging
// indefinitely, leaving the card stuck on its thumbnail forever with no
// error state and no way to recover.
const Duration _kVideoInitTimeout = Duration(seconds: 18);

class ScoredUser {
  final UserModel user;
  final int score;

  ScoredUser({required this.user, required this.score});
}

class SwipePage extends StatefulWidget {
  final void Function({Map<String, dynamic>? profile})? onOpenMatches;
  final VoidCallback? onOpenUpgrade;
  // Whether Discover is the currently-selected bottom-nav tab. `main_dashboard`
  // keeps all tabs alive in an `IndexedStack` (to preserve scroll/feed state
  // across tab switches), which means this page and its video keep running
  // even while hidden behind another tab unless told otherwise — this flag
  // is how the active `_ReelCard`'s video gets paused/muted-out the moment
  // the user leaves the Discover tab, not just when scrolled off within it.
  final bool isTabActive;

  const SwipePage({
    super.key,
    this.onOpenMatches,
    this.onOpenUpgrade,
    this.isTabActive = true,
  });

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage> with RouteAware {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<UserModel> _profiles = [];
  // Per-session shuffle seed: keeps the Discover order stable while the user
  // browses, but re-shuffles on each fresh load/refresh so they don't see the
  // same fixed order every time.
  int _discoverSeed = DateTime.now().microsecondsSinceEpoch;
  Set<String> blockedUids = {};
  // Users the current user has already sent a Connect request to (pending
  // or accepted) — used to remove them from the Discover feed entirely (the
  // old swipe-based app's behavior). Mirrors the old `likedUids`/interest-
  // lock pattern but sourced from ConnectionService instead of InterestService.
  Set<String> _connectedOrPendingUserIds = {};
  bool _isLoading = false;
  // True while this page has been covered by a pushed route (e.g. the user
  // tapped a card and `MatchProfileDetailPage` is now on top) — this page
  // stays mounted underneath (`Navigator.push` doesn't dispose it), so
  // without this the active card's video/audio would silently keep playing
  // behind the new screen. Combined into `isActive` below to pause it.
  bool _routeCovered = false;
  UserModel? _currentUser;
  StreamSubscription<Map<String, dynamic>?>? _profileSubscription;
  StreamSubscription<Set<String>>? _connectionsSub;
  Timer? _discoverReloadDebounce;
  String _lastProfileSignature = '';
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _discoverSubscription;
  bool _discoverStreamStarted = false;
  List<UserModel> _lastRawCandidates = [];

  // ── Next-card video preloading ───────────────────────────────────────────
  // Buffers the intro video for the card just past the current one so it's
  // ready to play the instant the user scrolls there, instead of starting
  // from zero. Only ever holds at most one preloaded controller at a time.
  VideoPlayerController? _preloadController;
  Future<void>? _preloadInitFuture;
  String? _preloadUid;

  late final Stream<Map<String, dynamic>?> _userProfileStream;
  late final Stream<Set<String>> _connectionUserIdsStream;

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

  // ── Discover debug log (debug builds only) ───────────────────────────────
  // Writes every PASS/BLOCK decision from the Discover filter pipeline to a
  // file so it can be reviewed after the run, instead of scrolling terminal
  // output. No-op (and stripped by kDebugMode) in release builds.
  File? _discoverDebugLogFile;

  Future<void> _initDiscoverDebugLog() async {
    if (!kDebugMode) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/discover_debug.log');
      // Overwrite at the start of each run so the file only reflects the
      // current session, not every run since the app was installed.
      await file.writeAsString(
        '=== Discover debug log started ${DateTime.now()} ===\n',
      );
      _discoverDebugLogFile = file;
      debugPrint('SwipePage: discover debug log -> ${file.path}');
    } catch (e) {
      debugPrint('SwipePage: could not open discover debug log: $e');
    }
  }

  void _logDiscover(String status, String uid, String reason,
      [String extra = '']) {
    if (!kDebugMode) return;
    final line = 'SwipePage: $status $uid reason=$reason $extra';
    debugPrint(line);
    try {
      _discoverDebugLogFile?.writeAsStringSync(
        '${DateTime.now().toIso8601String()} $line\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // Best-effort only — never let logging break the Discover feed.
    }
  }

  @override
  void initState() {
    super.initState();
    _initDiscoverDebugLog();
    _userProfileStream = UserService.instance.watchCurrentUserProfile();
    _connectionUserIdsStream =
        ConnectionService.instance.watchMyPendingOrAcceptedConnectionUserIds();
    _profileSubscription = _userProfileStream.listen(_handleProfileUpdate);
    _connectionsSub = _connectionUserIdsStream.listen((ids) {
      if (!mounted) return;
      setState(() => _connectedOrPendingUserIds = ids);
      // Keep exclusion lists (e.g. blockedUids) fresh when connection state
      // changes, mirroring the old interest-stream-triggered reload.
      _scheduleDiscoverReload();
    });
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _profileSubscription?.cancel();
    _connectionsSub?.cancel();
    _discoverReloadDebounce?.cancel();
    _discoverSubscription?.cancel();
    _pageController.dispose();
    _clearPreload();
    super.dispose();
  }

  // ─── RouteAware: pause the active card's video while covered ────────────
  @override
  void didPushNext() {
    if (mounted) setState(() => _routeCovered = true);
  }

  @override
  void didPopNext() {
    if (mounted) setState(() => _routeCovered = false);
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

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> matches,
    Map<String, dynamic> profile,
    Map<String, dynamic> hiddenMap, {
    bool includeSkipped = false,
  }) {
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
    const noReligionPref = {
      'any',
      'open to all',
      'all',
      'no preference',
      'same as mine',
      '',
    };

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

    final blockReasons = <String, int>{};
    void logBlock(String uid, String reason, [String extra = '']) {
      blockReasons[reason] = (blockReasons[reason] ?? 0) + 1;
      _logDiscover('FILTER-BLOCK', uid, reason, extra);
    }

    final result = matches.where((item) {
      final uid = (item['uid'] ?? '').toString();
      final itemGender = (item['gender'] ?? '').toString();

      // Skip profiles that are deleted, missing uid, or blocked
      if (uid.isEmpty) {
        return false;
      }
      if (blocked.contains(uid)) {
        logBlock(uid, 'in_blocked_list');
        return false;
      }
      if (DeletedUserHelper.isDeleted(item)) {
        logBlock(uid, 'deleted');
        return false;
      }
      // Users the current user has already connected with (pending request
      // sent, OR accepted) are removed from Discover entirely — matching the
      // original swipe-based app's behavior of hiding matched users from the
      // discovery feed, instead of merely relabeling the Connect button.
      if (_connectedOrPendingUserIds.contains(uid)) {
        logBlock(uid, 'already_connected');
        return false;
      }

      // ─ Local Bottom Sheet Filters (tier-enforced) ─
      if (genderFilter != 'All') {
        final g = _normalizeGender(itemGender);
        final f = _normalizeGender(genderFilter);
        if (g != f) {
          logBlock(uid, 'bottom_sheet_gender_filter', 'their=$g wanted=$f');
          return false;
        }
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
        if (ageMin != null && ageLocal < ageMin) {
          logBlock(uid, 'age_below_my_min', 'their_age=$ageLocal min=$ageMin');
          return false;
        }
        if (ageMax != null && ageLocal > ageMax) {
          logBlock(uid, 'age_above_my_max', 'their_age=$ageLocal max=$ageMax');
          return false;
        }
        if (ageLocal < ageRange.start || ageLocal > ageRange.end) {
          logBlock(uid, 'age_outside_bottom_sheet_range',
              'their_age=$ageLocal range=${ageRange.start}-${ageRange.end}');
          return false;
        }
      }

      if (interestTags.isNotEmpty) {
        final interestsList = item['interests'] as List<dynamic>? ?? [];
        final profileInterests = interestsList
            .map((i) => i.toString().trim().toLowerCase())
            .toSet();
        final hasAny = interestTags.any(
          (tag) => profileInterests.contains(tag.trim().toLowerCase()),
        );
        if (!hasAny) {
          logBlock(uid, 'no_matching_interest_tags');
          return false;
        }
      }

      if (motherTongueFilter.isNotEmpty) {
        final mt = (item['primaryLanguage'] ?? item['motherTongue'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (mt != motherTongueFilter.trim().toLowerCase()) {
          logBlock(uid, 'mother_tongue_mismatch',
              'their=$mt wanted=$motherTongueFilter');
          return false;
        }
      }

      // ─ Gender (opposite of current user) ───────────────────────────────
      if (genderFilter == 'All' && allowedGenders.isNotEmpty) {
        final profileGenderNorm = _normalizeGender(itemGender);
        final allowedNorm = allowedGenders.map(_normalizeGender).toSet();
        if (!allowedNorm.contains(profileGenderNorm)) {
          logBlock(uid, 'opposite_gender_only',
              'their=$profileGenderNorm allowed=$allowedNorm');
          return false;
        }
      }

      // ─ Religion (Edit Profile preferredReligion only) ──────────────────
      if (!noReligionPref.contains(preferredReligion)) {
        final r = (item['religion'] ?? '').toString().trim().toLowerCase();
        if (r != preferredReligion) {
          logBlock(uid, 'religion_mismatch',
              'their=$r wanted=$preferredReligion');
          return false;
        }
      }

      // ─ Cooldown ──────────────────────────────────────────────────────────
      // Passed profiles are hidden only until their cooldown expires (see the
      // ✕ handler), so the pool never permanently dries up. The legacy
      // permanent `ignoredMatchIds` list is intentionally no longer used to
      // hide profiles from Discover.
      // When includeSkipped is true (the "Review skipped" flow) we deliberately
      // bypass the cooldown so the profiles the user passed can resurface.
      final hidden = int.tryParse((hiddenMap[uid] ?? '').toString()) ?? 0;
      if (!includeSkipped && hidden > now) {
        logBlock(uid, 'cooldown_after_pass',
            'hiddenUntil=$hidden now=$now');
        return false;
      }

      _logDiscover('PASS', uid, 'ok', 'name=${item['firstName'] ?? ''}');
      return true;
    }).toList();

    if (kDebugMode) {
      _logDiscover('SUMMARY', 'filter-stage',
          'in=${matches.length} out=${result.length}', 'blocked=$blockReasons');
    }
    return result;
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
  String _normalizeGender(String raw) {
    final g = raw.trim().toLowerCase();
    if (g == 'male' || g == 'man' || g == 'm') return 'male';
    if (g == 'female' || g == 'woman' || g == 'f') return 'female';
    return g;
  }

  Future<void> _loadProfiles() async {
    if (!mounted) return;
    // New shuffle order for this load (so "every time they come" the order
    // varies). Stream re-emits reuse this seed, so cards don't jump mid-browse.
    _discoverSeed = DateTime.now().microsecondsSinceEpoch;
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
    final blockReasons = <String, int>{};
    void blocked(String uid, String reason, [String extra = '']) {
      blockReasons[reason] = (blockReasons[reason] ?? 0) + 1;
      _logDiscover('BLOCK', uid, reason, extra);
    }

    for (final doc in snapshot.docs) {
      if (doc.id == _currentUser!.uid) continue;
      final data = doc.data();
      if (DeletedUserHelper.isDeleted(data)) {
        blocked(doc.id, 'deleted_flag');
        continue;
      }

      UserModel user;
      try {
        user = UserModel.fromMap(<String, dynamic>{...data, 'uid': doc.id});
      } catch (e, st) {
        blocked(doc.id, 'parse_error', '$e');
        debugPrint('SwipePage: skip profile ${doc.id}: $e\n$st');
        continue;
      }
      if (!user.registrationCompleted) {
        blocked(doc.id, 'registration_incomplete');
        continue;
      }
      if (user.isDeleted || user.status.toLowerCase() == 'deleted') {
        blocked(doc.id, 'deleted_status', 'status=${user.status}');
        continue;
      }

      // Admin profile approval + approved intro video required for Discover.
      if (!ProfileVisibilityHelper.isDiscoverVisible(data)) {
        blocked(doc.id, 'not_admin_verified',
            'profileApprovalStatus=${user.profileApprovalStatus} introVideoStatus=${user.introVideoStatus}');
        continue;
      }

      if (targetNorm.isNotEmpty) {
        final g = _normalizeGender(user.gender);
        if (!targetNorm.contains(g)) {
          blocked(doc.id, 'gender_mismatch',
              'their_gender=$g wanted=$targetNorm');
          continue;
        }
      }

      if (seen.add(user.uid)) {
        fetched.add(user);
        _logDiscover('PASS', user.uid, 'ok', 'name=${user.firstName}');
      }
    }

    _lastRawCandidates = fetched;
    if (kDebugMode) {
      _logDiscover('SUMMARY', 'stream-stage', 'fetched=${fetched.length}',
          'blocked=$blockReasons');
    }
    final filtered = _applyDartFilters(fetched, _currentUser!);
    final ranked = _rankUsers(filtered, _currentUser!);
    final ordered = _orderDiscover(ranked);
    final boosted = _applySubscriptionBoost(ordered, _currentUser!);
    _mergeDiscoverProfiles(boosted);
  }

  void _refilterDiscoverFeed() {
    if (_currentUser == null || _lastRawCandidates.isEmpty) return;
    final filtered = _applyDartFilters(_lastRawCandidates, _currentUser!);
    final ranked = _rankUsers(filtered, _currentUser!);
    final ordered = _orderDiscover(ranked);
    final boosted = _applySubscriptionBoost(ordered, _currentUser!);
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
    // Surface newly-arrived profiles right AFTER the current card (top of the
    // remaining stack) instead of dumping them at the tail where users never
    // reach. On the first load `kept` is empty, so this is just the ordered list.
    final insertAt = kept.isEmpty
        ? 0
        : (_currentPage + 1).clamp(0, kept.length);
    final merged = [
      ...kept.sublist(0, insertAt),
      ...added,
      ...kept.sublist(insertAt),
    ];

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
    if (kDebugMode) _logDiscover('SUMMARY', 'dart-stage', 'in=${users.length}');
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
        _logDiscover('DROP', user.uid, 'self');
        return false;
      }
      if (user.uid.isEmpty) {
        dropped++;
        return false;
      }
      // Filter deleted profiles early
      if (user.isDeleted || user.status.toLowerCase() == 'deleted') {
        dropped++;
        _logDiscover('DROP', user.uid, 'deleted', 'status=${user.status}');
        return false;
      }
      // Hide private / non-discoverable profiles
      if (user.profileVisibility == 'Private' ||
          user.profileVisibility == 'Curated Matches Only') {
        dropped++;
        _logDiscover('DROP', user.uid, 'profile_visibility',
            'visibility=${user.profileVisibility}');
        return false;
      }
      final userAge = user.age;
      if (userAge > 0 && (userAge < minAge || userAge > maxAge)) {
        dropped++;
        _logDiscover(
          'DROP',
          user.uid,
          'age_out_of_range',
          'age=$userAge, range=$minAge-$maxAge',
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
          _logDiscover(
            'DROP',
            user.uid,
            'religion_mismatch',
            'religion=${user.religion}, pref=${currentUser.preferredReligion}',
          );
          return false;
        }
      }

      // Hard dealbreaker constraints (marriage non-negotiables)
      if (currentUser.dealbreakers.isNotEmpty) {
        final ok = DealbreakerMatcher.satisfies(
          myDealbreakers: currentUser.dealbreakers,
          candidate: user.toMap(),
          myProfile: currentUser.toMap(),
        );
        if (!ok) {
          dropped++;
          _logDiscover('DROP', user.uid, 'dealbreaker_mismatch');
          return false;
        }
      }

      // Pause / break — never show in Discover
      final intent = (user.toMap()['intentStatus'] ?? '').toString();
      if (intent == 'taking_break' || intent == 'pause_matching') {
        dropped++;
        _logDiscover('DROP', user.uid, 'intent_paused', intent);
        return false;
      }

      _logDiscover('PASS', user.uid, 'ok', 'name=${user.firstName}');
      return true;
    }).toList();
    if (kDebugMode) {
      _logDiscover(
        'SUMMARY',
        'dart-stage',
        'out=${result.length}',
        'dropped=$dropped',
      );
    }
    return result;
  }

  /// Weighted compatibility score (0–100) between the signed-in user (`me`)
  /// and `other`. Weights total 100 and reflect what matters for serious
  /// relationships. Used by [_rankUsers] to sort the Discover feed best-first.
  int _calculateScore(UserModel me, UserModel other) {
    String norm(String s) => s.trim().toLowerCase();
    double score = 0;

    // 1. Relationship goal — 25
    if (me.lookingFor.isNotEmpty && other.lookingFor.isNotEmpty) {
      score += norm(me.lookingFor) == norm(other.lookingFor) ? 25 : 25 * 0.4;
    }

    // 2. Age fit — 20 (full inside my preferred range, partial within 3 years)
    final otherAge = other.age > 0
        ? other.age
        : (other.dateOfBirth != null
            ? DateTime.now().year - other.dateOfBirth!.year
            : 0);
    if (otherAge > 0) {
      if (otherAge >= me.minAgePreference && otherAge <= me.maxAgePreference) {
        score += 20;
      } else {
        final gap = otherAge < me.minAgePreference
            ? me.minAgePreference - otherAge
            : otherAge - me.maxAgePreference;
        if (gap <= 3) score += 20 * (1 - gap / 3) * 0.7;
      }
    }

    // 3. Shared interests — 18 (overlap ratio)
    final mine = me.interests.map(norm).toSet();
    final theirs = other.interests.map(norm).toSet();
    if (mine.isNotEmpty && theirs.isNotEmpty) {
      final shared = mine.intersection(theirs).length;
      final union = mine.union(theirs).length;
      if (union > 0) score += 18 * (shared / union);
    }

    // 4. Religion / community — 12
    if (me.religion.isNotEmpty &&
        other.religion.isNotEmpty &&
        norm(me.religion) == norm(other.religion)) {
      score += 12;
    }

    // 5. Location — 10 (same city full, same country partial)
    if (me.city.isNotEmpty && norm(me.city) == norm(other.city)) {
      score += 10;
    } else if (me.country.isNotEmpty &&
        norm(me.country) == norm(other.country)) {
      score += 10 * 0.4;
    }

    // 6. Language — 8 (any shared primary/other language)
    final myLangs = {norm(me.primaryLanguage), ...me.otherLanguages.map(norm)}
      ..removeWhere((e) => e.isEmpty);
    final theirLangs = {
      norm(other.primaryLanguage),
      ...other.otherLanguages.map(norm),
    }..removeWhere((e) => e.isEmpty);
    if (myLangs.isNotEmpty &&
        theirLangs.isNotEmpty &&
        myLangs.intersection(theirLangs).isNotEmpty) {
      score += 8;
    }

    // 7. Lifestyle — 7 (smoking + drinking + workout + family-values closeness)
    double sub = 0;
    int parts = 0;
    for (final pair in [
      [me.smoking, other.smoking],
      [me.drinking, other.drinking],
      [me.workout, other.workout],
    ]) {
      if (pair[0].isNotEmpty && pair[1].isNotEmpty) {
        parts++;
        if (norm(pair[0]) == norm(pair[1])) sub += 1;
      }
    }
    parts++;
    sub += (1 -
            (me.familyValuesImportance - other.familyValuesImportance).abs() /
                5)
        .clamp(0.0, 1.0);
    if (parts > 0) score += 7 * (sub / parts);

    return score.clamp(0, 100).round();
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

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = userDoc.data() ?? <String, dynamic>{};
    blockedUids = Set<String>.from(data['blockedUids'] ?? <String>[]);
  }

  /// Orders the Discover feed: brand-new profiles (joined in the last 7 days)
  /// come FIRST, then everyone else. Each group is shuffled with the current
  /// session seed so the order varies between sessions but stays stable while
  /// the user is browsing (no card jumping on stream re-emits).
  List<UserModel> _orderDiscover(List<UserModel> users) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final rng = Random(_discoverSeed);
    final fresh = <UserModel>[];
    final rest = <UserModel>[];
    for (final u in users) {
      (u.createdAt.isAfter(cutoff) ? fresh : rest).add(u);
    }
    fresh.shuffle(rng);
    rest.shuffle(rng);
    return [...fresh, ...rest];
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
            'Explore',
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

            // Show loading indicator only on fresh start with no profiles yet
            if (_isLoading && _profiles.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.goldMedium,
                ),
              );
            }

            // A not-yet-approved account can't see anyone else's profile in
            // Discover — mirrors the same admin-approval gates that decide
            // whether THIS user would be visible to others, applied here to
            // gate what they can see. Seed/demo accounts are pre-approved so
            // this never affects them.
            if (ps.hasData && !ProfileVisibilityHelper.isAccountApprovedForDiscover(profile)) {
              return const _AwaitingApprovalState();
            }

            final savedIds =
                ((profile['savedMatchIds'] as List<dynamic>?) ?? [])
                    .map((e) => e.toString())
                    .toSet();

            final rankedMaps = _profiles.map((u) {
              final m = u.toMap();
              m['uid'] = u.uid; // toMap() doesn't include uid — add it explicitly
              return m;
            }).toList();
            final matches = _applyFilters(rankedMaps, profile, hiddenMap);

            if (matches.isEmpty) {
              // Fresh deck is exhausted. If the user skipped anyone, show
              // an "all caught up" card with a one-tap way to revisit only
              // those skipped profiles (liked / matched / blocked people
              // are never included). Otherwise show the standard empty state.
              final skipped = _applyFilters(
                rankedMaps,
                profile,
                hiddenMap,
                includeSkipped: true,
              );
              if (skipped.isNotEmpty) {
                return _ResetDeckCard(
                  onReset: () => _resetDeck(hiddenMap),
                );
              }
              return _EmptyDiscoverState();
            }

            // Keep the next card's video buffering in the background so it's
            // ready the instant the user scrolls to it. Deferred to the next
            // frame so an about-to-become-active `_ReelCard` gets a chance to
            // adopt (consume) the current preload via didUpdateWidget/
            // _initVideo before we potentially advance/dispose it here.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updatePreload(matches);
            });

            return PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const PageScrollPhysics(),
              onPageChanged: (i) async {
                if (i > _currentPage) {
                  final swipeCheck =
                      await SubscriptionLimitsService.instance.canSwipe();
                  if (!swipeCheck.allowed) {
                    _showSwipeUpgradeSheet();
                    _pageController.jumpToPage(_currentPage);
                    return;
                  }
                  await SubscriptionLimitsService.instance.recordSwipe();
                }
                setState(() => _currentPage = i);
                _checkEmailLinkPopup();
              },
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final item = matches[index];
                final uid = (item['uid'] ?? '').toString();
                final isSaved = savedIds.contains(uid);
                final isPreloadTarget =
                    uid.isNotEmpty && uid == _preloadUid;
                return _ReelCard(
                  key: ValueKey(uid),
                  match: item,
                  isActive: index == _currentPage && widget.isTabActive && !_routeCovered,
                  isSaved: isSaved,
                  preloadedController:
                      isPreloadTarget ? _preloadController : null,
                  preloadedInitFuture:
                      isPreloadTarget ? _preloadInitFuture : null,
                  onPreloadConsumed:
                      isPreloadTarget ? () => _consumePreload(uid) : null,
                  onSkip: () => _dismissProfile(uid, hiddenMap, matches),
                  onSave: () => _toggleSaved(uid, isSaved),
                  onTap: () {
                    if (uid.isNotEmpty) {
                      MatchService.instance.recordProfileView(
                        viewedUserId: uid,
                      );
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MatchProfileDetailPage(profile: item),
                      ),
                    );
                  },
                  onConnect: () async {
                    if (uid.isEmpty) return;
                    final name = (item['name'] ?? '').toString();
                    final photo = (item['profilePicture'] ??
                            item['photoUrl'] ??
                            item['profilePhoto'] ??
                            '')
                        .toString();
                    final sent = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConnectRecordPage(
                          receiverId: uid,
                          receiverName: name,
                          receiverPhotoUrl: photo,
                        ),
                      ),
                    );
                    if (sent == true && mounted) {
                      _showMessage('Connection request sent.');
                      _nextCard(matches);
                    }
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

  void _nextCard(List<Map<String, dynamic>> matches) {
    if (_currentPage < matches.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Restored "Skip" (✕) action. Reuses the same `hiddenMatches` cooldown map
  /// already read in [_applyFilters] (`hidden > now` check) and expired in
  /// [_resetDeck] — this just writes a fresh 7-day-out timestamp for `uid` so
  /// the profile drops out of Discover until the cooldown lapses, then
  /// advances the reel to the next card (same as the Connect flow does).
  Future<void> _dismissProfile(
    String uid,
    Map<String, dynamic> hiddenMap,
    List<Map<String, dynamic>> matches,
  ) async {
    if (uid.isEmpty) return;
    final until =
        DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;
    final updated = Map<String, dynamic>.from(hiddenMap)..[uid] = until;
    _nextCard(matches);
    try {
      await UserService.instance.updateCurrentUserProfile(
        {'hiddenMatches': updated},
      );
    } catch (e) {
      debugPrint('SwipePage: dismiss profile error: $e');
    }
  }

  /// Restored "Save" (bookmark) action. Reuses the exact `savedMatchIds`
  /// list field already read/written by `saved_profiles_page.dart` — toggles
  /// membership of `uid` in that list on the current user's profile.
  Future<void> _toggleSaved(String uid, bool currentlySaved) async {
    if (uid.isEmpty) return;
    try {
      final myProfile = await UserService.instance.getCurrentUserProfile();
      final cur = ((myProfile?['savedMatchIds'] ?? []) as List)
          .map((e) => e.toString())
          .toSet();
      if (currentlySaved) {
        cur.remove(uid);
      } else {
        cur.add(uid);
      }
      await UserService.instance.updateCurrentUserProfile(
        <String, dynamic>{'savedMatchIds': cur.toList()},
      );
      if (mounted) {
        _showMessage(currentlySaved ? 'Removed from saved.' : 'Profile saved.');
      }
    } catch (e) {
      debugPrint('SwipePage: toggle saved error: $e');
    }
  }

  // ── Next-card video preloading ───────────────────────────────────────────
  /// Keeps at most one preloaded [VideoPlayerController] buffered ahead of
  /// [_currentPage] so the next card's video is already initializing by the
  /// time the user scrolls to it. Safe to call repeatedly (e.g. on every
  /// build/page change) — it no-ops unless the target changes.
  void _updatePreload(List<Map<String, dynamic>> matches) {
    final nextIndex = _currentPage + 1;
    if (nextIndex >= matches.length) {
      _clearPreload();
      return;
    }
    final nextItem = matches[nextIndex];
    final nextUid = (nextItem['uid'] ?? '').toString();
    if (nextUid.isEmpty || nextUid == _preloadUid) return;
    final nextUrl = (nextItem['introVideoUrl'] ?? '').toString();
    _clearPreload();
    if (nextUrl.isEmpty) return;
    _preloadUid = nextUid;
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(nextUrl));
      _preloadController = controller;
      // Timeout guards against a hung network init leaving this buffered
      // controller (and, transitively, the card that later adopts it) stuck
      // forever; catchError keeps a failed/timed-out preload from becoming
      // an unhandled async error, since the failure is (re)detected and
      // surfaced by the consuming `_ReelCard` via `.value.hasError` / its
      // own timeout on `preloadedInitFuture`.
      _preloadInitFuture =
          controller.initialize().timeout(_kVideoInitTimeout).catchError((_) {});
    } catch (_) {
      _preloadController = null;
      _preloadInitFuture = null;
      _preloadUid = null;
    }
  }

  /// Disposes any buffered-but-unused preloaded controller (e.g. the user
  /// scrolled past it without landing on that card, or scrolled further
  /// before it was consumed). No-op if a `_ReelCard` already took ownership
  /// (it clears these fields via [_consumePreload] first).
  void _clearPreload() {
    _preloadController?.dispose();
    _preloadController = null;
    _preloadInitFuture = null;
    _preloadUid = null;
  }

  /// Called by a `_ReelCard` when it adopts the preloaded controller matching
  /// its uid, so the parent stops tracking (and won't later dispose) it.
  void _consumePreload(String uid) {
    if (uid == _preloadUid) {
      _preloadController = null;
      _preloadInitFuture = null;
      _preloadUid = null;
    }
  }

  /// Resets the Discover deck back to the first profile. We expire the cooldown
  /// timestamps of the profiles the user skipped (the ✕ button → 7-day cooldown)
  /// so they re-enter the deck, then jump the PageView to profile zero. Profiles
  /// the user liked, matched with, or blocked are tracked separately and are NOT
  /// brought back. The live profile stream then rebuilds the deck from the top.
  Future<void> _resetDeck(Map<String, dynamic> hiddenMap) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = Map<String, dynamic>.from(hiddenMap);
    updated.updateAll((key, value) {
      final ms = int.tryParse(value.toString()) ?? 0;
      return ms > now ? 0 : value; // expire active cooldowns only
    });

    await UserService.instance.updateCurrentUserProfile(
      {'hiddenMatches': updated},
    );
    if (!mounted) return;
    setState(() => _currentPage = 0);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _showMessage('Starting over from the first profile 🔄');
  }

  Future<void> _checkEmailLinkPopup() async {
    // Soft one-time prompt removed — MainDashboard shows a mandatory
    // Google + Email linking dialog every time until both are linked.
    return;
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
                            // Clear BOTH the keyboard (viewInsets) AND the system
                            // gesture / home-indicator area (viewPadding) so the
                            // last chips aren't hidden behind the swipe zone.
                            MediaQuery.of(context).viewInsets.bottom +
                                MediaQuery.of(context).viewPadding.bottom +
                                24,
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
// ─── FULL-SCREEN REEL CARD (full-bleed intro-video, autoplay/loop) ───────────
// ═══════════════════════════════════════════════════════════════════════════════
class _ReelCard extends StatefulWidget {
  final Map<String, dynamic> match;
  final bool isActive;
  final bool isSaved;
  // A controller the parent already started buffering for THIS card (because
  // it was the "next" card while another was active), plus the Future from
  // its single `.initialize()` call. Null when nothing was preloaded for it.
  final VideoPlayerController? preloadedController;
  final Future<void>? preloadedInitFuture;
  // Tells the parent this card has taken ownership of the preloaded
  // controller above, so the parent stops tracking (and won't dispose) it.
  final VoidCallback? onPreloadConsumed;
  final VoidCallback onTap;
  final VoidCallback onConnect;
  final VoidCallback? onSkip;
  final VoidCallback? onSave;

  const _ReelCard({
    super.key,
    required this.match,
    required this.isActive,
    this.isSaved = false,
    this.preloadedController,
    this.preloadedInitFuture,
    this.onPreloadConsumed,
    required this.onTap,
    required this.onConnect,
    this.onSkip,
    this.onSave,
  });

  @override
  State<_ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<_ReelCard> {
  // Persists the user's last mute preference across cards/sessions.
  static const String _muteKey = 'discover_video_muted';

  VideoPlayerController? _videoController;
  bool _videoError = false;
  bool _muted = true;

  // Watches for a mid-playback stall (e.g. a network hiccup ExoPlayer/AVPlayer
  // never recovers from) that the initial-load timeout in `_initVideo()` can't
  // catch, since that timeout only guards the first `initialize()` call. Ticks
  // every 5s; if the reported position hasn't advanced for two consecutive
  // ticks while the controller believes it's actively playing, the video is
  // treated as stuck and routed into the same "Tap to retry" overlay already
  // used for load failures, rather than leaving the card silently frozen.
  Timer? _stallWatchdog;
  Duration _lastStallCheckPosition = Duration.zero;
  int _stallTicks = 0;

  // Monotonically-increasing generation id, bumped at the start of every
  // `_initVideo()` call. Lets overlapping calls (e.g. the user scrolling
  // quickly back and forth re-triggers init while a previous call is still
  // awaiting a slow network initialize()) detect they've been superseded
  // and safely dispose their own controller instead of racing to write
  // `_videoController`/`setState` — this is what prevents a double-init
  // leak or a disposed controller ending up referenced by the widget.
  int _initGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadMutePref().then((_) {
      if (mounted && widget.isActive) _initVideo();
    });
  }

  @override
  void didUpdateWidget(covariant _ReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_videoUrl(widget.match) != _videoUrl(oldWidget.match)) {
      _disposeVideo();
      if (widget.isActive) _initVideo();
      return;
    }
    if (widget.isActive && !oldWidget.isActive) {
      final controller = _videoController;
      if (controller == null) {
        _initVideo();
      } else {
        controller.seekTo(Duration.zero);
        controller.play();
        _stallTicks = 0;
        _lastStallCheckPosition = Duration.zero;
        if (_stallWatchdog == null) _startStallWatchdog();
      }
    } else if (!widget.isActive && oldWidget.isActive) {
      _videoController?.pause();
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  String _videoUrl(Map<String, dynamic> m) =>
      (m['introVideoUrl'] ?? '').toString();

  Future<void> _loadMutePref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final muted = prefs.getBool(_muteKey) ?? true;
      if (mounted) setState(() => _muted = muted);
    } catch (_) {
      // Best-effort only — default stays muted.
    }
  }

  Future<void> _initVideo() async {
    final url = _videoUrl(widget.match);
    // Bump the generation FIRST (and synchronously — no `await` above this
    // line) so this call immediately supersedes any still-in-flight call
    // for this same card. That earlier call's own `_stale()` checks (below)
    // will start returning true, so it disposes whatever controller it was
    // holding instead of touching `_videoController`/state — there is never
    // more than one "winning" controller per card.
    final myGeneration = ++_initGeneration;
    bool stale() => !mounted || myGeneration != _initGeneration;

    if (url.isEmpty) {
      if (mounted) setState(() => _videoError = true);
      return;
    }

    // If the parent already started buffering this exact card's video while
    // it was the "next" card, adopt that controller instead of starting a
    // fresh network fetch from zero.
    final preloaded = widget.preloadedController;
    if (preloaded != null) {
      widget.onPreloadConsumed?.call();
      try {
        // `preloadedInitFuture` is already timeout-capped where it's created
        // (see `_updatePreload`), but this second timeout also covers the
        // case where adoption itself stalls waiting on that future.
        await widget.preloadedInitFuture?.timeout(_kVideoInitTimeout);
        if (stale()) {
          preloaded.dispose();
          return;
        }
        if (preloaded.value.hasError) {
          preloaded.dispose();
          setState(() => _videoError = true);
          return;
        }
        await preloaded.setLooping(true);
        await preloaded.setVolume(_muted ? 0 : 1);
        if (stale()) {
          preloaded.dispose();
          return;
        }
        _disposeVideo();
        setState(() {
          _videoController = preloaded;
          _videoError = false;
        });
        if (widget.isActive) preloaded.play();
        _startStallWatchdog();
        return;
      } on TimeoutException {
        debugPrint('ReelCard: preloaded video init timed out for $url');
        preloaded.dispose();
        if (!stale()) setState(() => _videoError = true);
        return;
      } catch (e) {
        debugPrint('ReelCard: preloaded video adopt error: $e');
        preloaded.dispose();
        // Fall through to a normal init below.
      }
    }

    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize().timeout(_kVideoInitTimeout);
      if (stale()) {
        controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      if (stale()) {
        controller.dispose();
        return;
      }
      _disposeVideo();
      setState(() {
        _videoController = controller;
        _videoError = false;
      });
      if (widget.isActive) controller.play();
      _startStallWatchdog();
    } on TimeoutException {
      debugPrint('ReelCard: video init timed out for $url');
      controller?.dispose();
      if (!stale()) setState(() => _videoError = true);
    } catch (e) {
      debugPrint('ReelCard: video init error: $e');
      controller?.dispose();
      if (!stale()) setState(() => _videoError = true);
    }
  }

  /// "Tap to retry" affordance after a timed-out/failed init — resets the
  /// error state and re-runs `_initVideo()` from scratch (a fresh network
  /// fetch, since the failed controller was already disposed).
  void _retryVideo() {
    if (!mounted) return;
    setState(() => _videoError = false);
    _initVideo();
  }

  void _startStallWatchdog() {
    _stallWatchdog?.cancel();
    _stallTicks = 0;
    _lastStallCheckPosition = _videoController?.value.position ?? Duration.zero;
    _stallWatchdog = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkForStall(),
    );
  }

  void _checkForStall() {
    final controller = _videoController;
    if (!mounted || controller == null || !controller.value.isInitialized) {
      _stallWatchdog?.cancel();
      return;
    }
    if (controller.value.hasError) {
      _handleStall();
      return;
    }
    // Only a card that's supposed to be actively advancing can be "stuck" —
    // an inactive/paused card sitting still is expected, not a stall.
    if (!widget.isActive || !controller.value.isPlaying) {
      _stallTicks = 0;
      _lastStallCheckPosition = controller.value.position;
      return;
    }
    final position = controller.value.position;
    if (position == _lastStallCheckPosition) {
      _stallTicks++;
      if (_stallTicks >= 2) {
        _handleStall();
        return;
      }
    } else {
      _stallTicks = 0;
    }
    _lastStallCheckPosition = position;
  }

  /// Position hasn't moved for ~10s while the controller believes it's
  /// playing — treat exactly like a load failure: drop the frozen controller
  /// and surface the existing "Tap to retry" overlay instead of leaving the
  /// card silently stuck on its last frame forever.
  void _handleStall() {
    debugPrint('ReelCard: video stalled for ${_videoUrl(widget.match)}');
    _disposeVideo();
    if (mounted) setState(() => _videoError = true);
  }

  void _disposeVideo() {
    _stallWatchdog?.cancel();
    _stallWatchdog = null;
    _videoController?.dispose();
    _videoController = null;
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    setState(() => _muted = next);
    await _videoController?.setVolume(next ? 0 : 1);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_muteKey, next);
    } catch (_) {
      // Best-effort only.
    }
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // ─── Full-bleed intro-video (autoplay/loop, muted by default) ───
        GestureDetector(
          onTap: widget.onTap,
          child: _buildVideoLayer(),
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

        // ─── Tap-to-unmute control (top-right) ───
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 16,
          child: GestureDetector(
            onTap: _toggleMute,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),

        // ─── Bottom info ───
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

                  // ─── Restored Skip / Save / Connect row. Connect stays the
                  // most prominent action (expanded, filled gold pill);
                  // Skip and Save flank it as smaller circular icon buttons
                  // matching the same gold/dark card styling. ───
                  Row(
                    children: [
                      if (widget.onSkip != null) ...[
                        _CircleActionButton(
                          icon: Icons.close_rounded,
                          onTap: widget.onSkip,
                          tooltip: 'Skip',
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (widget.onSave != null) ...[
                        _CircleActionButton(
                          icon: widget.isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          iconColor: widget.isSaved
                              ? AppColors.goldMedium
                              : Colors.white,
                          onTap: widget.onSave,
                          tooltip: widget.isSaved ? 'Unsave' : 'Save',
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: widget.onConnect,
                            icon: const Icon(
                              Icons.forum_rounded,
                              size: 20,
                            ),
                            label: const Text('Connect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.goldMedium,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
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

  /// The user's real profile photo (main `profilePicture`, or the first
  /// entry of `photos` as a fallback) — preferred over the auto-generated
  /// video-frame thumbnail below since it's more recognizable/meaningful.
  String _profilePhotoUrl() {
    final profilePicture = (widget.match['profilePicture'] ?? '').toString();
    if (profilePicture.isNotEmpty) return profilePicture;
    final photos = widget.match['photos'];
    if (photos is List && photos.isNotEmpty) {
      return photos.first.toString();
    }
    return '';
  }

  String _thumbnailUrl() =>
      (widget.match['introVideoThumbnailUrl'] ?? '').toString();

  /// Instant-loading placeholder shown while the video buffers (and the
  /// permanent layer if there's no video at all). Preference order: the
  /// user's real profile photo, then the auto-generated video-frame
  /// thumbnail, then a plain dark container (never a broken-image icon).
  Widget _buildThumbnailLayer() {
    final profileUrl = _profilePhotoUrl();
    if (profileUrl.isNotEmpty) {
      return Image.network(
        profileUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildVideoThumbnailLayer(),
      );
    }
    return _buildVideoThumbnailLayer();
  }

  Widget _buildVideoThumbnailLayer() {
    final thumbUrl = _thumbnailUrl();
    if (thumbUrl.isEmpty) {
      return _noVideo();
    }
    return Image.network(
      thumbUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _noVideo(),
    );
  }

  Widget _buildVideoLayer() {
    final controller = _videoController;
    final videoReady =
        !_videoError && controller != null && controller.value.isInitialized;
    final hasUrl = _videoUrl(widget.match).isNotEmpty;

    if (!hasUrl) {
      // No playable video at all — thumbnail (or the plain placeholder) is
      // the permanent layer.
      return _buildThumbnailLayer();
    }

    if (_videoError) {
      // The video failed to load or timed out — never leave the card stuck
      // silently on the thumbnail forever; give the user a clear way to
      // retry instead.
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildThumbnailLayer(),
          _buildRetryOverlay(),
        ],
      );
    }

    // Thumbnail-first: show the thumbnail immediately, then cross-fade to
    // the live video once its controller has finished initializing.
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildThumbnailLayer(),
        AnimatedOpacity(
          opacity: videoReady ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: videoReady
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildRetryOverlay() {
    return GestureDetector(
      onTap: _retryVideo,
      child: Container(
        color: Colors.black.withOpacity(0.25),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap to retry',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noVideo() => Container(
    color: const Color(0xFF111111),
    child: const Icon(Icons.person, color: Colors.white12, size: 100),
  );
}

// ─── Small circular icon button used for the restored Skip/Save actions,
// styled to match the card's dark/gold theme (same treatment as the
// existing mute toggle). ───
class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final String? tooltip;

  const _CircleActionButton({
    required this.icon,
    this.iconColor = Colors.white,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
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

// ─── Empty state ───
// ─── Shown instead of the feed while the current user's own account is
// still awaiting admin approval (profile, intro video, and/or ID
// verification) — they can't see or connect with anyone until that clears.
class _AwaitingApprovalState extends StatelessWidget {
  const _AwaitingApprovalState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            color: AppColors.goldMedium.withOpacity(0.5),
            size: 72,
          ),
          const SizedBox(height: 24),
          const Text(
            'Your Profile Is Under Review',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Once our team approves your intro video and profile, you'll be able to see and connect with other members. Government ID is optional and can be added later for a trust badge.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14, height: 1.4),
          ),
        ],
      ),
    ),
  );
}

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

// ─── End-of-deck reset card: shown when the user reaches the final profile.
// Tapping Reset restarts the deck from the first profile (skipped people are
// shown again; liked / matched / blocked people are not). ───
class _ResetDeckCard extends StatelessWidget {
  const _ResetDeckCard({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.refresh_rounded,
            color: AppColors.goldMedium.withOpacity(0.6),
            size: 72,
          ),
          const SizedBox(height: 24),
          const Text(
            "You've reached the end",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "You've seen everyone for now. Tap Reset to start again from the first profile.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldMedium,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              label: const Text('Reset'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "People you liked or matched with won't reappear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}
