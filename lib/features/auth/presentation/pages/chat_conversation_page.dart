import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/constants/colors.dart';
import '../../../../models/message_model.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/chat_presence_service.dart';
import '../../../../services/subscription_limits_service.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/linear_message.dart';
import '../../../../shared/helpers/deleted_user_helper.dart';
import '../../../../shared/widgets/deleted_user_avatar.dart';
import '../../../../shared/helpers/profile_visibility_helper.dart';
import 'match_profile_detail_page.dart';
import 'subscription_page.dart';

class ChatConversationPage extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatConversationPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  bool _chatRestricted = false;
  String? _chatRestrictionReason;
  Map<String, dynamic>? _otherUserProfile;

  // ─── STREAM CACHED IN STATE ───
  late final Stream<List<MessageModel>> _messageStream;

  // ─── Real-time presence stream ───
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _presenceStream;

  @override
  void initState() {
    super.initState();
    ChatPresenceService.instance.enterChat(widget.otherUserId);
    _messageStream = ChatService.instance.watchMessages(widget.otherUserId);
    // Real-time presence (isOnline field in the user doc)
    _presenceStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUserId)
        .snapshots();
    _loadOtherUserProfile();
    _loadChatAccess();
  }

  Future<void> _loadChatAccess() async {
    final check = await SubscriptionLimitsService.instance.canOpenChat(
      widget.otherUserId,
    );
    if (!mounted) return;
    setState(() {
      _chatRestricted = !check.allowed;
      _chatRestrictionReason = check.reason;
    });
  }

  Future<void> _loadOtherUserProfile() async {
    final profile = await UserService.instance.getUserProfile(
      widget.otherUserId,
    );
    if (mounted) {
      setState(() {
        _otherUserProfile = profile;
      });
    }
  }

  String? _getProfileImageUrl() {
    if (_otherUserProfile == null) return null;
    // Return null for deleted users so placeholder is shown
    if (DeletedUserHelper.isDeleted(_otherUserProfile)) return null;
    if (ProfileVisibilityHelper.shouldHidePhotos(_otherUserProfile!)) {
      return null;
    }
    String photoUrl = (_otherUserProfile!['photoUrl'] ?? '').toString();
    if (photoUrl.isEmpty &&
        _otherUserProfile!['photos'] is List &&
        (_otherUserProfile!['photos'] as List).isNotEmpty) {
      photoUrl = (_otherUserProfile!['photos'] as List).first.toString();
    }
    return photoUrl.isEmpty ? null : photoUrl;
  }

  bool get _isOtherUserDeleted =>
      DeletedUserHelper.isDeleted(_otherUserProfile);

  @override
  void dispose() {
    ChatPresenceService.instance.leaveChat();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final sent = await ChatService.instance.sendMessage(
        receiverId: widget.otherUserId,
        text: text,
      );

      if (!sent && mounted) {
        final check = await SubscriptionLimitsService.instance.canSendMessageTo(
          widget.otherUserId,
        );
        if (!check.allowed) {
          showLinearMessage(
            context,
            check.reason ?? 'Messaging is not available on your plan.',
            isError: true,
          );
        } else {
          _showUpgradeSheet();
        }
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _openPartnerProfile() {
    if (_otherUserProfile == null) return;
    // Don't navigate to the profile of a deleted user
    if (_isOtherUserDeleted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchProfileDetailPage(profile: _otherUserProfile!),
      ),
    );
  }

  void _showBlockReportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
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
            const SizedBox(height: 20),
            // ── Block option ──
            ListTile(
              leading: const Icon(Icons.block, color: Colors.orangeAccent),
              title: const Text(
                'Block User',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Remove from chat & connections',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.onyx,
                    title: const Text(
                      'Block User?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'This user will be removed from your connections and chat. You can unblock them later.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Block',
                          style: TextStyle(color: Colors.orangeAccent),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await UserService.instance.blockUser(widget.otherUserId);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User blocked.')),
                    );
                  }
                }
              },
            ),
            const Divider(color: Colors.white12),
            // ── Report option ──
            ListTile(
              leading: const FaIcon(
                FontAwesomeIcons.flag,
                color: Colors.redAccent,
                size: 20,
              ),
              title: const Text(
                'Report User',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Report abuse — user is permanently blocked',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(context);
                final reasonController = TextEditingController();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.onyx,
                    title: const Text(
                      'Report User?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This user will be reported and permanently blocked. They will never appear in your connections or chat again, even if you try to unblock.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Reason for reporting:',
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
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Please describe the issue...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 14,
                            ),
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
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white54),
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
                );
                final reason = reasonController.text.trim();
                final shouldReport = confirm == true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  reasonController.dispose();
                });
                if (shouldReport && mounted) {
                  if (reason.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You must provide a reason to report someone.'),
                      ),
                    );
                    return;
                  }
                  try {
                    await UserService.instance.reportUser(
                      widget.otherUserId,
                      reason: reason,
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'User reported and permanently blocked.',
                        ),
                      ),
                    );
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not submit report. Please try again.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUpgradeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
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
              Icons.workspace_premium_rounded,
              color: AppColors.goldMedium,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Premium Feature',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Messaging is exclusive to Swan Match Premium members. '
              'Upgrade to start meaningful conversations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
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
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe later',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        toolbarHeight: 72,
        iconTheme: const IconThemeData(color: AppColors.goldMedium),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.commentSlash, size: 18),
            tooltip: 'Block / Report',
            onPressed: () => _showBlockReportSheet(),
          ),
        ],
        // ── Tapping the header navigates to the partner's profile ──
        title: GestureDetector(
          onTap: _openPartnerProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Hero(
                tag: 'chat_avatar_${widget.otherUserId}',
                child: DeletedUserAvatar(
                  photoUrl: _getProfileImageUrl(),
                  radius: 18,
                  isDeleted: _isOtherUserDeleted,
                  photosHidden: _otherUserProfile != null &&
                      ProfileVisibilityHelper.shouldHidePhotos(
                        _otherUserProfile!,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.otherUserName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Verified badge — admin must have approved the ID
                        if (_otherUserProfile?['isVerified'] == true ||
                            _otherUserProfile?['profileVerified'] == true ||
                            _otherUserProfile?['verificationStatus']
                                    ?.toString()
                                    .toLowerCase() ==
                                'approved') ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: AppColors.goldMedium,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _presenceStream,
                      builder: (context, presSnap) {
                        final data = presSnap.data?.data() ?? _otherUserProfile;
                        final bool isOnline =
                            data?['isOnline'] == true ||
                            data?['online'] == true;
                        return Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? Colors.greenAccent
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${isOnline ? 'Online' : 'Offline'} • Tap to view profile',
                              style: TextStyle(
                                color: AppColors.goldMedium.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Pure black background ──
          Positioned.fill(child: Container(color: Colors.black)),

          // ── Main content ──
          Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _messageStream,
                  builder: (context, snapshot) {
                    // Don't show a spinner — use whatever data we have.
                    final messages = snapshot.data ?? const <MessageModel>[];

                    if (messages.isEmpty &&
                        snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.goldMedium,
                          strokeWidth: 2,
                        ),
                      );
                    }

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              color: AppColors.goldMedium.withValues(
                                alpha: 0.3,
                              ),
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Start your conversation 👋',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == currentUid;
                        return _MessageBubble(msg: msg, isMe: isMe);
                      },
                    );
                  },
                ),
              ),

              // ── Input bar (hidden for deleted / restricted users) ──
              if (_chatRestricted && !_isOtherUserDeleted)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: BoxDecoration(
                    color: AppColors.obsidian,
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _chatRestrictionReason ??
                              'Messaging is not available on your plan.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _showUpgradeSheet,
                          child: const Text(
                            'Upgrade to Premium',
                            style: TextStyle(color: AppColors.goldMedium),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_isOtherUserDeleted)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: BoxDecoration(
                    color: AppColors.obsidian,
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.white30,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This account no longer exists. You cannot send new messages.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // ── Normal input bar ──
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    decoration: BoxDecoration(
                      color: AppColors.obsidian,
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Type a message…',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSending ? null : _send,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.goldMedium,
                              foregroundColor: AppColors.obsidian,
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero,
                            ),
                            child: _isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.obsidian,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;

  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.goldMedium : const Color(0xFF2A2A2A),
                border: Border.all(
                  color: isMe
                      ? AppColors.goldMedium
                      : Colors.white.withValues(alpha: 0.05),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: isMe ? AppColors.obsidian : Colors.white,
                      fontSize: 14.5,
                      fontWeight: isMe ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _hhmm(msg.sentAt),
                        style: TextStyle(
                          color: isMe
                              ? AppColors.obsidian.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        // Clock = pending; double-tick = delivered
                        Icon(
                          msg.hasPendingWrites
                              ? Icons.access_time_rounded
                              : Icons.done_all_rounded,
                          size: 12,
                          color: msg.hasPendingWrites
                              ? AppColors.obsidian.withValues(alpha: 0.4)
                              : AppColors.obsidian.withValues(alpha: 0.8),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _hhmm(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
