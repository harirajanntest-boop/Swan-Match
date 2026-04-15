import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/interest_service.dart';
import '../../../../shared/widgets/linear_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';

/// A Tinder-style swipeable card stack for the Recommended matches tab.
class SwipeCardStack extends StatefulWidget {
  final List<Map<String, dynamic>> matches;
  final Map<String, String> sentStatusByUser;
  final Set<String> savedIds;
  final Map<String, dynamic> userProfile;
  final Function(Map<String, dynamic> match) onViewProfile;
  final Function(String uid, bool save) onToggleSave;
  final Function(String uid) onDismiss;

  const SwipeCardStack({
    super.key,
    required this.matches,
    required this.sentStatusByUser,
    required this.savedIds,
    required this.userProfile,
    required this.onViewProfile,
    required this.onToggleSave,
    required this.onDismiss,
  });

  @override
  State<SwipeCardStack> createState() => _SwipeCardStackState();
}

class _SwipeCardStackState extends State<SwipeCardStack>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0.0;
  bool _isDragging = false;

  late AnimationController _animController;
  late Animation<Offset> _slideOutAnim;
  late Animation<double> _rotateOutAnim;
  bool _isAnimating = false;
  bool _swipeRight = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideOutAnim = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    ));
    _rotateOutAnim = Tween<double>(begin: 0, end: 0).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (_isAnimating) return;
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() {
      _dragOffset += details.delta;
      _dragAngle = _dragOffset.dx / 400 * 0.3;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimating) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.3;

    if (_dragOffset.dx.abs() > threshold) {
      _swipeRight = _dragOffset.dx > 0;
      _animateOut();
    } else {
      // Snap back
      setState(() {
        _dragOffset = Offset.zero;
        _dragAngle = 0.0;
        _isDragging = false;
      });
    }
  }

  void _animateOut() {
    _isAnimating = true;
    final direction = _swipeRight ? 1.5 : -1.5;
    final screenWidth = MediaQuery.of(context).size.width;

    _slideOutAnim = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(screenWidth * direction, _dragOffset.dy),
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    ));
    _rotateOutAnim = Tween<double>(
      begin: _dragAngle,
      end: direction * 0.5,
    ).animate(_animController);

    _animController.forward(from: 0).then((_) {
      if (!mounted) return;
      final match = widget.matches[_currentIndex];
      final uid = (match['uid'] ?? '').toString();

      if (_swipeRight) {
        // Swipe right → Save
        widget.onToggleSave(uid, true);
      } else {
        // Swipe left → Dismiss
        widget.onDismiss(uid);
      }

      setState(() {
        _currentIndex++;
        _dragOffset = Offset.zero;
        _dragAngle = 0.0;
        _isDragging = false;
        _isAnimating = false;
      });
    });
  }

  void _tapSendInterest() async {
    if (_currentIndex >= widget.matches.length) return;
    final match = widget.matches[_currentIndex];
    final uid = (match['uid'] ?? '').toString();
    if (uid.isEmpty) return;

    final status =
        (widget.sentStatusByUser[uid] ?? '').toLowerCase();
    if (status == 'pending' || status == 'accepted' || status == 'replied') {
      return;
    }

    final result = await InterestService.instance.sendInterest(toUserId: uid);
    if (!mounted) return;

    showLinearMessage(
      context,
      result == InterestSendResult.pending
          ? 'Interest already pending'
          : result == InterestSendResult.alreadyAccepted
              ? 'Interest already accepted. You can message now.'
              : 'Interest sent successfully ✨',
    );
    if (result != InterestSendResult.pending &&
        result != InterestSendResult.alreadyAccepted) {
      _maybeRequestReview();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.matches.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style_outlined,
                color: AppColors.goldMedium.withOpacity(0.4), size: 80),
            const SizedBox(height: 20),
            Text(
              'No more profiles to show',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
                fontFamily: 'serif',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new matches',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ─── Card counter ───
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentIndex + 1} of ${widget.matches.length}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.swipe,
                      color: AppColors.goldMedium.withOpacity(0.5), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Swipe to explore',
                    style: TextStyle(
                      color: AppColors.goldMedium.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ─── Card stack ───
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Background cards
                for (int i = math.min(
                        _currentIndex + 2, widget.matches.length - 1);
                    i > _currentIndex;
                    i--)
                  _buildBackCard(i - _currentIndex),

                // Top (active) card
                _buildTopCard(),
              ],
            ),
          ),
        ),

        // ─── Action buttons ───
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionBtn(
                icon: Icons.close,
                color: Colors.redAccent.shade200,
                size: 54,
                onTap: () {
                  if (_isAnimating || _currentIndex >= widget.matches.length) {
                    return;
                  }
                  _swipeRight = false;
                  _animateOut();
                },
              ),
              _buildActionBtn(
                icon: Icons.auto_awesome,
                color: AppColors.goldMedium,
                size: 64,
                isMain: true,
                onTap: _tapSendInterest,
              ),
              _buildActionBtn(
                icon: Icons.bookmark_add_outlined,
                color: Colors.greenAccent.shade200,
                size: 54,
                onTap: () {
                  if (_isAnimating || _currentIndex >= widget.matches.length) {
                    return;
                  }
                  _swipeRight = true;
                  _animateOut();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackCard(int offset) {
    final scale = 1.0 - (offset * 0.05);
    final yOffset = offset * 14.0;
    return Transform.translate(
      offset: Offset(0, yOffset),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: (1.0 - offset * 0.3).clamp(0.0, 1.0),
          child: _SwipeMatchCard(
            match: widget.matches[_currentIndex + offset],
            interestStatus: '',
            isSaved: false,
            isInteractive: false,
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard() {
    final match = widget.matches[_currentIndex];
    final uid = (match['uid'] ?? '').toString();
    final status = widget.sentStatusByUser[uid] ?? '';

    Widget card = _SwipeMatchCard(
      match: match,
      interestStatus: status,
      isSaved: widget.savedIds.contains(uid),
      isInteractive: true,
      onTap: () => widget.onViewProfile(match),
    );

    if (_isAnimating) {
      return AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Transform.translate(
            offset: _slideOutAnim.value,
            child: Transform.rotate(
              angle: _rotateOutAnim.value,
              child: child,
            ),
          );
        },
        child: card,
      );
    }

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Stack(
        children: [
          Transform.translate(
            offset: _dragOffset,
            child: Transform.rotate(
              angle: _dragAngle,
              child: card,
            ),
          ),
          // ─── Swipe indicators ───
          if (_isDragging && _dragOffset.dx > 40)
            Positioned(
              top: 40,
              left: 30,
              child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.greenAccent.shade200, width: 3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'SAVE',
                    style: TextStyle(
                      color: Colors.greenAccent.shade200,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            ),
          if (_isDragging && _dragOffset.dx < -40)
            Positioned(
              top: 40,
              right: 30,
              child: Transform.rotate(
                angle: 0.3,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: Colors.redAccent.shade200, width: 3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'SKIP',
                    style: TextStyle(
                      color: Colors.redAccent.shade200,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required Color color,
    required double size,
    bool isMain = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isMain
              ? AppColors.goldGradient
              : null,
          color: isMain ? null : Colors.white.withOpacity(0.06),
          border: Border.all(
            color: isMain ? Colors.transparent : color.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: isMain
              ? [
                  BoxShadow(
                    color: AppColors.goldMedium.withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: isMain ? Colors.black : color,
          size: size * 0.42,
        ),
      ),
    );
  }
}

// ─── Individual swipe match card ─────────────────────────────────────────────
class _SwipeMatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final String interestStatus;
  final bool isSaved;
  final bool isInteractive;
  final VoidCallback? onTap;

  const _SwipeMatchCard({
    required this.match,
    required this.interestStatus,
    required this.isSaved,
    this.isInteractive = false,
    this.onTap,
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
    if (dob == null) return '';
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return '$age';
  }

  @override
  Widget build(BuildContext context) {
    final name = _readValue(['name'], fallback: 'Member');
    final age = _ageText();
    final caste = _readValue(['caste']);
    final education = _readValue(['educationDegree']);
    final occupation = _readValue(['occupation']);
    final city = _readValue(['city']);
    final height = _readValue(['height']);
    final star = _readValue(['star']);
    final photoUrl = _readValue(['photoUrl', 'profileImageUrl', 'imageUrl']);
    final isOnline =
        match['isOnline'] == true || match['online'] == true;

    return GestureDetector(
      onTap: isInteractive ? onTap : null,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ─── Photo ───
              (match['showPhotosToEveryone'] == false || photoUrl.isEmpty)
                  ? Container(
                      color: const Color(0xFF1A1A1A),
                      child: Center(
                        child: Icon(
                          match['showPhotosToEveryone'] == false
                              ? Icons.lock_person_outlined
                              : Icons.person,
                          color: AppColors.goldDark.withOpacity(0.4),
                          size: 120,
                        ),
                      ),
                    )
                  : Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1A1A1A),
                        child: Center(
                          child: Icon(
                            Icons.person,
                            color: AppColors.goldDark.withOpacity(0.4),
                            size: 120,
                          ),
                        ),
                      ),
                    ),

              // ─── Gradient overlay ───
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.85),
                        Colors.black.withOpacity(0.95),
                      ],
                      stops: const [0.0, 0.35, 0.55, 0.75, 1.0],
                    ),
                  ),
                ),
              ),

              // ─── Top badges ───
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.blue.shade300.withOpacity(0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text("Verified",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              // ─── Online indicator ───
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOnline
                        ? Colors.green.shade900.withOpacity(0.8)
                        : Colors.grey.shade900.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.greenAccent : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Bottom info ───
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  age.isNotEmpty ? '$name, $age' : name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'serif',
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSaved)
                                const Icon(Icons.bookmark,
                                    color: AppColors.goldMedium, size: 22),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Attribute chips
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (occupation.isNotEmpty)
                                _chipWidget(Icons.work_outline, occupation),
                              if (city.isNotEmpty)
                                _chipWidget(Icons.location_on_outlined, city),
                              if (education.isNotEmpty)
                                _chipWidget(
                                    Icons.school_outlined, education),
                              if (height.isNotEmpty)
                                _chipWidget(
                                    Icons.height, height),
                              if (caste.isNotEmpty)
                                _chipWidget(Icons.groups_outlined, caste),
                              if (star.isNotEmpty)
                                _chipWidget(Icons.star_border, star),
                            ],
                          ),
                          if (isInteractive) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Tap to view full profile →',
                                    style: TextStyle(
                                      color:
                                          AppColors.goldLight.withOpacity(0.7),
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
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

  Widget _chipWidget(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.goldLight.withOpacity(0.7), size: 13),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Review helper ───
Future<void> _maybeRequestReview() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt('interest_send_count') ?? 0) + 1;
    await prefs.setInt('interest_send_count', count);
    if (count % 3 == 0) {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      }
    }
  } catch (_) {}
}
