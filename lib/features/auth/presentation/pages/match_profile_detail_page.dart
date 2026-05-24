import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../../core/constants/colors.dart';
import '../../../../services/interest_service.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/helpers/deleted_user_helper.dart';
import '../../../../shared/helpers/profile_visibility_helper.dart';
import '../../../../shared/widgets/linear_message.dart';
import 'chat_conversation_page.dart';
import 'subscription_page.dart';

class MatchProfileDetailPage extends StatefulWidget {
  final Map<String, dynamic> profile;
  /// When true, pops with `true` after a successful interest send (swipe flow).
  final bool popOnInterestSent;

  const MatchProfileDetailPage({
    super.key,
    required this.profile,
    this.popOnInterestSent = false,
  });

  @override
  State<MatchProfileDetailPage> createState() => _MatchProfileDetailPageState();
}

class _MatchProfileDetailPageState extends State<MatchProfileDetailPage> {
  // Streams cached in state to avoid re-subscribing on rebuild
  late final Stream<Set<String>> _pendingStream;
  late final Stream<Set<String>> _acceptedStream;

  bool _isSending = false;
  bool _connectInFlight = false;

  @override
  void initState() {
    super.initState();
    _pendingStream = InterestService.instance
        .watchMyPendingSentInterestUserIds();
    _acceptedStream = InterestService.instance
        .watchMyAcceptedSentInterestUserIds();
  }

  String _read(String key, {String fallback = ''}) {
    final raw = widget.profile[key];
    if (raw == null) return fallback;
    final text = raw.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  int? _age() {
    final dob = widget.profile['dateOfBirth'];
    if (dob == null) {
      final rawAge = widget.profile['age'];
      if (rawAge is int && rawAge > 0) return rawAge;
      return null;
    }
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

  String _location() {
    final city = _read('city');
    final country = _read('country');
    return [city, country].where((s) => s.isNotEmpty).join(', ');
  }

  List<String> _photos() {
    final photos = widget.profile['photos'];
    if (photos is List && photos.isNotEmpty) {
      return photos
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final single =
        (widget.profile['photoUrl'] ??
                widget.profile['profileImageUrl'] ??
                widget.profile['imageUrl'] ??
                '')
            .toString()
            .trim();
    return single.isNotEmpty ? [single] : [];
  }

  List<String> _values() {
    final out = <String>[];
    final traits =
        widget.profile['personalityTraits'] ?? widget.profile['lifestyleTags'];
    if (traits is List && traits.isNotEmpty) {
      out.addAll(traits.take(6).map((e) => e.toString()));
    }
    if (out.isEmpty) {
      final r = _read('religion');
      if (r.isNotEmpty) out.add(r);
      final p = _read('profession');
      if (p.isEmpty) {
        final occ = _read('occupation');
        if (occ.isNotEmpty) out.add(occ);
      } else {
        out.add(p);
      }
    }
    return out;
  }

  /// Verified only when admin has approved the ID.
  bool get _isVerified =>
      widget.profile['isVerified'] == true ||
      widget.profile['idVerified'] == true ||
      widget.profile['profileVerified'] == true ||
      widget.profile['verificationStatus']?.toString().toLowerCase() ==
          'approved';

  @override
  Widget build(BuildContext context) {
    // ── Guard: show a placeholder instead of crashing for deleted accounts ──
    if (DeletedUserHelper.isDeleted(widget.profile)) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0A0A),
          iconTheme: const IconThemeData(color: AppColors.goldMedium),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_off_outlined,
                color: Colors.white24,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Account Deleted',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This user has deleted their account\nand is no longer available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.goldMedium,
                  side: const BorderSide(color: AppColors.goldMedium),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final uid = _read('uid');
    final name = _read('name', fallback: 'Member');
    final age = _age();
    final location = _location();
    final bio = _read(
      'bio',
      fallback: _read('shortBio', fallback: _read('aboutMe')),
    );
    final values = _values();
    final intent = _read('lookingFor', fallback: _read('goal'));
    final photos = _photos();
    final hidePhotos = ProfileVisibilityHelper.shouldHidePhotos(widget.profile);
    final religion = _read('religion');
    final education = _read(
      'educationLevel',
      fallback: _read('educationDegree'),
    );
    final profession = _read('profession', fallback: _read('occupation'));
    final maritalStatus = _read('maritalStatus');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      // ─── Floating Connect Button ───
      bottomNavigationBar: StreamBuilder<Set<String>>(
        stream: _pendingStream,
        builder: (context, pendingSnap) {
          return StreamBuilder<Set<String>>(
            stream: _acceptedStream,
            builder: (context, acceptedSnap) {
              final pendingIds = pendingSnap.data ?? const <String>{};
              final acceptedIds = acceptedSnap.data ?? const <String>{};
              final isPending = pendingIds.contains(uid);
              final isAccepted = acceptedIds.contains(uid);

              return _ConnectBar(
                uid: uid,
                isPending: isPending,
                isAccepted: isAccepted,
                isSending: _isSending,
                userName: name,
                onConnect: () async {
                  if (uid.isEmpty ||
                      isPending ||
                      isAccepted ||
                      _isSending ||
                      _connectInFlight) {
                    return;
                  }
                  _connectInFlight = true;
                  HapticFeedback.mediumImpact();
                  setState(() => _isSending = true);
                  try {
                    final result = await InterestService.instance.sendInterest(
                      toUserId: uid,
                    );
                    if (!mounted) return;
                    if (result == InterestSendResult.trialLimitReached) {
                      _showUpgradeSheet(context);
                      return;
                    }
                    final sent = result == InterestSendResult.sent ||
                        result == InterestSendResult.pending ||
                        result == InterestSendResult.alreadyAccepted;
                    if (!sent) return;

                    if (widget.popOnInterestSent) {
                      if (mounted) Navigator.pop(context, true);
                    } else {
                      showLinearMessage(
                        context,
                        result == InterestSendResult.pending
                            ? 'Interest already pending'
                            : result == InterestSendResult.alreadyAccepted
                            ? 'Already connected! You can message now.'
                            : 'Interest sent! 💛',
                      );
                    }
                  } finally {
                    _connectInFlight = false;
                    if (mounted) setState(() => _isSending = false);
                  }
                },
                onChat: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatConversationPage(
                        otherUserId: uid,
                        otherUserName: name,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      body: CustomScrollView(
        slivers: [
          // ─── Full-width photo hero ───
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Full-width image — no cropping, entire image visible
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: hidePhotos
                      ? ProfileVisibilityHelper.hiddenPhotoPlaceholder(
                          iconSize: 64,
                        )
                      : photos.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photos.first,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (_, __) => Container(
                            color: const Color(0xFF111111),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.goldMedium,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => _noPhoto(),
                        )
                      : _noPhoto(),
                ),

                // Top gradient (for back button readability)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.65),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom gradient (fades into page background)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 200,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color(0xFF0A0A0A),
                          const Color(0xFF0A0A0A).withOpacity(0.7),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),

                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.goldMedium,
                        size: 18,
                      ),
                    ),
                  ),
                ),

                // More options
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 12,
                  child: PopupMenuButton<String>(
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                    color: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (val) async {
                      if (val == 'ignore') {
                        await UserService.instance.ignoreUser(uid);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        showLinearMessage(context, 'Profile hidden for 2 days');
                      } else if (val == 'block') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1A1A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Text(
                              'Block Profile',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'Are you sure you want to block this profile?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Block',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await UserService.instance.blockUser(uid);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          showLinearMessage(context, 'Profile blocked');
                        }
                      } else if (val == 'report') {
                        final reasonController = TextEditingController();
                        String selectedCategory = '';
                        final categories = [
                          {'label': '🚨 Harassment / Threats', 'value': 'harassment'},
                          {'label': '👤 Fake Profile / Catfish', 'value': 'fake_profile'},
                          {'label': '💰 Scam / Fraud', 'value': 'scam'},
                          {'label': '🔞 Inappropriate Content', 'value': 'inappropriate'},
                          {'label': '👶 Underage User', 'value': 'underage'},
                          {'label': '📩 Spam / Solicitation', 'value': 'spam'},
                          {'label': '📋 Other', 'value': 'other'},
                        ];
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => StatefulBuilder(
                            builder: (ctx, setDialogState) => AlertDialog(
                              backgroundColor: const Color(0xFF1A1A1A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: const Text(
                                'Report Profile',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Report this profile for abuse? They will be permanently blocked and will never appear in your feed or connections again.',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Select a category:',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: categories.map((cat) {
                                        final isSelected = selectedCategory == cat['value'];
                                        return GestureDetector(
                                          onTap: () {
                                            setDialogState(() {
                                              selectedCategory = cat['value']!;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.redAccent.withOpacity(0.15)
                                                  : Colors.white.withOpacity(0.06),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isSelected
                                                    ? Colors.redAccent
                                                    : Colors.white.withOpacity(0.12),
                                                width: isSelected ? 1.5 : 1,
                                              ),
                                            ),
                                            child: Text(
                                              cat['label']!,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.redAccent
                                                    : Colors.white70,
                                                fontSize: 12,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Additional details (required):',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: reasonController,
                                      maxLines: 3,
                                      maxLength: 500,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Please describe the issue...',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 14,
                                        ),
                                        counterText: '',
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.06),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.white.withOpacity(0.1),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.white.withOpacity(0.1),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                        contentPadding: const EdgeInsets.all(12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Report',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        final reason = reasonController.text.trim();
                        final shouldReport = confirm == true;
                        final chosenCategory = selectedCategory;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          reasonController.dispose();
                        });
                        if (shouldReport) {
                          if (chosenCategory.isEmpty) {
                            if (!context.mounted) return;
                            showLinearMessage(
                              context,
                              'Please select a report category.',
                              isError: true,
                            );
                            return;
                          }
                          if (reason.isEmpty) {
                            if (!context.mounted) return;
                            showLinearMessage(
                              context,
                              'You must provide a reason to report someone.',
                              isError: true,
                            );
                            return;
                          }
                          try {
                            await UserService.instance.reportUser(
                              uid,
                              reason: reason,
                              category: chosenCategory,
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            showLinearMessage(
                              context,
                              'Profile reported and permanently blocked',
                            );
                          } catch (e) {
                            debugPrint('Report user error: $e');
                            if (!context.mounted) return;
                            String errorMessage = 'Could not submit report. Please try again.';
                            if (e is FirebaseFunctionsException) {
                              errorMessage = e.message ?? errorMessage;
                            } else if (e is FirebaseException) {
                              errorMessage = e.message ?? errorMessage;
                            } else {
                              errorMessage = e.toString();
                            }
                            showLinearMessage(
                              context,
                              errorMessage,
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'ignore',
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility_off_outlined,
                              color: Colors.white54,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Ignore Match',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(
                              Icons.block,
                              color: Colors.orangeAccent,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Block Match',
                              style: TextStyle(color: Colors.orangeAccent),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Report Profile',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Name + age + location overlaid at bottom
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                          if (_isVerified) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.verified,
                              color: AppColors.goldMedium,
                              size: 22,
                            ),
                          ],
                          if ((widget.profile['uid'] ==
                                  UserService.instance.currentUid) &&
                              UserService.instance.isPremium(
                                widget.profile,
                              )) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFD4A017),
                                    Color(0xFFC8960C),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: Colors.black,
                                    size: 12,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'PREMIUM',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: AppColors.goldMedium.withOpacity(0.85),
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              location,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 14,
                                shadows: const [
                                  Shadow(blurRadius: 6, color: Colors.black45),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Content sections ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // About Me
                  if (bio.isNotEmpty) ...[
                    _sectionTitle('About Me'),
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Values
                  if (values.isNotEmpty) ...[
                    _sectionTitle('Values'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: values
                          .map(
                            (v) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.14),
                                ),
                              ),
                              child: Text(
                                v,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Intent
                  if (intent.isNotEmpty) ...[
                    _sectionTitle('Intent'),
                    const SizedBox(height: 8),
                    Text(
                      'Looking for ${intent.toLowerCase()}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Details
                  if (_hasDetails()) ...[
                    _sectionTitle('Details'),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Religion', value: religion),
                    _DetailRow(label: 'Education', value: education),
                    _DetailRow(label: 'Profession', value: profession),
                    _DetailRow(label: 'Marital Status', value: maritalStatus),
                    const SizedBox(height: 28),
                  ],

                  // Photo gallery
                  if (!hidePhotos && photos.length > 1) ...[
                    _sectionTitle('Photos'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: photos[i],
                            width: 140,
                            height: 180,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 140,
                              color: const Color(0xFF1A1A1A),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 140,
                              color: const Color(0xFF1A1A1A),
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Bottom spacer so content isn't hidden behind FAB bar
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasDetails() {
    return _read('religion').isNotEmpty ||
        _read(
          'educationLevel',
          fallback: _read('educationDegree'),
        ).isNotEmpty ||
        _read('profession', fallback: _read('occupation')).isNotEmpty ||
        _read('maritalStatus').isNotEmpty;
  }

  Widget _noPhoto() => Container(
    color: const Color(0xFF111111),
    child: const Center(
      child: Icon(Icons.person, color: Colors.white12, size: 80),
    ),
  );

  void _showUpgradeSheet(BuildContext context) {
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
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
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
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You\'ve used all your free connections for today.\n'
              'Upgrade to Premium for unlimited interests and messaging.',
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
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
}

// ─── Floating Connect Bar ────────────────────────────────────────────────────

class _ConnectBar extends StatelessWidget {
  final String uid;
  final bool isPending;
  final bool isAccepted;
  final bool isSending;
  final String userName;
  final VoidCallback onConnect;
  final VoidCallback onChat;

  const _ConnectBar({
    required this.uid,
    required this.isPending,
    required this.isAccepted,
    required this.isSending,
    required this.userName,
    required this.onConnect,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: isAccepted
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Accepted: disabled greyed button + Chat CTA
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: null, // disabled
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Accepted'),
                    style: ElevatedButton.styleFrom(
                      disabledBackgroundColor: Colors.white.withOpacity(0.06),
                      disabledForegroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onChat,
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                    ),
                    label: Text('Continue with $userName'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldMedium,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: isPending
                  ? ElevatedButton.icon(
                      onPressed: null, // pending — disabled
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: const Text('Interest Sent'),
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: Colors.white.withOpacity(0.06),
                        disabledForegroundColor: Colors.white38,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                    )
                  : ElevatedButton(
                      onPressed: isSending ? null : onConnect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldMedium,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: isSending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Connect',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
            ),
    );
  }
}

// ─── Section Title ────────────────────────────────────────────────────────────

Widget _sectionTitle(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 0),
  child: Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.1,
    ),
  ),
);

// ─── Detail row ───────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
