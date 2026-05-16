import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/match_service.dart';
import '../../../../services/user_service.dart';
import '../../../../services/interest_service.dart';
import '../../../../models/interest_model.dart';
import '../../../../shared/widgets/linear_message.dart';
import 'notifications_page.dart';
import 'match_profile_detail_page.dart';
import 'settings_page.dart';
import 'subscription_page.dart';
import 'edit_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/auth_service.dart';




class SwipePage extends StatefulWidget {
  final void Function({Map<String, dynamic>? profile})? onOpenMatches;
  final VoidCallback? onOpenUpgrade;

  const SwipePage({super.key, this.onOpenMatches, this.onOpenUpgrade});

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage> {
  final MatchService _matchService = MatchService.instance;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final Stream<Map<String, dynamic>?> _userProfileStream;
  late final Stream<Map<String, String>> _sentInterestStatusStream;
  late final Stream<Map<String, String>> _receivedInterestStatusStream;
  late final Stream<List<Map<String, dynamic>>> _recommendedMatchesStream;

  // Local filter states
  String _genderFilter = 'All';
  RangeValues _ageRange = const RangeValues(18, 70);
  // Selected interest tags (multi-select from onboarding options)
  List<String> _selectedInterestTags = [];
  // Selected mother tongue (single-select from onboarding language list)
  String _motherTongueFilter = '';

  // Interest options mirrored from onboarding_step5_personality
  static const List<Map<String, dynamic>> _kInterestOptions = [
    {'label': 'Travel',           'icon': Icons.flight},
    {'label': 'Reading',          'icon': Icons.menu_book},
    {'label': 'Music',            'icon': Icons.music_note},
    {'label': 'Cooking',          'icon': Icons.restaurant},
    {'label': 'Photography',      'icon': Icons.camera_alt},
    {'label': 'Sports',           'icon': Icons.sports_soccer},
    {'label': 'Art',              'icon': Icons.brush},
    {'label': 'Technology',       'icon': Icons.computer},
    {'label': 'Movies',           'icon': Icons.movie},
    {'label': 'Yoga & Meditation','icon': Icons.spa},
    {'label': 'Dancing',          'icon': Icons.nightlife},
    {'label': 'Hiking',           'icon': Icons.terrain},
    {'label': 'Gaming',           'icon': Icons.sports_esports},
    {'label': 'Volunteering',     'icon': Icons.volunteer_activism},
    {'label': 'Fashion',          'icon': Icons.checkroom},
    {'label': 'Gardening',        'icon': Icons.local_florist},
    {'label': 'Writing',          'icon': Icons.edit},
    {'label': 'Fitness',          'icon': Icons.fitness_center},
  ];

  // Language options mirrored from onboarding_step4_cultural
  static const List<String> _kLanguageOptions = [
    'English', 'Spanish', 'French', 'Arabic', 'Hindi', 'Mandarin',
    'German', 'Italian', 'Tamil', 'Telugu', 'Turkish', 'Urdu', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _userProfileStream = UserService.instance.watchCurrentUserProfile();
    _sentInterestStatusStream =
        InterestService.instance.watchMySentInterestStatusByUserId();
    _receivedInterestStatusStream =
        InterestService.instance.watchInterestsForMe().map((items) {
      final latest = <String, InterestModel>{};
      for (final item in items) {
        final prev = latest[item.fromUserId];
        if (prev == null || item.updatedAt.isAfter(prev.updatedAt)) {
          latest[item.fromUserId] = item;
        }
      }
      return latest.map((k, v) => MapEntry(k, v.status.toLowerCase()));
    });
    _recommendedMatchesStream =
        _matchService.watchRecommendedMatches(limit: 50);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ─── Pre-cache the next profile's photos ───
  void _precacheNext(List<Map<String, dynamic>> matches, int currentIndex) {
    if (currentIndex + 1 >= matches.length) return;
    final next = matches[currentIndex + 1];
    final photos = _photosOf(next);
    for (final url in photos.take(3)) {
      precacheImage(CachedNetworkImageProvider(url), context);
    }
  }

  List<String> _photosOf(Map<String, dynamic> m) {
    final photos = m['photos'];
    if (photos is List && photos.isNotEmpty) {
      return photos.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    final single = (m['photoUrl'] ?? m['profilePhoto'] ?? m['profilePic'] ?? '').toString();
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

    // ── Read partner preferences ──────────────────────────────────────────────
    // Support both the root-level "partnerPreference" (gender) field AND the
    // nested "partnerPreferences" map written by the preferences settings page.
    final pref = (profile['partnerPreference'] ?? '').toString().trim().toLowerCase();
    final prefs = profile['partnerPreferences'] is Map
        ? Map<String, dynamic>.from(profile['partnerPreferences'] as Map)
        : <String, dynamic>{};

    // Force discover to show only the opposite gender of the current user.
    // We compute the user's own gender and then restrict allowedGenders
    // to the opposite (male -> female, female -> male). If the user's
    // gender is not set or is non-binary/unknown we fall back to the
    // previous partnerPreference logic.
    List<String> allowedGenders = [];
    final myGenderRaw = (profile['gender'] ?? '').toString().trim().toLowerCase();
    if (myGenderRaw == 'male' || myGenderRaw == 'man' || myGenderRaw == 'm') {
      allowedGenders = ['Female', 'female', 'woman', 'Woman'];
    } else if (myGenderRaw == 'female' || myGenderRaw == 'woman' || myGenderRaw == 'f') {
      allowedGenders = ['Male', 'male', 'man', 'Man'];
    } else {
      // Fallback to partnerPreference if user's gender is not available
      if (pref == 'female' || pref == 'women') allowedGenders = ['Female', 'female'];
      else if (pref == 'male' || pref == 'men') allowedGenders = ['Male', 'male'];
      else if (pref == 'both') allowedGenders = ['Male', 'male', 'Female', 'female'];

      // Overridden by nested prefs if present
      final prefGender = (prefs['gender'] ?? '').toString().trim().toLowerCase();
      if (prefGender.isNotEmpty) {
        if (prefGender == 'female' || prefGender == 'women') {
          allowedGenders = ['Female', 'female'];
        } else if (prefGender == 'male' || prefGender == 'men') {
          allowedGenders = ['Male', 'male'];
        } else if (prefGender == 'both' || prefGender == 'any') {
          allowedGenders = [];
        }
      }
    }

    // Age range
    final ageMin = _parseInt(prefs['ageMin'] ?? prefs['minAge']);
    final ageMax = _parseInt(prefs['ageMax'] ?? prefs['maxAge']);

    // Height range (cm)
    final heightMin = _parseInt(prefs['heightMin'] ?? prefs['minHeight']);
    final heightMax = _parseInt(prefs['heightMax'] ?? prefs['maxHeight']);

    // Religion — single string OR list
    final Set<String> allowedReligions = _toStringSet(prefs['religion'] ?? prefs['religions']);

    // Country — single string OR list
    final Set<String> allowedCountries = _toStringSet(prefs['country'] ?? prefs['countries']);

    // Mother tongue — single string OR list
    final Set<String> allowedTongues = _toStringSet(
        prefs['motherTongue'] ?? prefs['motherTongues'] ?? prefs['language']);

    // Education level — single string OR list
    final Set<String> allowedEducation = _toStringSet(
        prefs['educationLevel'] ?? prefs['education']);

    return matches.where((item) {
      final uid = (item['uid'] ?? '').toString();
      final itemGender = (item['gender'] ?? '').toString();

      // Skip profiles that are deleted, missing uid, or blocked
      if (uid.isEmpty || blocked.contains(uid) || item['isDeleted'] == true) {
        return false;
      }

      // ─ Local Bottom Sheet Filters ─
      if (_genderFilter != 'All') {
        final g = _normalizeGender(itemGender);
        final f = _normalizeGender(_genderFilter);
        if (g != f) return false;
      }

      final rawDob = item['dateOfBirth'];
      int? ageLocal;
      if (rawDob is DateTime) {
        final nowDate = DateTime.now();
        ageLocal = nowDate.year - rawDob.year;
        if (nowDate.month < rawDob.month || (nowDate.month == rawDob.month && nowDate.day < rawDob.day)) ageLocal--;
      } else if (rawDob != null && rawDob.runtimeType.toString() == 'Timestamp') {
        try {
          final dob = rawDob.toDate() as DateTime;
          final nowDate = DateTime.now();
          ageLocal = nowDate.year - dob.year;
          if (nowDate.month < dob.month || (nowDate.month == dob.month && nowDate.day < dob.day)) ageLocal--;
        } catch (_) {}
      }
      ageLocal ??= _parseInt(item['age'] ?? item['calculatedAge']);

      if (ageLocal != null) {
        if (ageMin != null && ageLocal < ageMin) return false;
        if (ageMax != null && ageLocal > ageMax) return false;
        if (ageLocal < _ageRange.start || ageLocal > _ageRange.end) return false;
      }

      if (_selectedInterestTags.isNotEmpty) {
        final interestsList = item['interests'] as List<dynamic>? ?? [];
        final profileInterests = interestsList.map((i) => i.toString().trim().toLowerCase()).toSet();
        final hasAny = _selectedInterestTags.any(
          (tag) => profileInterests.contains(tag.trim().toLowerCase()),
        );
        if (!hasAny) return false;
      }

      if (_motherTongueFilter.isNotEmpty) {
        final mt = (item['primaryLanguage'] ?? item['motherTongue'] ?? '').toString().trim().toLowerCase();
        if (mt != _motherTongueFilter.trim().toLowerCase()) return false;
      }

      // ─ Gender (Profile Prefs) ────────────────────────────────────────────
      if (_genderFilter == 'All' && allowedGenders.isNotEmpty) {
        final profileGenderNorm = _normalizeGender(itemGender);
        final allowedNorm = allowedGenders.map(_normalizeGender).toSet();
        if (!allowedNorm.contains(profileGenderNorm)) return false;
      }

      // ─ Height (Profile Prefs) ────────────────────────────────────────────
      final height = _parseInt(item['height'] ?? item['heightCm']);
      if (height != null) {
        if (heightMin != null && height < heightMin) return false;
        if (heightMax != null && height > heightMax) return false;
      }

      // ─ Religion ──────────────────────────────────────────────────────────
      if (allowedReligions.isNotEmpty) {
        final r = (item['religion'] ?? '').toString().trim().toLowerCase();
        if (!allowedReligions.any((a) => a == r)) return false;
      }

      // ─ Country ───────────────────────────────────────────────────────────
      if (allowedCountries.isNotEmpty) {
        final c = (item['country'] ?? item['location'] ?? '').toString().trim().toLowerCase();
        if (!allowedCountries.any((a) => c.contains(a))) return false;
      }

      // ─ Mother tongue ─────────────────────────────────────────────────────
      if (_motherTongueFilter.isEmpty && allowedTongues.isNotEmpty) {
        final t = (item['motherTongue'] ?? item['primaryLanguage'] ?? '')
            .toString().trim().toLowerCase();
        if (!allowedTongues.any((a) => a == t)) return false;
      }

      // ─ Education ─────────────────────────────────────────────────────────
      if (allowedEducation.isNotEmpty) {
        final e = (item['educationLevel'] ?? item['education'] ?? '')
            .toString().trim().toLowerCase();
        if (!allowedEducation.any((a) => a == e)) return false;
      }

      // ─ Ignored / hidden ──────────────────────────────────────────────────
      final ignoredMatchIds = (profile['ignoredMatchIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet();
      if (ignoredMatchIds.contains(uid)) return false;

      final hidden = int.tryParse((hiddenMap[uid] ?? '').toString()) ?? 0;
      if (hidden > now) return false;

      // ─ Interest status ───────────────────────────────────────────────────
      final ss = sentStatus[uid]?.toLowerCase() ?? '';
      if (ss == 'accepted' || ss == 'replied' || ss == 'sent' || ss == 'pending') return false;
      final rs = receivedStatus[uid]?.toLowerCase() ?? '';
      if (rs == 'accepted' || rs == 'replied') return false;

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
  String _normalizeGender(String raw) {
    final g = raw.trim().toLowerCase();
    if (g == 'male' || g == 'man' || g == 'm') return 'male';
    if (g == 'female' || g == 'woman' || g == 'f') return 'female';
    return g;
  }

  /// Converts a dynamic value to a lower-cased Set<String>.
  /// Accepts a single String or a List of Strings.
  Set<String> _toStringSet(dynamic v) {
    if (v == null) return {};
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s.isEmpty ? {} : {s};
    }
    if (v is List) {
      return v
          .map((e) => e.toString().trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    return {};
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
          title: const Text('Discover',
              style: TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w600, letterSpacing: 0.4)),
          actions: [
            IconButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage())),
              icon: const Icon(Icons.notifications_none_rounded,
                  color: Colors.white, size: 26),
            ),
            IconButton(
              onPressed: _showAdvancedFilterSheet,
              icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 26),
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
                ? Map<String, dynamic>.from(hiddenRaw) : <String, dynamic>{};

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
                        .where((e) => e.isNotEmpty).toSet();

                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _recommendedMatchesStream,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(
                              color: AppColors.goldMedium));
                        }
                        final matches = _applyFilters(
                            snap.data ?? [], profile, hiddenMap, sentStatus, recvStatus);

                        if (matches.isEmpty) return _EmptyDiscoverState();

                        return PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.vertical,
                          physics: const PageScrollPhysics(),
                          onPageChanged: (i) {
                            setState(() => _currentPage = i);
                            _precacheNext(matches, i);
                            _checkEmailLinkPopup();
                          },
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final item = matches[index];
                            final uid = (item['uid'] ?? '').toString();
                            return _ReelCard(
                              key: ValueKey(uid),
                              match: item,
                              photos: _photosOf(item),
                              interestStatus: sentStatus[uid] ?? '',
                              isSaved: savedIds.contains(uid),
                              onTap: () {
                                if (uid.isNotEmpty) {
                                  MatchService.instance
                                      .recordProfileView(viewedUserId: uid);
                                }
                                Navigator.push(context,
                                    MaterialPageRoute(builder: (_) =>
                                        MatchProfileDetailPage(profile: item)));
                              },
                              onDismiss: () async {
                                if (uid.isEmpty) return;
                                final curIgnored = ((profile['ignoredMatchIds'] ?? []) as List)
                                    .map((e) => e.toString()).toSet();
                                curIgnored.add(uid);
                                await UserService.instance
                                    .updateCurrentUserProfile({'ignoredMatchIds': curIgnored.toList()});
                                if (!context.mounted) return;
                                showLinearMessage(context, 'Profile ignored.');
                                _nextCard(matches);
                              },
                              onToggleSave: () async {
                                if (uid.isEmpty) return;
                                final cur = ((profile['savedMatchIds'] ?? []) as List)
                                    .map((e) => e.toString()).toSet();
                                if (cur.contains(uid)) {
                                  cur.remove(uid);
                                  showLinearMessage(context, 'Removed from saved.');
                                } else {
                                  cur.add(uid);
                                  showLinearMessage(context, 'Profile saved!');
                                }
                                await UserService.instance
                                    .updateCurrentUserProfile(
                                        {'savedMatchIds': cur.toList()});
                              },
                              onLike: () async {
                                if (uid.isEmpty) return;
                                HapticFeedback.mediumImpact();
                                final result = await InterestService.instance
                                    .sendInterest(toUserId: uid);
                                if (!context.mounted) return;
                                if (result == InterestSendResult.trialLimitReached) {
                                  _showSwipeUpgradeSheet(context);
                                  return;
                                }
                                showLinearMessage(context, 'Interest sent! 💛');
                                _nextCard(matches);
                              },
                            );
                          },
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
    final hasEmailOrGoogle = linkedProviders.contains('password') || linkedProviders.contains('google.com');

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // Linear, not modern rounded
          backgroundColor: const Color(0xFF141414),
          title: const Text('Account Security', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          content: const Text(
            'Secure your account by linking an Email or Google account. This ensures you never lose access to your matches.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldMedium,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // Linear look
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage(scrollToSecurity: true)));
              },
              child: const Text('Go to Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSwipeUpgradeSheet(BuildContext context) {
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 28),
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4A017), Color(0xFFC8960C)],
                ),
                boxShadow: [
                  BoxShadow(color: AppColors.goldMedium.withOpacity(0.3),
                      blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.black, size: 36),
            ),
            const SizedBox(height: 20),
            const Text('Daily Limit Reached',
                style: TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              'You\'ve used your 3 free daily connections.\n'
              'Upgrade to Premium for unlimited interests.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6),
                  fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SubscriptionPage()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldMedium,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: const Text('Upgrade to Premium',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Maybe later',
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdvancedFilterSheet() async {
    RangeValues tempAge = _ageRange;
    String tempGender = _genderFilter;
    List<String> tempInterests = List.from(_selectedInterestTags);
    String tempMotherTongue = _motherTongueFilter;

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
                        width: 40, height: 4,
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
                              child: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
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
                            20, 16, 20,
                            MediaQuery.of(context).viewInsets.bottom + 20,
                          ),
                          children: [
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
                                  onTap: () => setModalState(() => tempGender = g),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: sel ? AppColors.goldMedium : Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: sel ? AppColors.goldMedium : Colors.white.withOpacity(0.14),
                                      ),
                                    ),
                                    child: Text(
                                      g,
                                      style: TextStyle(
                                        color: sel ? Colors.black : Colors.white70,
                                        fontWeight: sel ? FontWeight.bold : FontWeight.w400,
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
                              inactiveColor: AppColors.goldMedium.withOpacity(0.2),
                              values: tempAge,
                              min: 18,
                              max: 70,
                              divisions: 52,
                              labels: RangeLabels(
                                '${tempAge.start.round()}',
                                '${tempAge.end.round()}',
                              ),
                              onChanged: (v) => setModalState(() => tempAge = v),
                            ),
                            const SizedBox(height: 24),

                            // ──────────────────── INTERESTS ────────────────────
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
                              children: _kInterestOptions.map((opt) {
                                final label = opt['label'] as String;
                                final icon  = opt['icon']  as IconData;
                                final sel   = tempInterests.contains(label);
                                return GestureDetector(
                                  onTap: () => setModalState(() {
                                    if (sel) {
                                      tempInterests.remove(label);
                                    } else {
                                      tempInterests.add(label);
                                    }
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? AppColors.goldMedium.withOpacity(0.18)
                                          : Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: sel
                                            ? AppColors.goldMedium
                                            : Colors.white.withOpacity(0.12),
                                        width: sel ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          icon,
                                          size: 14,
                                          color: sel ? AppColors.goldMedium : Colors.white38,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          label,
                                          style: TextStyle(
                                            color: sel ? AppColors.goldMedium : Colors.white54,
                                            fontSize: 13,
                                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),

                            // ──────────────────── MOTHER TONGUE ────────────────────
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
                              children: _kLanguageOptions.map((lang) {
                                final sel = tempMotherTongue == lang;
                                return GestureDetector(
                                  onTap: () => setModalState(() {
                                    tempMotherTongue = sel ? '' : lang;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? AppColors.goldMedium
                                          : Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: sel
                                            ? AppColors.goldMedium
                                            : Colors.white.withOpacity(0.14),
                                      ),
                                    ),
                                    child: Text(
                                      lang,
                                      style: TextStyle(
                                        color: sel ? Colors.black : Colors.white60,
                                        fontWeight: sel ? FontWeight.bold : FontWeight.w400,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 32),

                            // ──────────────────── ACTION BUTTONS ────────────────────
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: AppColors.goldMedium.withOpacity(0.6),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _ageRange = const RangeValues(18, 70);
                                        _selectedInterestTags = [];
                                        _motherTongueFilter = '';
                                        _genderFilter = 'All';
                                      });
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text(
                                      'Reset',
                                      style: TextStyle(color: AppColors.goldMedium),
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
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _ageRange = tempAge;
                                        _selectedInterestTags = tempInterests;
                                        _motherTongueFilter = tempMotherTongue;
                                        _genderFilter = tempGender;
                                      });
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text(
                                      'Apply',
                                      style: TextStyle(fontWeight: FontWeight.w700),
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
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final VoidCallback onToggleSave;
  final VoidCallback onLike;

  const _ReelCard({
    super.key,
    required this.match,
    required this.photos,
    required this.interestStatus,
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

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
        parent: _heartController, curve: Curves.easeInOut));
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
    } catch (_) { return null; }
  }

  List<String> _traits() {
    final tags = widget.match['lifestyleTags'] ??
        widget.match['personalityTraits'] ?? widget.match['interests'];
    if (tags is List && tags.isNotEmpty) {
      return tags.take(3).map((e) => e.toString()).toList();
    }
    final out = <String>[];
    final r = (widget.match['religion'] ?? '').toString().trim();
    if (r.isNotEmpty) out.add(r);
    final p = (widget.match['profession'] ?? widget.match['occupation'] ?? '').toString().trim();
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
    final age  = _age();
    final city    = (widget.match['city']    ?? '').toString().trim();
    final country = (widget.match['country'] ?? '').toString().trim();
    final location = [city, country].where((s) => s.isNotEmpty).join(', ');
    final bio  = (widget.match['bio'] ?? widget.match['shortBio'] ?? '').toString().trim();
    final traits = _traits();
    final isVerified = widget.match['isVerified'] == true ||
        widget.match['verificationStatus']?.toString().toLowerCase() == 'approved';
    final hasLiked = ['pending', 'sent'].contains(widget.interestStatus.toLowerCase());

    return Stack(
      fit: StackFit.expand,
      children: [
        // ─── Horizontal photo PageView ───
        PageView.builder(
          controller: _photoController,
          scrollDirection: Axis.horizontal,
          physics: const PageScrollPhysics(),
          onPageChanged: (i) => setState(() => _photoIndex = i),
          itemCount: _totalPages,
          itemBuilder: (ctx, i) {
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
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, __) => Container(color: const Color(0xFF111111),
                          child: const Center(child: CircularProgressIndicator(
                              color: AppColors.goldMedium, strokeWidth: 2))),
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
                final isUpgrade = widget.photos.isNotEmpty && i == widget.photos.length;
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

        // ─── Verified badge ───
        if (isVerified && !_isUpgradePage)
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            right: 20,
            child: Container(
              width: 34, height: 34,
              decoration: const BoxDecoration(
                  color: Color(0xFF4A90E2), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 20),
            ),
          ),

        // ─── Bottom info (hidden on upgrade page) ───
        if (!_isUpgradePage)
          Positioned(
            left: 0, right: 0, bottom: 0,
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
                                color: Colors.white, fontSize: 28,
                                fontWeight: FontWeight.bold, letterSpacing: 0.2,
                                shadows: [Shadow(blurRadius: 8, color: Colors.black54)]),
                          ),
                        ),
                        if (UserService.instance.isPremium(widget.match)) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD4A017), Color(0xFFC8960C)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, color: Colors.black, size: 14),
                                SizedBox(width: 2),
                                Text('PREMIUM', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(location,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.82), fontSize: 15,
                              shadows: const [Shadow(blurRadius: 6, color: Colors.black45)])),
                    ],
                    if (traits.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 6,
                          children: traits.map((t) => _TraitChip(label: t)).toList()),
                    ],
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        bio.length > 100 ? '${bio.substring(0, 100)}… ›' : bio,
                        style: TextStyle(color: Colors.white.withOpacity(0.78),
                            fontSize: 14, height: 1.45,
                            shadows: const [Shadow(blurRadius: 6, color: Colors.black45)]),
                        maxLines: 3, overflow: TextOverflow.ellipsis,
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
                          size: 58, iconSize: 26,
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
                          size: 58, iconSize: 24,
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
                            size: 68, iconSize: 32, glowing: true,
                            onTap: () {
                              if (hasLiked) return;
                              _heartController.forward(from: 0);
                              widget.onLike();
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
          bottom: 6, left: 0, right: 0,
          child: Center(
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withOpacity(0.25), size: 20),
          ),
        ),
      ],
    );
  }

  Widget _noPhoto() => Container(
      color: const Color(0xFF111111),
      child: const Icon(Icons.person, color: Colors.white12, size: 100));
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
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.goldMedium.withOpacity(0.1),
                  border: Border.all(color: AppColors.goldMedium.withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined,
                    color: AppColors.goldMedium, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'Want to see more?',
                style: TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add more photos of yourself to unlock\nexclusive profile views.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 15, height: 1.5),
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
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC8960C), AppColors.goldMedium],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(
                        color: AppColors.goldMedium.withOpacity(0.35),
                        blurRadius: 20, offset: const Offset(0, 6))],
                  ),
                  child: const Text(
                    'Add My Photos',
                    style: TextStyle(color: Colors.black, fontSize: 15,
                        fontWeight: FontWeight.bold),
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
    child: Text(label, style: const TextStyle(
        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
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
      width: size, height: size,
      decoration: BoxDecoration(
        color: bgColor, shape: BoxShape.circle,
        boxShadow: glowing
            ? [BoxShadow(color: AppColors.goldMedium.withOpacity(0.4),
                blurRadius: 22, spreadRadius: 2)]
            : null,
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    ),
  );
}

// ─── Empty state ───
class _EmptyDiscoverState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.favorite_outline_rounded,
          color: AppColors.goldMedium.withOpacity(0.35), size: 72),
      const SizedBox(height: 24),
      const Text('No profiles right now',
          style: TextStyle(color: Colors.white, fontSize: 20,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Text('Check back soon for new matches',
          style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14)),
    ]),
  );
}
