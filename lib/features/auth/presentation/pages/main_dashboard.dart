
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/interest_service.dart';
import '../../../../services/match_service.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/linear_message.dart';
import 'home_page.dart'; // ─── IMPORT THE NEW FILE HERE ───
import 'interests_view.dart';
import 'match_profile_detail_page.dart';
import 'messages_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/stripe_service.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/auth_service.dart';
import 'settings_page.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'feature_guide_page.dart';

class MainDashboard extends StatefulWidget {
  final int initialIndex;
  final Map<String, dynamic>? initialProfileToOpen;

  const MainDashboard({
    super.key,
    this.initialIndex = 0,
    this.initialProfileToOpen,
  });

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  // Opening on the Home page (Index 0)
  late int _currentIndex;
  Map<String, dynamic>? _pendingProfileToOpen;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pendingProfileToOpen = widget.initialProfileToOpen;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Show the feature guide first (only once for new users)
      final guideSeen = await _checkAndShowFeatureGuide();
      // Only show the linking popup if the guide was already seen
      // (otherwise we navigated away and this context is disposed)
      if (guideSeen && mounted) {
        _checkAndShowLinkingPopup();
      }
    });
  }

  /// Returns `true` if the guide was already seen (no navigation happened).
  /// Returns `false` if we navigated to the guide page.
  Future<bool> _checkAndShowFeatureGuide() async {
    final alreadySeen = await FeatureGuidePage.hasBeenShown();
    if (!alreadySeen && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const FeatureGuidePage(
            destination: MainDashboard(),
          ),
        ),
        (route) => false,
      );
      return false;
    }
    return true;
  }

  Future<void> _checkAndShowLinkingPopup() async {
    final profile = await UserService.instance.getCurrentUserProfile();

    // Auto-set registrationCompleted if the user is on the dashboard
    if (profile != null && profile['registrationCompleted'] != true) {
      await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
        'registrationCompleted': true,
      });
    }

    final linkedIds = AuthService.instance.getLinkedProviderIds();
    final missing = <String>[];
    if (!linkedIds.contains('google.com')) missing.add('Google');
    if (!linkedIds.contains('password')) missing.add('Email');
    if (!linkedIds.contains('phone')) missing.add('Phone Number');

    if (missing.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt('last_linking_popup_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Show daily (24 hours = 86400000 ms)
    if (now - lastShown > 86400000) {
      if (!mounted) return;
      await _showLinkingDialog(missing);
      await prefs.setInt('last_linking_popup_time', now);
    }
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
                style: TextStyle(color: Colors.white, fontFamily: 'serif', fontSize: 20),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'To ensure 100% security for your profile, please link all your accounts.',
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
              child: GoldGradientButton(
                text: 'LINK NOW',
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMatchesTab({Map<String, dynamic>? profile}) {
    setState(() {
      _currentIndex = 1;
      _pendingProfileToOpen = profile;
    });
  }

  void _openUpgradeTab() {
    setState(() => _currentIndex = 4);
  }

  @override
  Widget build(BuildContext context) {
    Widget currentPage;
    switch (_currentIndex) {
      case 0:
        currentPage = HomePage(
          onOpenMatches: ({Map<String, dynamic>? profile}) => _openMatchesTab(profile: profile),
          onOpenUpgrade: _openUpgradeTab,
        );
        break;
      case 1:
        currentPage = _MatchesView(
          pendingProfileToOpen: _pendingProfileToOpen,
          onPendingProfileOpened: () {
            if (!mounted) return;
            setState(() => _pendingProfileToOpen = null);
          },
        );
        break;
      case 2:
        currentPage = const InterestsView();
        break;
      case 3:
        currentPage = const MessagesView();
        break;
      default:
        currentPage = const _UpgradePlansPage();
    }

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: currentPage,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.obsidian,
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 20, offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppColors.obsidian,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.goldMedium,
          unselectedItemColor: Colors.white.withOpacity(0.4),
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, height: 1.8),
          unselectedLabelStyle: const TextStyle(fontSize: 10, height: 1.8),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.style_outlined), activeIcon: Icon(Icons.style), label: "Matches"),
            BottomNavigationBarItem(icon: Icon(Icons.favorite_border), activeIcon: Icon(Icons.favorite), label: "Interests"),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: "Messages"),
            BottomNavigationBarItem(icon: Icon(Icons.workspace_premium_outlined), activeIcon: Icon(Icons.workspace_premium), label: "Upgrade"),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── THE MATCHES VIEW ────────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════
class _MatchesView extends StatefulWidget {
  final Map<String, dynamic>? pendingProfileToOpen;
  final VoidCallback? onPendingProfileOpened;

  const _MatchesView({
    this.pendingProfileToOpen,
    this.onPendingProfileOpened,
  });

  @override
  State<_MatchesView> createState() => _MatchesViewState();
}

class _MatchesViewState extends State<_MatchesView> with SingleTickerProviderStateMixin {
  String _selectedTier = 'Regular'; 
  String _sortBy = 'Newest';
  bool _onlineOnly = false;
  bool _locationOnly = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  RangeValues _ageRange = const RangeValues(18, 60);
  String _occupationFilter = '';
  String _heightFilter = '';
  String _starFilter = '';
  final MatchService _matchService = MatchService.instance;
  String? _lastOpenedProfileUid;

  // ─── STREAMS CACHED IN STATE ───
  late final Stream<Map<String, dynamic>?> _userProfileStream;
  late final Stream<Map<String, String>> _sentInterestStatusStream;
  late final Stream<List<Map<String, dynamic>>> _recommendedMatchesStream;
  late final Stream<List<Map<String, dynamic>>> _allMatchesStream;
  late final Stream<List<Map<String, dynamic>>> _viewedYouStream;
  late final Stream<List<Map<String, dynamic>>> _savedMatchesSourceStream;

  @override
  void initState() {
    super.initState();

    // Initialize streams here to avoid re-creating them on every build
    _userProfileStream = UserService.instance.watchCurrentUserProfile();
    _sentInterestStatusStream = InterestService.instance.watchMySentInterestStatusByUserId();
    _recommendedMatchesStream = _matchService.watchRecommendedMatches();
    _allMatchesStream = _matchService.watchAllMatches();
    _viewedYouStream = _matchService.watchViewedYouMatches();
    _savedMatchesSourceStream = _matchService.watchRecommendedMatches(limit: 200);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryOpenPendingProfile();
    });
  }

  @override
  void didUpdateWidget(covariant _MatchesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tryOpenPendingProfile();
  }

  void _tryOpenPendingProfile() {
    final profile = widget.pendingProfileToOpen;
    if (profile == null) return;

    final uid = (profile['uid'] ?? '').toString();
    if (uid.isEmpty || uid == _lastOpenedProfileUid || !mounted) return;
    _lastOpenedProfileUid = uid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchProfileDetailPage(profile: profile),
        ),
      );
      widget.onPendingProfileOpened?.call();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Discover", style: TextStyle(color: Colors.white, fontSize: 28, fontFamily: 'serif', fontWeight: FontWeight.w600, letterSpacing: 1)),
                  Container(
                    decoration: BoxDecoration(color: AppColors.onyx, borderRadius: BorderRadius.circular(30), border: Border.all(color: AppColors.goldMedium.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [_buildTierToggle("Regular"), _buildTierToggle("PRIME")]),
                  ),
                ],
              ),
            ),
            TabBar(
              isScrollable: true, dividerColor: Colors.transparent,
              indicator: const UnderlineTabIndicator(borderSide: BorderSide(color: AppColors.goldMedium, width: 2), insets: EdgeInsets.symmetric(horizontal: 16)),
              labelColor: AppColors.goldMedium, unselectedLabelColor: Colors.white.withOpacity(0.4),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
              tabs: const [
                Tab(text: "Recommended"),
                Tab(text: "New Members"),
                Tab(text: "Viewed You"),
                Tab(text: "Saved Matches"),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                children: [
                  _buildRecommendedSwipeView(),
                  _buildNewMembersGrid(),
                  _buildViewedYouList(),
                  _buildSavedMatchesList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierToggle(String title) {
    bool isSelected = _selectedTier == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedTier = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(gradient: isSelected ? AppColors.goldGradient : null, borderRadius: BorderRadius.circular(30)),
        child: Row(
          children: [
            if (title == "PRIME" && !isSelected) ...[
              Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.goldMedium, shape: BoxShape.circle)), const SizedBox(width: 4),
            ],
            Text(title, style: TextStyle(color: isSelected ? Colors.black : Colors.white.withOpacity(0.7), fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 12, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  // ─── Shared filter logic ───
  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> matches,
    Map<String, dynamic> profile,
    Map<String, dynamic> hiddenMap,
  ) {
    final city = (profile['city'] ?? '').toString().trim();
    final ignoredProfiles = profile['ignoredProfiles'] is Map
        ? Map<String, dynamic>.from(profile['ignoredProfiles'] as Map)
        : <String, dynamic>{};
    final blockedUids = List<String>.from(profile['blockedUids'] ?? []);
    final now = DateTime.now().millisecondsSinceEpoch;

    final filtered = matches.where((item) {
      final uid = (item['uid'] ?? '').toString();
      if (uid.isEmpty) return false;
      if (blockedUids.contains(uid)) return false;
      if (ignoredProfiles.containsKey(uid)) {
        final expiry = (ignoredProfiles[uid] as Timestamp).toDate().millisecondsSinceEpoch;
        if (expiry > now) return false;
      }
      final hiddenUntil = int.tryParse((hiddenMap[uid] ?? '').toString()) ?? 0;
      if (hiddenUntil > now) return false;

      if (_selectedTier == 'PRIME') {
        final isPrime = item['isPrime'] == true ||
            item['subscriptionPlan']?.toString().toLowerCase() == 'prime';
        if (!isPrime) return false;
      }
      if (_onlineOnly) {
        final isOnline = item['isOnline'] == true || item['online'] == true;
        if (!isOnline) return false;
      }
      if (_locationOnly && city.isNotEmpty) {
        final matchCity = (item['city'] ?? '').toString().trim().toLowerCase();
        if (matchCity.isEmpty || matchCity != city.toLowerCase()) return false;
      }

      final rawDob = item['dateOfBirth'];
      int? age;
      if (rawDob is DateTime) {
        final nowDate = DateTime.now();
        age = nowDate.year - rawDob.year;
        if (nowDate.month < rawDob.month || (nowDate.month == rawDob.month && nowDate.day < rawDob.day)) age--;
      } else if (rawDob != null && rawDob.runtimeType.toString() == 'Timestamp') {
        try {
          final dob = rawDob.toDate() as DateTime;
          final nowDate = DateTime.now();
          age = nowDate.year - dob.year;
          if (nowDate.month < dob.month || (nowDate.month == dob.month && nowDate.day < dob.day)) age--;
        } catch (_) { age = null; }
      }
      if (age != null && (age < _ageRange.start || age > _ageRange.end)) return false;
      if (_occupationFilter.isNotEmpty) {
        final occ = (item['occupation'] ?? '').toString().toLowerCase();
        if (!occ.contains(_occupationFilter.toLowerCase())) return false;
      }
      if (_heightFilter.isNotEmpty) {
        final h = (item['height'] ?? '').toString().toLowerCase();
        if (!h.contains(_heightFilter.toLowerCase())) return false;
      }
      if (_starFilter.isNotEmpty) {
        final s = (item['star'] ?? '').toString().toLowerCase();
        if (!s.contains(_starFilter.toLowerCase())) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final haystack = [item['name'], item['occupation'], item['star'], item['height'], item['city']]
            .map((e) => (e ?? '').toString().toLowerCase()).join(' ');
        if (!haystack.contains(_searchQuery)) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (_sortBy == 'Name') {
        return (a['name'] ?? '').toString().toLowerCase()
            .compareTo((b['name'] ?? '').toString().toLowerCase());
      }
      return _extractDateTime(b['createdAt']).compareTo(_extractDateTime(a['createdAt']));
    });
    return filtered;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── RECOMMENDED: SWIPE CARD STACK ─────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildRecommendedSwipeView() {
    return StreamBuilder<Map<String, dynamic>?>(
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

            return Column(
              children: [
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Center(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by name, occupation, star, city...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                        prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.6)),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                                icon: const Icon(Icons.close, color: Colors.white70),
                              ),
                            IconButton(onPressed: _showAdvancedFilterSheet, icon: const Icon(Icons.filter_list, color: AppColors.goldMedium)),
                          ],
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _recommendedMatchesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.goldMedium));
                      }
                      final matches = _applyFilters(snapshot.data ?? [], profile, hiddenMap);
                      if (matches.isEmpty) {
                        return Center(
                          child: Text('No recommended matches yet.',
                              style: TextStyle(color: Colors.white.withOpacity(0.6))),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 16, bottom: 40),
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final item = matches[index];
                          final uid = (item['uid'] ?? '').toString();
                          return _EditorialMatchCard(
                            match: item,
                            interestStatus: sentStatusByUser[uid] ?? '',
                            isSaved: savedIds.contains(uid),
                            onToggleSave: () async {
                              if (uid.isEmpty) return;
                              final current = ((profile['savedMatchIds'] ?? const <dynamic>[]) as List)
                                  .map((e) => e.toString()).toSet();
                              if (current.contains(uid)) {
                                current.remove(uid);
                                showLinearMessage(context, 'Removed from saved matches.');
                              } else {
                                current.add(uid);
                                showLinearMessage(context, 'Saved to saved matches.');
                              }
                              await UserService.instance.updateCurrentUserProfile(<String, dynamic>{'savedMatchIds': current.toList()});
                            },
                            onDismissTemporarily: () async {
                              if (uid.isEmpty) return;
                              final currentHidden = profile['hiddenMatches'] is Map
                                  ? Map<String, dynamic>.from(profile['hiddenMatches'] as Map) : <String, dynamic>{};
                              currentHidden[uid] = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch;
                              await UserService.instance.updateCurrentUserProfile(<String, dynamic>{'hiddenMatches': currentHidden});
                              if (!context.mounted) return;
                              showLinearMessage(context, 'Match hidden for 2 hours.');
                            },
                            onTap: (profile) {
                              final viewedUid = (profile['uid'] ?? '').toString();
                              if (viewedUid.isNotEmpty) {
                                MatchService.instance.recordProfileView(viewedUserId: viewedUid);
                              }
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => MatchProfileDetailPage(profile: profile),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── NEW MEMBERS: SCROLL LIST WITH EDITORIAL CARDS ────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildNewMembersGrid() {
    return StreamBuilder<Map<String, dynamic>?>(
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

            return Column(
              children: [
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Center(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by name, occupation, star, city...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                        prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.6)),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                                icon: const Icon(Icons.close, color: Colors.white70),
                              ),
                            IconButton(onPressed: _showAdvancedFilterSheet, icon: const Icon(Icons.filter_list, color: AppColors.goldMedium)),
                          ],
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _allMatchesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.goldMedium));
                      }
                      final matches = _applyFilters(snapshot.data ?? [], profile, hiddenMap);
                      if (matches.isEmpty) {
                        return Center(
                          child: Text('No new members found yet.',
                              style: TextStyle(color: Colors.white.withOpacity(0.6))),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 16, bottom: 40),
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final item = matches[index];
                          final uid = (item['uid'] ?? '').toString();
                          return _EditorialMatchCard(
                            match: item,
                            interestStatus: sentStatusByUser[uid] ?? '',
                            isSaved: savedIds.contains(uid),
                            onToggleSave: () async {
                              if (uid.isEmpty) return;
                              final current = ((profile['savedMatchIds'] ?? const <dynamic>[]) as List)
                                  .map((e) => e.toString()).toSet();
                              if (current.contains(uid)) {
                                current.remove(uid);
                                showLinearMessage(context, 'Removed from saved matches.');
                              } else {
                                current.add(uid);
                                showLinearMessage(context, 'Saved to saved matches.');
                              }
                              await UserService.instance.updateCurrentUserProfile(<String, dynamic>{'savedMatchIds': current.toList()});
                            },
                            onDismissTemporarily: () async {
                              if (uid.isEmpty) return;
                              final currentHidden = profile['hiddenMatches'] is Map
                                  ? Map<String, dynamic>.from(profile['hiddenMatches'] as Map) : <String, dynamic>{};
                              currentHidden[uid] = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch;
                              await UserService.instance.updateCurrentUserProfile(<String, dynamic>{'hiddenMatches': currentHidden});
                              if (!context.mounted) return;
                              showLinearMessage(context, 'Match hidden for 2 hours.');
                            },
                            onTap: (profile) {
                              final viewedUid = (profile['uid'] ?? '').toString();
                              if (viewedUid.isNotEmpty) {
                                MatchService.instance.recordProfileView(viewedUserId: viewedUid);
                              }
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => MatchProfileDetailPage(profile: profile),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildViewedYouList() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _userProfileStream,
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data ?? const <String, dynamic>{};
        final savedIds = ((profile['savedMatchIds'] ?? const <dynamic>[]) as List)
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toSet();

        return StreamBuilder<Map<String, String>>(
          stream: _sentInterestStatusStream,
          builder: (context, statusSnapshot) {
            final sentStatusByUser = statusSnapshot.data ?? const <String, String>{};

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _viewedYouStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.goldMedium));
                }

                final items = snapshot.data ?? const <Map<String, dynamic>>[];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No one viewed your profile yet.',
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 16, bottom: 40),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final uid = (item['uid'] ?? '').toString();
                    return _EditorialMatchCard(
                      match: item,
                      interestStatus: sentStatusByUser[uid] ?? '',
                      isSaved: savedIds.contains(uid),
                      onTap: (profile) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchProfileDetailPage(profile: profile),
                          ),
                        );
                      },
                      onToggleSave: () async {
                        if (uid.isEmpty) return;
                        final current = ((profile['savedMatchIds'] ?? const <dynamic>[]) as List)
                            .map((e) => e.toString())
                            .toSet();
                        if (current.contains(uid)) {
                          current.remove(uid);
                        } else {
                          current.add(uid);
                        }
                        await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
                          'savedMatchIds': current.toList(),
                        });
                      },
                      onDismissTemporarily: null,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSavedMatchesList() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _userProfileStream,
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data ?? const <String, dynamic>{};
        final savedIds = ((profile['savedMatchIds'] ?? const <dynamic>[]) as List)
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toSet();

        if (savedIds.isEmpty) {
          return Center(
            child: Text(
              'No saved matches yet.',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          );
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _savedMatchesSourceStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.goldMedium));
            }

            final all = snapshot.data ?? const <Map<String, dynamic>>[];
            final saved = all.where((item) => savedIds.contains((item['uid'] ?? '').toString())).toList();

            if (saved.isEmpty) {
              return Center(
                child: Text(
                  'Saved profiles are currently unavailable.',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 16, bottom: 40),
              itemCount: saved.length,
              itemBuilder: (context, index) {
                final item = saved[index];
                final uid = (item['uid'] ?? '').toString();
                return _EditorialMatchCard(
                  match: item,
                  interestStatus: '',
                  isSaved: true,
                  onTap: (profile) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MatchProfileDetailPage(profile: profile)),
                    );
                  },
                  onDismissTemporarily: null,
                  onToggleSave: () async {
                    final current = ((profile['savedMatchIds'] ?? const <dynamic>[]) as List)
                        .map((e) => e.toString())
                        .toSet();
                    current.remove(uid);
                    await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
                      'savedMatchIds': current.toList(),
                    });
                    if (!context.mounted) return;
                    showLinearMessage(context, 'Removed from saved matches.');
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showAdvancedFilterSheet() async {
    final occupationController = TextEditingController(text: _occupationFilter);
    final heightController = TextEditingController(text: _heightFilter);
    final starController = TextEditingController(text: _starFilter);
    RangeValues tempAge = _ageRange;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.onyx,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final fieldDecoration = InputDecoration(
              labelStyle: TextStyle(color: AppColors.goldMedium.withOpacity(0.9)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.goldMedium.withOpacity(0.35)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.goldMedium, width: 1.5),
              ),
            );

            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.goldMedium,
                  secondary: AppColors.goldLight,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Advanced Filters', style: TextStyle(color: AppColors.goldLight, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('Age: ${tempAge.start.round()} - ${tempAge.end.round()}', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                    RangeSlider(
                      activeColor: AppColors.goldMedium,
                      inactiveColor: AppColors.goldMedium.withOpacity(0.25),
                      values: tempAge,
                      min: 18,
                      max: 70,
                      divisions: 52,
                      labels: RangeLabels('${tempAge.start.round()}', '${tempAge.end.round()}'),
                      onChanged: (values) => setModalState(() => tempAge = values),
                    ),
                    TextField(
                      controller: occupationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: fieldDecoration.copyWith(labelText: 'Occupation contains'),
                    ),
                    TextField(
                      controller: heightController,
                      style: const TextStyle(color: Colors.white),
                      decoration: fieldDecoration.copyWith(labelText: 'Height contains'),
                    ),
                    TextField(
                      controller: starController,
                      style: const TextStyle(color: Colors.white),
                      decoration: fieldDecoration.copyWith(labelText: 'Star contains'),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Ashwini', 'Rohini', 'Punarpoosam', 'Uthiram'].map((star) {
                        return ActionChip(
                          label: Text(star, style: const TextStyle(color: AppColors.goldLight)),
                          backgroundColor: AppColors.goldMedium.withOpacity(0.08),
                          side: BorderSide(color: AppColors.goldMedium.withOpacity(0.45)),
                          onPressed: () {
                            setState(() {
                              _starFilter = star;
                              _ageRange = tempAge;
                              _occupationFilter = occupationController.text.trim();
                              _heightFilter = heightController.text.trim();
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.goldMedium.withOpacity(0.6)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            onPressed: () {
                              setState(() {
                                _ageRange = const RangeValues(18, 60);
                                _occupationFilter = '';
                                _heightFilter = '';
                                _starFilter = '';
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text('Reset', style: TextStyle(color: AppColors.goldLight)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.goldMedium,
                              foregroundColor: AppColors.obsidian,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            onPressed: () {
                              setState(() {
                                _ageRange = tempAge;
                                _occupationFilter = occupationController.text.trim();
                                _heightFilter = heightController.text.trim();
                                _starFilter = starController.text.trim();
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  DateTime _extractDateTime(dynamic raw) {
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
}

// ─── Google / App Store In-App Review Trigger ────────────────────────────────
Future<void> _maybeRequestReview() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt('interest_send_count') ?? 0) + 1;
    await prefs.setInt('interest_send_count', count);
    // Show review dialog on every 3rd successful send
    if (count % 3 == 0) {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      }
    }
  } catch (_) {
    // Never crash the UI for a review prompt
  }
}

class _EditorialMatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final ValueChanged<Map<String, dynamic>>? onTap;
  final String interestStatus;
  final bool isSaved;
  final VoidCallback? onToggleSave;
  final VoidCallback? onDismissTemporarily;

  const _EditorialMatchCard({
    required this.match,
    this.onTap,
    this.interestStatus = '',
    this.isSaved = false,
    this.onToggleSave,
    this.onDismissTemporarily,
  });

  String _readValue(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = match[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  String _ageText() {
    final raw = match['dateOfBirth'];
    DateTime? dob;
    if (raw is DateTime) {
      dob = raw;
    } else if (raw != null && raw.runtimeType.toString() == 'Timestamp') {
      try {
        dob = raw.toDate() as DateTime;
      } catch (_) {
        dob = null;
      }
    }
    if (dob == null) return 'Age N/A';
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return '$age Yrs';
  }

  @override
  Widget build(BuildContext context) {
    final name = _readValue(['name'], fallback: 'Member');
    final height = _readValue(['height'], fallback: 'Height N/A');
    final caste = _readValue(['caste'], fallback: 'Caste N/A');
    final education = _readValue(['educationDegree'], fallback: 'Education N/A');
    final occupation = _readValue(['occupation'], fallback: 'Occupation N/A');
    final city = _readValue(['city'], fallback: 'City N/A');
    final uid = _readValue(['uid']);
    final photoUrl = _readValue(['photoUrl', 'profileImageUrl', 'imageUrl']);
    final normalizedStatus = interestStatus.toLowerCase();
    final isPending = normalizedStatus == 'pending';
    final isAccepted = normalizedStatus == 'accepted' || normalizedStatus == 'replied';
    final isRejected = normalizedStatus == 'declined' || normalizedStatus == 'rejected';

    return GestureDetector(
      onTap: () => onTap?.call(match),
      child: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 32),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 420, width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: [Color(0xFF2A2A2A), Color(0xFF111111)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 10))],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: (match['showPhotosToEveryone'] == false || photoUrl.isEmpty)
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 80.0),
                                child: Icon(
                                  match['showPhotosToEveryone'] == false ? Icons.lock_person_outlined : Icons.person,
                                  color: AppColors.goldDark,
                                  size: 100,
                                ),
                              ),
                            )
                          : Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 80.0),
                                    child: Icon(
                                      Icons.person,
                                      color: AppColors.goldDark,
                                      size: 100,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                Positioned(
                  top: 16, right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: onToggleSave,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(top: 20, left: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.blue.shade900.withOpacity(0.8), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade300.withOpacity(0.5))), child: const Row(children: [Icon(Icons.verified, color: Colors.white, size: 14), SizedBox(width: 4), Text("Verified", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))]))),
                ],
              ),
            ),
            Positioned(
              bottom: -20, left: 16, right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.onyx.withOpacity(0.85), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.goldMedium.withOpacity(0.3), width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -2))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: AppColors.goldLight,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'serif',
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: (match['isOnline'] == true || match['online'] == true)
                                        ? Colors.greenAccent
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (match['isOnline'] == true || match['online'] == true) ? "Online" : "Offline",
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildAttributeText(_ageText(), height, caste), const SizedBox(height: 6), _buildAttributeText(education, occupation, city),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: onDismissTemporarily,
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                                  color: Colors.white.withOpacity(0.05),
                                ),
                                child: const Icon(Icons.close, color: Colors.white54, size: 22),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  if (isPending || isAccepted) return;
                                  if (uid.isEmpty) return;
                                  final result = await InterestService.instance.sendInterest(toUserId: uid);
                                  if (!context.mounted) return;
                                  showLinearMessage(
                                    context,
                                    result == InterestSendResult.pending
                                        ? 'Interest already pending'
                                        : result == InterestSendResult.alreadyAccepted
                                            ? 'Interest already accepted. You can message now.'
                                            : (isRejected
                                                ? 'Interest request sent again.'
                                                : 'Interest sent successfully'),
                                  );
                                  // ─── Google Review after every 3rd send interest ───
                                  if (result != InterestSendResult.pending &&
                                      result != InterestSendResult.alreadyAccepted) {
                                    _maybeRequestReview();
                                  }
                                },
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: (isPending || isAccepted) ? null : AppColors.goldGradient,
                                    color: (isPending || isAccepted) ? Colors.white.withOpacity(0.08) : null,
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(color: AppColors.goldDark.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isAccepted
                                            ? Icons.check_circle_outline
                                            : isPending
                                                ? Icons.hourglass_top
                                                : isRejected
                                                    ? Icons.refresh
                                                    : Icons.auto_awesome,
                                        color: (isPending || isAccepted)
                                            ? Colors.white70
                                            : AppColors.obsidian,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isAccepted
                                            ? "Accepted"
                                            : isPending
                                                ? "Pending"
                                                : isRejected
                                                    ? "Retry Interest"
                                                    : "Send Interest",
                                        style: TextStyle(
                                          color: (isPending || isAccepted)
                                              ? Colors.white70
                                              : AppColors.obsidian,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributeText(String t1, String t2, String t3) {
    final style = TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13);
    return Row(
      children: [
        Flexible(
          child: Text(
            t1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        _goldDot(),
        Flexible(
          child: Text(
            t2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        _goldDot(),
        Flexible(
          child: Text(
            t3,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }

  Widget _goldDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(color: AppColors.goldMedium.withOpacity(0.6), shape: BoxShape.circle),
      ),
    );
  }
}

class _UpgradePlansPage extends StatefulWidget {
  const _UpgradePlansPage();

  @override
  State<_UpgradePlansPage> createState() => _UpgradePlansPageState();
}

class _UpgradePlansPageState extends State<_UpgradePlansPage> {
  bool _isLoading = false;

  static const _priceId = StripeService.premiumMonthlyPriceId;

  static const _features = [
    'Unlimited Send Interest',
    'See Who Liked You',
    'Advanced Filters',
    'Priority Profile Boost',
    'Ad-Free Experience',
    'Chat & Video Call Unlock',
  ];

  Future<void> _onSubscribe() async {
    setState(() => _isLoading = true);
    try {
      const successUrl = 'https://swanmatch.page.link/payment-success';
      const cancelUrl  = 'https://swanmatch.page.link/payment-cancel';
      await StripeService.instance.startSubscription(
        priceId: _priceId,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
      );
    } catch (e) {
      if (mounted) showLinearMessage(context, 'Unable to open payment. Please check your connection and try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ─── Crown Icon ───
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldMedium.withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.workspace_premium, color: Colors.black, size: 42),
                ),
                const SizedBox(height: 22),

                // ─── Title ───
                const Text(
                  'Upgrade to SWAN Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Find your perfect match without limits',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // ─── Feature List Card ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Column(
                    children: _features
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: AppColors.goldMedium, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    f,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Pricing Card ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.goldMedium.withOpacity(0.22),
                        AppColors.goldLight.withOpacity(0.1),
                      ],
                    ),
                    border: Border.all(color: AppColors.goldMedium.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.goldMedium.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: AppColors.goldLight, size: 14),
                            SizedBox(width: 5),
                            Text(
                              'Most Popular',
                              style: TextStyle(color: AppColors.goldLight, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Premium Monthly',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '\$19.99',
                        style: TextStyle(
                          color: AppColors.goldLight,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                        ),
                      ),
                      const Text(
                        '/ month',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cancel anytime · No hidden fees',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ─── Pay Now Button ───
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onSubscribe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldMedium,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.workspace_premium, size: 20),
                        SizedBox(width: 10),
                        Text('Subscribe Now — \$19.99 / mo'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Legal note ───
                Text(
                  'Billed monthly. Cancel anytime from your account settings.',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.55),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.goldMedium),
            ),
          ),
      ],
    );
  }
}