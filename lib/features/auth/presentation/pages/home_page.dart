import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/match_service.dart';
import '../../../../services/user_service.dart';
import 'notifications_page.dart';
import 'edit_profile_page.dart';

class HomePage extends StatefulWidget {
  final void Function({Map<String, dynamic>? profile})? onOpenMatches;
  final VoidCallback? onOpenUpgrade;

  const HomePage({super.key, this.onOpenMatches, this.onOpenUpgrade});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  final MatchService _matchService = MatchService.instance;

  // ─── STREAMS CACHED IN STATE ───
  late final Stream<Map<String, dynamic>?> _userProfileStream;
  late final Stream<List<Map<String, dynamic>>> _recommendedMatchesStream;
  late final Stream<List<Map<String, dynamic>>> _newMatchesStream;

  @override
  void initState() {
    super.initState();

    // Initialize streams here to avoid re-creating them on every build
    _userProfileStream = UserService.instance.watchCurrentUserProfile();
    _recommendedMatchesStream = _matchService.watchRecommendedMatches(
      limit: 12,
    );
    _newMatchesStream = _matchService.watchNewMatches(days: 30);

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
    // ─── ADDED SCAFFOLD SO DRAWER ONLY BELONGS TO HOME TAB ───
    return Scaffold(
      backgroundColor: AppColors.obsidian, // Matches the parent dashboard
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _userProfileStream,
        builder: (context, snapshot) {
          final profile = snapshot.data ?? <String, dynamic>{};

          return SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: RefreshIndicator(
                  color: AppColors.goldMedium,
                  backgroundColor: AppColors.onyx,
                  onRefresh: () async =>
                      await Future.delayed(const Duration(seconds: 1)),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(profile),
                        _buildProfileTracker(profile),
                        _buildHorizontalList(
                          title: "Daily Recommendations",
                          subtitle: "Matches handpicked for you today",
                          hasTimer: true,
                          showViewAll: true,
                          stream: _recommendedMatchesStream,
                        ),
                        _buildPremiumBanner(),
                        _buildHorizontalList(
                          title: "New Matches",
                          subtitle: "Joined in the last 30 days",
                          hasTimer: false,
                          showViewAll: true,
                          stream: _newMatchesStream,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            "Celebrating 26 Years of Matchmaking",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> profile) {
    final name = (profile['name'] ?? '').toString().trim().isEmpty
        ? 'Member'
        : profile['name'].toString();
    final subscription = (profile['subscriptionPlan'] ?? 'free').toString();
    final memberType = subscription == 'free'
        ? 'Free Member'
        : 'Premium Member';
    final photoUrl =
        [profile['photoUrl'], profile['profileImageUrl'], profile['imageUrl']]
            .firstWhere(
              (value) => value != null && value.toString().trim().isNotEmpty,
              orElse: () => '',
            )
            .toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                // ─── BURGER MENU BUTTON WRAPPED IN BUILDER ───
                Builder(
                  builder: (BuildContext ctx) {
                    return IconButton(
                      icon: const Icon(
                        Icons.menu,
                        color: AppColors.goldMedium,
                        size: 28,
                      ),
                      onPressed: () {
                        // This uses the nested 'ctx' to find the Scaffold on THIS page
                        Scaffold.of(ctx).openDrawer();
                      },
                    );
                  },
                ),
                const SizedBox(width: 4),

                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldMedium.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.obsidian,
                    child: photoUrl.isEmpty
                        ? const Icon(Icons.person, color: AppColors.goldMedium)
                        : ClipOval(
                            child: Image.network(
                              photoUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  color: AppColors.goldMedium,
                                );
                              },
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hello, $name",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            "$memberType  ",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onOpenUpgrade,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.goldMedium.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "Upgrade",
                                style: TextStyle(
                                  color: AppColors.goldLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
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
            ),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none,
                  color: Colors.white70,
                ),
                onPressed: () {
                  // ─── NAVIGATE TO NOTIFICATIONS ───
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsPage(),
                    ),
                  );
                },
              ),
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildProfileTracker(Map<String, dynamic> profile) {
    final progress = UserService.instance.calculateProfileCompletion(profile);
    final progressText = '${(progress * 100).round()}%';

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Complete Your Profile",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                progressText,
                style: TextStyle(
                  color: AppColors.goldMedium.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.goldMedium,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActionPill(
                icon: Icons.add_a_photo_outlined,
                label: "Add Photo",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                ),
              ),
              _ActionPill(
                icon: Icons.verified_user_outlined,
                label: "Verify ID",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                ),
              ),
              _ActionPill(
                icon: Icons.family_restroom,
                label: "Family Info",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHorizontalList({
    required String title,
    required String subtitle,
    required bool hasTimer,
    required Stream<List<Map<String, dynamic>>> stream,
    required bool showViewAll,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (showViewAll)
                GestureDetector(
                  onTap: () => widget.onOpenMatches?.call(),
                  child: const Text(
                    "View All >",
                    style: TextStyle(
                      color: AppColors.goldMedium,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.goldMedium),
                );
              }

              final matches = snapshot.data ?? const <Map<String, dynamic>>[];
              if (matches.isEmpty) {
                return Center(
                  child: Text(
                    'No matches available.',
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  return _MiniMatchCard(
                    match: matches[index],
                    onTap: () =>
                        widget.onOpenMatches?.call(profile: matches[index]),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPremiumBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB8860B), Color(0xFFD4AF37), Color(0xFFF1D592)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldMedium.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.diamond_outlined,
              color: Colors.white.withOpacity(0.2),
              size: 120,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Unlock Prime Matches",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Call/WhatsApp matches directly\nView verified profiles & horoscopes.",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: widget.onOpenUpgrade,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "View Membership Plans",
                      style: TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionPill({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(icon, color: AppColors.goldMedium, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final VoidCallback? onTap;

  const _MiniMatchCard({required this.match, this.onTap});

  String _read(String key, {String fallback = ''}) {
    final raw = match[key];
    if (raw == null) return fallback;
    final text = raw.toString().trim();
    return text.isEmpty ? fallback : text;
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
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return '$age Yrs';
  }

  @override
  Widget build(BuildContext context) {
    final name = _read('name', fallback: 'Member');
    final height = _read('height', fallback: 'Height N/A');
    final photoUrl = _read('photoUrl').isNotEmpty
        ? _read('photoUrl')
        : (_read('profileImageUrl').isNotEmpty
              ? _read('profileImageUrl')
              : _read('imageUrl'));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2A2A), Color(0xFF111111)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child:
                    (match['showPhotosToEveryone'] == false || photoUrl.isEmpty)
                    ? Center(
                        child: Icon(
                          match['showPhotosToEveryone'] == false
                              ? Icons.admin_panel_settings_outlined
                              : Icons.person_outline,
                          color: Colors.white24,
                          size: 50,
                        ),
                      )
                    : Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.person_outline,
                              color: Colors.white24,
                              size: 50,
                            ),
                          );
                        },
                      ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (match['isOnline'] == true)
                      ? Colors.green.withOpacity(0.8)
                      : Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: (match['isOnline'] == true)
                            ? Colors.greenAccent
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      (match['isOnline'] == true) ? "Online" : "Offline",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${_ageText()} • $height",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
