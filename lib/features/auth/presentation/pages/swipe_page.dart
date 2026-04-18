import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/match_service.dart';
import '../../../../services/user_service.dart';
import '../../../../services/interest_service.dart';
import '../../../../shared/widgets/linear_message.dart';
import 'swipe_card_stack.dart';
import 'notifications_page.dart';
import 'match_profile_detail_page.dart';

class SwipePage extends StatefulWidget {
  final void Function({Map<String, dynamic>? profile})? onOpenMatches;
  final VoidCallback? onOpenUpgrade;

  const SwipePage({super.key, this.onOpenMatches, this.onOpenUpgrade});

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  final MatchService _matchService = MatchService.instance;

  // ─── STREAMS CACHED IN STATE ───
  late final Stream<Map<String, dynamic>?> _userProfileStream;
  late final Stream<Map<String, String>> _sentInterestStatusStream;
  late final Stream<List<Map<String, dynamic>>> _recommendedMatchesStream;

  @override
  void initState() {
    super.initState();

    // Initialize streams here to avoid re-creating them on every build
    _userProfileStream = UserService.instance.watchCurrentUserProfile();
    _sentInterestStatusStream = InterestService.instance.watchMySentInterestStatusByUserId();
    _recommendedMatchesStream = _matchService.watchRecommendedMatches(limit: 50);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
      ),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _userProfileStream,
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data ?? <String, dynamic>{};
          final hiddenMapRaw = profile['hiddenMatches'];
          final hiddenMap = hiddenMapRaw is Map ? Map<String, dynamic>.from(hiddenMapRaw) : <String, dynamic>{};

          return StreamBuilder<Map<String, String>>(
            stream: _sentInterestStatusStream,
            builder: (context, statusSnapshot) {
              final sentStatusByUser = statusSnapshot.data ?? const <String, String>{};
              final savedIds = ((profile['savedMatchIds'] ?? const <dynamic>[]) as List)
                  .map((item) => item.toString()).where((item) => item.isNotEmpty).toSet();

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _recommendedMatchesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.goldMedium));
                  }

                  final matches = _applyFilters(snapshot.data ?? [], profile, hiddenMap);

                  return SafeArea(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          children: [
                            _buildHeader(profile),
                            Expanded(
                              child: SwipeCardStack(
                                matches: matches,
                                sentStatusByUser: sentStatusByUser,
                                savedIds: savedIds,
                                userProfile: profile,
                                onViewProfile: (match) {
                                  final viewedUid = (match['uid'] ?? '').toString();
                                  if (viewedUid.isNotEmpty) {
                                    MatchService.instance.recordProfileView(viewedUserId: viewedUid);
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MatchProfileDetailPage(profile: match),
                                    ),
                                  );
                                },
                                onToggleSave: (uid, save) async {
                                  if (uid.isEmpty) return;
                                  final current = ((profile['savedMatchIds'] ?? const <dynamic>[]) as List)
                                      .map((e) => e.toString()).toSet();
                                  if (save) {
                                    current.add(uid);
                                    showLinearMessage(context, 'Saved to saved matches.');
                                  } else {
                                    current.remove(uid);
                                    showLinearMessage(context, 'Removed from saved matches.');
                                  }
                                  await UserService.instance.updateCurrentUserProfile(<String, dynamic>{'savedMatchIds': current.toList()});
                                },
                                onDismiss: (uid) async {
                                  if (uid.isEmpty) return;
                                  final currentHidden = profile['hiddenMatches'] is Map
                                      ? Map<String, dynamic>.from(profile['hiddenMatches'] as Map) : <String, dynamic>{};
                                  currentHidden[uid] = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch;
                                  await UserService.instance.updateCurrentUserProfile(<String, dynamic>{'hiddenMatches': currentHidden});
                                  if (!context.mounted) return;
                                  showLinearMessage(context, 'Match hidden for 2 hours.');
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'SWAN',
            style: TextStyle(
              color: AppColors.goldMedium,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
              letterSpacing: 2,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.settings,
              color: AppColors.goldMedium,
              size: 28,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> matches,
    Map<String, dynamic> profile,
    Map<String, dynamic> hiddenMap,
  ) {
    final blockedUids = List<String>.from(profile['blockedUids'] ?? []);
    final partnerPreference = (profile['partnerPreference'] ?? '').toString().trim().toLowerCase();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Determine which genders to show based on partnerPreference
    List<String> allowedGenders = [];
    if (partnerPreference == 'female' || partnerPreference == 'women') {
      allowedGenders = ['Female', 'female'];
    } else if (partnerPreference == 'male' || partnerPreference == 'men') {
      allowedGenders = ['Male', 'male'];
    } else if (partnerPreference == 'both') {
      allowedGenders = ['Male', 'male', 'Female', 'female'];
    }

    final filtered = matches.where((item) {
      final uid = (item['uid'] ?? '').toString();
      if (uid.isEmpty) return false;
      if (blockedUids.contains(uid)) return false;

      // Filter by gender if partnerPreference is set and not empty
      if (allowedGenders.isNotEmpty) {
        final gender = (item['gender'] ?? '').toString();
        if (!allowedGenders.contains(gender)) return false;
      }

      final ignoredProfiles = profile['ignoredProfiles'] is Map
          ? Map<String, dynamic>.from(profile['ignoredProfiles'] as Map)
          : <String, dynamic>{};
      if (ignoredProfiles.containsKey(uid)) {
        final expiry = (ignoredProfiles[uid] as Timestamp).toDate().millisecondsSinceEpoch;
        if (expiry > now) return false;
      }

      final hiddenUntil = int.tryParse((hiddenMap[uid] ?? '').toString()) ?? 0;
      if (hiddenUntil > now) return false;

      return true;
    }).toList();

    return filtered;
  }
}
