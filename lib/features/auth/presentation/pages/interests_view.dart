import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/colors.dart';
import '../../../../models/interest_model.dart';
import '../../../../services/interest_service.dart';
import '../../../../services/user_service.dart';
import 'its_a_match_overlay.dart';
import 'match_profile_detail_page.dart';
import 'chat_conversation_page.dart';

class InterestsView extends StatefulWidget {
  const InterestsView({super.key});

  @override
  State<InterestsView> createState() => _InterestsViewState();
}

class _InterestsViewState extends State<InterestsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// People who sent me an interest (I received them) — only pending ones show in "New"
  late final Stream<List<InterestModel>> _receivedInterestsStream;

  /// Interests I sent to others — used by Connections tab to check sent+accepted
  late final Stream<List<InterestModel>> _sentInterestsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _receivedInterestsStream = InterestService.instance.watchInterestsForMe();
    _sentInterestsStream = InterestService.instance.watchMySentInterests();
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: const Text(
                'Matches',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── Tab Bar (New / Connections) ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: StreamBuilder<List<InterestModel>>(
                stream: _receivedInterestsStream,
                builder: (context, snap) {
                  // "New" badge = pending received only
                  final newCount = (snap.data ?? [])
                      .where((i) => i.status.toLowerCase() == 'pending')
                      .length;
                  return _MatchTabBar(
                    controller: _tabController,
                    newCount: newCount,
                  );
                },
              ),
            ),

            const SizedBox(height: 4),
            const Divider(color: Colors.white10, height: 1),

            // ─── Tab Content ───
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // TAB 0 — New: received interests that are still PENDING
                  _MatchListTab(
                    stream: _receivedInterestsStream,
                    isReceived: true,
                    filterStatus: 'pending',
                    emptyMessage: 'No new matches yet',
                    emptySubMessage:
                        'When someone likes your profile, they\'ll appear here.',
                  ),
                  // TAB 1 — Connections: both sent & received where status == accepted
                  _ConnectionsTab(
                    receivedStream: _receivedInterestsStream,
                    sentStream: _sentInterestsStream,
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

// ═══════════════════════════════════════════════════════════════════════════════
// ─── CUSTOM TAB BAR ───────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _MatchTabBar extends StatefulWidget {
  final TabController controller;
  final int newCount;
  const _MatchTabBar({required this.controller, required this.newCount});

  @override
  State<_MatchTabBar> createState() => _MatchTabBarState();
}

class _MatchTabBarState extends State<_MatchTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabPill(
          label: 'New',
          badge: widget.newCount,
          isSelected: widget.controller.index == 0,
          onTap: () => widget.controller.animateTo(0),
        ),
        const SizedBox(width: 28),
        _TabPill(
          label: 'Connections',
          badge: 0,
          isSelected: widget.controller.index == 1,
          onTap: () => widget.controller.animateTo(1),
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final int badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 19,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w400,
                    letterSpacing: 0.1,
                  ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.goldMedium,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 2,
              width: isSelected ? 44 : 0,
              decoration: BoxDecoration(
                color: AppColors.goldMedium,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── MATCH LIST TAB ───────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _MatchListTab extends StatelessWidget {
  final Stream<List<InterestModel>> stream;
  final bool isReceived;
  final String emptyMessage;
  final String emptySubMessage;
  /// If non-null, only shows items matching this status
  final String? filterStatus;

  const _MatchListTab({
    required this.stream,
    required this.isReceived,
    required this.emptyMessage,
    required this.emptySubMessage,
    this.filterStatus,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InterestModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.goldMedium,
              strokeWidth: 2,
            ),
          );
        }

        final all = snapshot.data ?? const <InterestModel>[];
        // Apply status filter if provided
        final interests = filterStatus == null
            ? all
            : all.where((i) => i.status.toLowerCase() == filterStatus!.toLowerCase()).toList();

        // Deduplicate by other user, keep latest
        final byOtherUser = <String, InterestModel>{};
        for (final item in interests) {
          final key = isReceived ? item.fromUserId : item.toUserId;
          final prev = byOtherUser[key];
          if (prev == null || item.updatedAt.isAfter(prev.updatedAt)) {
            byOtherUser[key] = item;
          }
        }
        final sorted = byOtherUser.values.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        if (sorted.isEmpty) {
          return _EmptyState(
            icon: isReceived
                ? Icons.favorite_outline_rounded
                : Icons.people_outline_rounded,
            message: emptyMessage,
            subMessage: emptySubMessage,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final item = sorted[index];
            final otherUserId =
                isReceived ? item.fromUserId : item.toUserId;
            return _MatchRow(
              interest: item,
              otherUserId: otherUserId,
              isReceived: isReceived,
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── CONNECTIONS TAB — accepted from both sent & received streams ──────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _ConnectionsTab extends StatelessWidget {
  final Stream<List<InterestModel>> receivedStream;
  final Stream<List<InterestModel>> sentStream;

  const _ConnectionsTab({
    required this.receivedStream,
    required this.sentStream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InterestModel>>(
      stream: receivedStream,
      builder: (context, receivedSnap) {
        return StreamBuilder<List<InterestModel>>(
          stream: sentStream,
          builder: (context, sentSnap) {
            if (receivedSnap.connectionState == ConnectionState.waiting &&
                sentSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.goldMedium, strokeWidth: 2),
              );
            }

            final received = receivedSnap.data ?? [];
            final sent = sentSnap.data ?? [];

            // Only accepted, merged, deduplicated by the other user
            final byOtherUser = <String, InterestModel>{};

            for (final item in received.where(
                (i) => i.status.toLowerCase() == 'accepted')) {
              final key = item.fromUserId; // the sender (the other person)
              final prev = byOtherUser[key];
              if (prev == null || item.updatedAt.isAfter(prev.updatedAt)) {
                byOtherUser[key] = item;
              }
            }
            for (final item in
                sent.where((i) => i.status.toLowerCase() == 'accepted')) {
              final key = item.toUserId;
              final prev = byOtherUser[key];
              if (prev == null || item.updatedAt.isAfter(prev.updatedAt)) {
                byOtherUser[key] = item;
              }
            }

            final sorted = byOtherUser.values.toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

            if (sorted.isEmpty) {
              return const _EmptyState(
                icon: Icons.people_outline_rounded,
                message: 'No connections yet',
                subMessage: 'When a match is accepted, they\'ll appear here.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final item = sorted[index];
                // Determine which side was received
                final isReceived = item.status == 'accepted' &&
                    received.any((r) => r.id == item.id);
                final otherUserId =
                    isReceived ? item.fromUserId : item.toUserId;
                return _MatchRow(
                  interest: item,
                  otherUserId: otherUserId,
                  isReceived: isReceived,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── MATCH ROW ────────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _MatchRow extends StatefulWidget {
  final InterestModel interest;
  final String otherUserId;
  final bool isReceived;

  const _MatchRow({
    required this.interest,
    required this.otherUserId,
    required this.isReceived,
  });

  @override
  State<_MatchRow> createState() => _MatchRowState();
}

class _MatchRowState extends State<_MatchRow> {
  /// Cached future — created once in initState so rebuilds do NOT re-fire Firestore.
  late final Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = UserService.instance.getUserProfile(widget.otherUserId);
  }

  String _getPhotoUrl(Map<String, dynamic> profile) {
    final photos = profile['photos'];
    if (photos is List && photos.isNotEmpty) {
      return photos.first.toString();
    }
    return (profile['photoUrl'] ??
            profile['profilePhoto'] ??
            profile['profilePic'] ??
            '')
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data ?? <String, dynamic>{};
        final name = (profile['name'] ?? 'Member').toString();
        final status = widget.interest.status.toLowerCase();
        final photoUrl = _getPhotoUrl(profile);
        final isNew = status == 'pending';
        final isAccepted = status == 'accepted' || status == 'replied';
        final isDeclined = status == 'declined';

        // Subtitle text
        String subtitle;
        if (isAccepted) {
          subtitle = 'Connected';
        } else if (isDeclined) {
          subtitle = 'Declined';
        } else {
          subtitle = 'New Match';
        }

        return GestureDetector(
          onTap: () {
            if (profile.isEmpty) return;
            if (isAccepted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatConversationPage(
                    otherUserId: widget.otherUserId,
                    otherUserName: name,
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MatchProfileDetailPage(profile: profile),
                ),
              );
            }
          },
          onLongPress: isAccepted
              ? () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1A1A1A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: const Text('Disconnect',
                          style: TextStyle(color: Colors.white)),
                      content: Text(
                        'Remove your connection with $name? This cannot be undone.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel',
                              style: TextStyle(color: Colors.white54)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Disconnect',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await InterestService.instance.updateInterestStatus(
                      interestId: widget.interest.id,
                      status: 'declined',
                    );
                    if (!context.mounted) return;
                  }
                }
              : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E1E1E), width: 1),
              ),
            ),
            child: Row(
              children: [
                // ─── Avatar with online dot ───
                Stack(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isNew
                              ? AppColors.goldMedium
                              : isAccepted
                                  ? const Color(0xFF2ECC71)
                                  : Colors.white12,
                          width: isNew || isAccepted ? 2 : 1,
                        ),
                      ),
                      child: ClipOval(
                        child: photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _defaultAvatar(),
                              )
                            : _defaultAvatar(),
                      ),
                    ),
                    // Online indicator
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: (profile['isOnline'] == true ||
                                  profile['online'] == true)
                              ? const Color(0xFF2ECC71)
                              : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0C0C0C),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // ─── Name + subtitle ───
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Verified badge
                          if (profile['profileVerified'] == true ||
                              profile['idVerified'] == true) ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.verified,
                              color: AppColors.goldMedium,
                              size: 15,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isAccepted
                              ? const Color(0xFF2ECC71)
                              : isDeclined
                                  ? Colors.redAccent.withOpacity(0.7)
                                  : AppColors.goldMedium,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // ─── Action area ───
                if (widget.isReceived && isNew)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CircleIconBtn(
                        icon: Icons.close_rounded,
                        color: Colors.white10,
                        iconColor: Colors.white38,
                        size: 38,
                        onTap: () => InterestService.instance
                            .updateInterestStatus(
                                interestId: widget.interest.id,
                                status: 'declined'),
                      ),
                      const SizedBox(width: 8),
                      _CircleIconBtn(
                        icon: Icons.favorite_rounded,
                        color: AppColors.goldMedium,
                        iconColor: Colors.black,
                        size: 38,
                        onTap: () async {
                          // Accept interest
                          await InterestService.instance.updateInterestStatus(
                            interestId: widget.interest.id,
                            status: 'accepted',
                          );
                          if (!context.mounted) return;
                          // Fetch both profiles for the match overlay
                          final myUid =
                              FirebaseAuth.instance.currentUser?.uid ?? '';
                          final myProfile =
                              await UserService.instance.getUserProfile(myUid);
                          final theirProfileSnap = snapshot.data;
                          String myPhoto = '';
                          if (myProfile != null) {
                            final photos = myProfile['photos'];
                            if (photos is List && photos.isNotEmpty) {
                              myPhoto = photos.first.toString();
                            } else {
                              myPhoto = (myProfile['photoUrl'] ?? '').toString();
                            }
                          }
                          String theirPhoto = '';
                          if (theirProfileSnap != null) {
                            final photos = theirProfileSnap['photos'];
                            if (photos is List && photos.isNotEmpty) {
                              theirPhoto = photos.first.toString();
                            } else {
                              theirPhoto =
                                  (theirProfileSnap['photoUrl'] ?? '').toString();
                            }
                          }
                          if (!context.mounted) return;
                          await ItsAMatchOverlay.show(
                            context,
                            myPhotoUrl: myPhoto,
                            theirPhotoUrl: theirPhoto,
                            theirName: name,
                            theirUserId: widget.otherUserId,
                          );
                        },
                      ),
                    ],
                  )
                else if (isAccepted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF2ECC71).withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Chat',
                      style: TextStyle(
                        color: Color(0xFF2ECC71),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (isNew && !widget.isReceived)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.goldMedium,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: const Icon(Icons.person, color: Colors.white24, size: 28),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final double size;
  final VoidCallback onTap;

  const _CircleIconBtn({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: size * 0.48),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── EMPTY STATE ─────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subMessage;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.goldMedium, size: 64),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}