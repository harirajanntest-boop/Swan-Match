import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../shared/helpers/deleted_user_helper.dart';
import '../../../../shared/helpers/profile_visibility_helper.dart';
import '../../../../shared/widgets/deleted_user_avatar.dart';
import 'chat_conversation_page.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/interest_service.dart';
import '../../../../services/subscription_limits_service.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/linear_message.dart';

class MessagesView extends StatefulWidget {
  const MessagesView({super.key});

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ─── Animation ────────────────────────────────────────────────────────────
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;

  // ─── STREAMS CACHED IN STATE ───
  late final Stream<List<Map<String, dynamic>>> _myChatsStream;
  late final Stream<List<dynamic>> _mySentInterestsStream;
  late final Stream<List<dynamic>> _interestsForMeStream;
  late final Stream<Map<String, dynamic>?> _myProfileStream;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

    _myChatsStream = ChatService.instance.watchMyChats();
    _mySentInterestsStream = InterestService.instance.watchMySentInterests();
    _interestsForMeStream = InterestService.instance.watchInterestsForMe();
    _myProfileStream = UserService.instance.watchCurrentUserProfile();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ───
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                "Messages",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _myChatsStream,
                builder: (context, chatsSnapshot) {
                  if (chatsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.goldMedium,
                      ),
                    );
                  }
                  final chats =
                      chatsSnapshot.data ?? const <Map<String, dynamic>>[];
                  return StreamBuilder<List<dynamic>>(
                    stream: _mySentInterestsStream,
                    builder: (context, sentSnapshot) {
                      if (sentSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.goldMedium,
                          ),
                        );
                      }
                      return StreamBuilder<List<dynamic>>(
                        stream: _interestsForMeStream,
                        builder: (context, receivedSnapshot) {
                          if (receivedSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.goldMedium,
                              ),
                            );
                          }
                          final sent = sentSnapshot.data ?? const <dynamic>[];
                          final received =
                              receivedSnapshot.data ?? const <dynamic>[];

                          return StreamBuilder<Map<String, dynamic>?>(
                            stream: _myProfileStream,
                            builder: (context, profileSnap) {
                              final myProfile =
                                  profileSnap.data ?? const <String, dynamic>{};
                              final blockedUids = Set<String>.from(
                                myProfile['blockedUids'] ?? [],
                              );
                              final reportedUids = Set<String>.from(
                                myProfile['reportedUids'] ?? [],
                              );
                              final hiddenUids = {
                                ...blockedUids,
                                ...reportedUids,
                              };
                              final mergedChats = _mergeAcceptedInterests(
                                chats,
                                sent,
                                received,
                                hiddenUids,
                              );

                              return _buildMessageContent(
                                context,
                                title: "Messages",
                                emptyMessage: "No conversations yet.",
                                emptySub:
                                    "Accept an interest or get connected to start chatting.",
                                icon: Icons.chat_bubble_outline,
                                chats: mergedChats,
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
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _mergeAcceptedInterests(
    List<Map<String, dynamic>> chats,
    List<dynamic> sent,
    List<dynamic> received,
    Set<String> hiddenUids,
  ) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty) return chats;

    final disconnectedUserIds = <String>{};
    for (final item in [...sent, ...received]) {
      final status = (item.status ?? '').toString().toLowerCase();
      if (status == 'blocked') {
        final toUid = (item.toUserId ?? '').toString();
        final fromUid = (item.fromUserId ?? '').toString();
        if (toUid.isNotEmpty && toUid != currentUid)
          disconnectedUserIds.add(toUid);
        if (fromUid.isNotEmpty && fromUid != currentUid)
          disconnectedUserIds.add(fromUid);
      }
    }

    final validChats = chats.where((chat) {
      final participants =
          (chat['participants'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList();
      for (final uid in participants) {
        if (uid != currentUid &&
            uid.isNotEmpty &&
            disconnectedUserIds.contains(uid)) {
          return false;
        }
      }
      return true;
    }).toList();

    final existingUserIds = <String>{};
    for (final chat in validChats) {
      final participants =
          (chat['participants'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList();
      for (final uid in participants) {
        if (uid != currentUid && uid.isNotEmpty) {
          existingUserIds.add(uid);
        }
      }
    }

    final acceptedUserIds = <String>{};
    for (final item in sent) {
      final status = (item.status ?? '').toString().toLowerCase();
      if (status == 'accepted' || status == 'replied') {
        final toUserId = (item.toUserId ?? '').toString();
        if (toUserId.isNotEmpty && !hiddenUids.contains(toUserId)) {
          acceptedUserIds.add(toUserId);
        }
      }
    }
    for (final item in received) {
      final status = (item.status ?? '').toString().toLowerCase();
      if (status == 'accepted' || status == 'replied') {
        final fromUserId = (item.fromUserId ?? '').toString();
        if (fromUserId.isNotEmpty && !hiddenUids.contains(fromUserId)) {
          acceptedUserIds.add(fromUserId);
        }
      }
    }
    final merged = List<Map<String, dynamic>>.from(validChats);
    for (final userId in acceptedUserIds) {
      if (existingUserIds.contains(userId)) continue;
      merged.add(<String, dynamic>{
        'participants': <String>[currentUid, userId],
        'lastMessage': 'Interest accepted. Start your chat.',
        'lastMessageSenderId': userId,
      });
    }
    return merged;
  }

  // ─── Helper: Content Area Builder ───
  Widget _buildMessageContent(
    BuildContext context, {
    required String title,
    required String emptyMessage,
    required String emptySub,
    required IconData icon,
    required List<Map<String, dynamic>> chats,
  }) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final filteredChats = chats.where((chat) {
      if (_searchQuery.isEmpty) return true;
      final lastMessage = (chat['lastMessage'] ?? '').toString().toLowerCase();
      final participants =
          (chat['participants'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString().toLowerCase())
              .join(' ');
      return lastMessage.contains(_searchQuery) ||
          participants.contains(_searchQuery);
    }).toList();

    // De-duplicate by other user ID (in case chat doc + synthetic entry both exist)
    final seen = <String>{};
    final deduped = filteredChats.where((chat) {
      final participants =
          (chat['participants'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e.toString())
              .toList();
      final otherId = participants.firstWhere(
        (uid) => uid != currentUid,
        orElse: () => '',
      );
      if (otherId.isEmpty) return true;
      return seen.add(otherId);
    }).toList();

    return Column(
      children: [
        // ─── Search Bar ───
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            onChanged: (value) =>
                setState(() => _searchQuery = value.trim().toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search messages, user id or text',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.white.withOpacity(0.7),
              ),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: deduped.isEmpty
              ? Center(
                  child: _MessageEmptyState(
                    icon: icon,
                    message: emptyMessage,
                    subMessage: emptySub,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: deduped.length,
                  itemBuilder: (context, index) {
                    final chat = deduped[index];
                    final participants =
                        (chat['participants'] as List<dynamic>? ??
                                const <dynamic>[])
                            .map((item) => item.toString())
                            .toList();
                    final otherUserId = participants.firstWhere(
                      (uid) => uid != currentUid,
                      orElse: () => '',
                    );
                    return _ChatThreadTile(
                      chat: chat,
                      otherUserId: otherUserId,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ChatThreadTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final String otherUserId;

  const _ChatThreadTile({required this.chat, required this.otherUserId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: otherUserId.isEmpty
          ? Future.value(null)
          : UserService.instance.getUserProfile(otherUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.goldMedium,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Loading chat...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        final profile = snapshot.data ?? const <String, dynamic>{};
        final isDeletedUser = DeletedUserHelper.isDeleted(
          snapshot.data == null ? null : profile,
        );
        final name = isDeletedUser
            ? 'Deleted Account'
            : (profile['name'] ?? 'Member').toString();
        final city = isDeletedUser
            ? 'This account no longer exists'
            : (profile['city'] ?? '').toString();
        final lastMessage = (chat['lastMessage'] ?? '').toString();

        return _buildChatTile(
          context,
          profile,
          name,
          city,
          lastMessage,
          otherUserId,
          isDeletedUser,
        );
      },
    );
  }

  Widget _buildChatTile(
    BuildContext context,
    Map<String, dynamic> profile,
    String name,
    String city,
    String lastMessage,
    String otherUserId,
    bool isDeletedUser,
  ) {
    // Get photo URL from either photoUrl field or photos array
    String photoUrl = (profile['photoUrl'] ?? '').toString();
    if (photoUrl.isEmpty &&
        profile['photos'] is List &&
        (profile['photos'] as List).isNotEmpty) {
      photoUrl = (profile['photos'] as List).first.toString();
    }

    Future<void> openConversation() async {
      if (otherUserId.isEmpty) {
        showLinearMessage(context, 'Chat user unavailable.', isError: true);
        return;
      }
      // Prevent opening chat for deleted users
      if (isDeletedUser) {
        showLinearMessage(
          context,
          'This account no longer exists.',
          isError: true,
        );
        return;
      }
      final chatCheck = await SubscriptionLimitsService.instance.canOpenChat(
        otherUserId,
      );
      if (!chatCheck.allowed) {
        if (!context.mounted) return;
        showLinearMessage(
          context,
          chatCheck.reason ??
              'Someone messaged you! Upgrade to Premium to reply.',
          isError: true,
        );
        return;
      }
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationPage(
            otherUserId: otherUserId,
            otherUserName: name,
          ),
        ),
      );
    }

    return InkWell(
      onTap: openConversation,
      onLongPress: () async {
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (otherUserId.isEmpty || currentUid.isEmpty) {
          showLinearMessage(
            context,
            'Unable to delete conversation.',
            isError: true,
          );
          return;
        }

        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete conversation'),
            content: const Text(
              'Permanently delete this conversation? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );

        if (!context.mounted) return;

        if (confirm == true) {
          try {
            await ChatService.instance.deleteChatThreadBetween(
              currentUid,
              otherUserId,
            );
            if (!context.mounted) return;
            showLinearMessage(context, 'Conversation deleted.');
          } catch (e) {
            if (!context.mounted) return;
            showLinearMessage(
              context,
              'Failed to delete conversation.',
              isError: true,
            );
          }
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 16.0,
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    DeletedUserAvatar(
                      photoUrl: DeletedUserHelper.getAvatarUrl(profile),
                      radius: 26,
                      isDeleted: isDeletedUser,
                      photosHidden:
                          ProfileVisibilityHelper.shouldHidePhotos(profile),
                    ),
                    if (!isDeletedUser &&
                        (profile['isOnline'] == true ||
                            profile['online'] == true))
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Verified badge — admin must have approved the ID
                          if (profile['isVerified'] == true ||
                              profile['profileVerified'] == true ||
                              profile['verificationStatus']
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
                      const SizedBox(height: 4),
                      Text(
                        lastMessage.isEmpty ? city : lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
        ],
      ),
    );
  }
}

// ─── Reusable Glassmorphic Empty State for Messages ───
class _MessageEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subMessage;

  const _MessageEmptyState({
    required this.icon,
    required this.message,
    required this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            subMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
