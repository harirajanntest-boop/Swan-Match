import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/match_service.dart';
import '../../../../services/user_service.dart';
import '../../../../services/interest_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../models/interest_model.dart';
import '../../../../shared/widgets/linear_message.dart';
import 'swipe_card_stack.dart';
import 'match_profile_detail_page.dart';
import 'settings_page.dart';

class GoalSwipePage extends StatefulWidget {
  final String goalTitle;

  const GoalSwipePage({super.key, required this.goalTitle});

  @override
  State<GoalSwipePage> createState() => _GoalSwipePageState();
}

class _GoalSwipePageState extends State<GoalSwipePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  final MatchService _matchService = MatchService.instance;

  // ─── STREAMS CACHED IN STATE ───
  late final Stream<Map<String, dynamic>?> _userProfileStream;
  late final Stream<Map<String, String>> _sentInterestStatusStream;
  late final Stream<Map<String, String>> _receivedInterestStatusStream;
  late final Stream<List<Map<String, dynamic>>> _filteredMatchesStream;

  @override
  void initState() {
    super.initState();

    // MANDATORY: Check provider linking before allowing swipe page access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProviderLinking();
    });

    // Initialize streams
    _userProfileStream = UserService.instance.watchCurrentUserProfile();
    _sentInterestStatusStream = InterestService.instance.watchMySentInterestStatusByUserId();
    _receivedInterestStatusStream = InterestService.instance.watchInterestsForMe().map((items) {
      final latestByUser = <String, InterestModel>{};
      for (final item in items) {
        final previous = latestByUser[item.fromUserId];
        if (previous == null || item.updatedAt.isAfter(previous.updatedAt)) {
          latestByUser[item.fromUserId] = item;
        }
      }
      return latestByUser.map(
        (userId, model) => MapEntry(userId, model.status.toLowerCase()),
      );
    });
    _filteredMatchesStream = _matchService.watchMatchesByRelationshipGoal(widget.goalTitle);

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

  Future<void> _checkProviderLinking() async {
    // Account linking popup is disabled for now
    return;
  }

  Future<void> _showLinkingDialog(List<String> missing) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: AppColors.obsidian.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppColors.goldMedium.withOpacity(0.3)),
          ),
          title: const Column(
            children: [
              Icon(Icons.security, color: AppColors.goldMedium, size: 48),
              SizedBox(height: 16),
              Text(
                'Mandatory Account Linking',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'To ensure 100% security for your profile, please link all your accounts before using the app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: missing.map((m) => Chip(
                  label: Text(m, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                  backgroundColor: AppColors.goldMedium,
                )).toList(),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldMedium,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                },
                child: const Text(
                  'LINK NOW',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.goldMedium),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.goalTitle,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _userProfileStream,
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data ?? <String, dynamic>{};
          final hiddenMapRaw = profile['hiddenMatches'];
          final hiddenMap = hiddenMapRaw is Map ? Map<String, dynamic>.from(hiddenMapRaw) : <String, dynamic>{};

          return StreamBuilder<Map<String, String>>(
            stream: _sentInterestStatusStream,
            builder: (context, sentStatusSnapshot) {
              final sentStatusByUser = sentStatusSnapshot.data ?? const <String, String>{};
              
              return StreamBuilder<Map<String, String>>(
                stream: _receivedInterestStatusStream,
                builder: (context, receivedStatusSnapshot) {
                  final receivedStatusByUser = receivedStatusSnapshot.data ?? const <String, String>{};
                  
                  final savedIds = ((profile['savedMatchIds'] ?? const <dynamic>[]) as List)
                      .map((item) => item.toString()).where((item) => item.isNotEmpty).toSet();

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _filteredMatchesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.goldMedium));
                      }

                      final matches = _applyFilters(snapshot.data ?? [], profile, hiddenMap, sentStatusByUser, receivedStatusByUser);

                      if (matches.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search,
                                size: 64,
                                color: AppColors.goldMedium.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No profiles found for "${widget.goalTitle}"',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return SafeArea(
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: SlideTransition(
                            position: _slideAnim,
                            child: Column(
                              children: [
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
                                      final curIgnored = ((profile['ignoredMatchIds'] ?? []) as List)
                                          .map((e) => e.toString()).toSet();
                                      curIgnored.add(uid);
                                      await UserService.instance
                                          .updateCurrentUserProfile({'ignoredMatchIds': curIgnored.toList()});
                                      if (!context.mounted) return;
                                      showLinearMessage(context, 'Profile ignored.');
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
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> matches,
    Map<String, dynamic> profile,
    Map<String, dynamic> hiddenMap,
    Map<String, String> sentStatusByUser,
    Map<String, String> receivedStatusByUser,
  ) {
    final city = (profile['city'] ?? '').toString().trim();
    final ignoredMatchIds = (profile['ignoredMatchIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet();
    final blockedUids = List<String>.from(profile['blockedUids'] ?? []);
    final now = DateTime.now().millisecondsSinceEpoch;

    final filtered = matches.where((item) {
      final uid = (item['uid'] ?? '').toString();
      if (uid.isEmpty) return false;
      if (blockedUids.contains(uid)) return false;
      if (ignoredMatchIds.contains(uid)) return false;
      
      final hiddenUntil = int.tryParse((hiddenMap[uid] ?? '').toString()) ?? 0;
      if (hiddenUntil > now) return false;

      return true;
    }).toList();

    return filtered;
  }
}
