import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../shared/helpers/deleted_user_helper.dart';
import '../../../../shared/helpers/profile_visibility_helper.dart';
import '../../../../shared/widgets/deleted_user_avatar.dart';
import 'chat_conversation_page.dart';
import 'connection_request_detail_page.dart';
import 'match_profile_detail_page.dart';
import '../../../../models/connection_model.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/connection_service.dart';
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
  late final Stream<List<ConnectionModel>> _receivedConnectionsStream;
  late final Stream<List<ConnectionModel>> _sentConnectionsStream;
  late final Stream<List<ConnectionModel>> _acceptedConnectionsStream;
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
    _receivedConnectionsStream =
        ConnectionService.instance.watchReceivedConnections();
    _sentConnectionsStream = ConnectionService.instance.watchSentConnections();
    _acceptedConnectionsStream =
        ConnectionService.instance.watchAcceptedConnections();
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

  bool _isInitialLoad(AsyncSnapshot<dynamic> snap) {
    return snap.connectionState == ConnectionState.waiting && !snap.hasData;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SafeArea(
        child: DefaultTabController(
          length: 3,
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

              TabBar(
                indicatorColor: AppColors.goldMedium,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Requests'),
                  Tab(text: 'Connections'),
                  Tab(text: 'Chats'),
                ],
              ),

              Expanded(
                child: TabBarView(
                  // Switch tabs only by tapping Requests / Connections /
                  // Chats — no horizontal swipe between them.
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildRequestsTab(context),
                    _buildConnectionsTab(context),
                    _buildChatsTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tab 1: Requests (Received + Sent connection requests) ───
  Widget _buildRequestsTab(BuildContext context) {
    return StreamBuilder<List<ConnectionModel>>(
      stream: _receivedConnectionsStream,
      builder: (context, receivedSnapshot) {
        if (_isInitialLoad(receivedSnapshot)) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.goldMedium),
          );
        }
        final receivedAll =
            receivedSnapshot.data ?? const <ConnectionModel>[];
        final receivedPending = receivedAll
            .where((c) => c.status.toLowerCase() == 'pending')
            .toList();

        return StreamBuilder<List<ConnectionModel>>(
          stream: _sentConnectionsStream,
          builder: (context, sentSnapshot) {
            final sentAll = sentSnapshot.data ?? const <ConnectionModel>[];
            return StreamBuilder<Map<String, dynamic>?>(
              stream: _myProfileStream,
              builder: (context, profileSnap) {
                // People I blocked or reported don't show up here either (same
                // as Connections and Chats).
                final myProfile = profileSnap.data ?? const <String, dynamic>{};
                final hiddenUids = {
                  ...Set<String>.from(myProfile['blockedUids'] ?? []),
                  ...Set<String>.from(myProfile['reportedUids'] ?? []),
                };
                final received = receivedPending
                    .where((c) => !hiddenUids.contains(c.senderId))
                    .toList();
                final sent = sentAll.where((c) {
                  final status = c.status.toLowerCase();
                  return (status == 'pending' || status == 'expired') &&
                      !hiddenUids.contains(c.receiverId);
                }).toList();

                if (received.isEmpty && sent.isEmpty) {
                  return const Center(
                    child: _MessageEmptyState(
                      icon: Icons.forum_outlined,
                      message: "No requests yet",
                      subMessage:
                          "Connection requests you send or receive will show up here.",
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  children: [
                    if (received.isNotEmpty) ...[
                      _sectionLabel('Received'),
                      ...received.map(
                        (c) => _ReceivedRequestTile(connection: c),
                      ),
                    ],
                    if (sent.isNotEmpty) ...[
                      SizedBox(height: received.isNotEmpty ? 20 : 0),
                      _sectionLabel('Sent'),
                      ...sent.map((c) => _SentRequestTile(connection: c)),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.45),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // ─── Tab 2: Connections (all accepted connections) ───
  Widget _buildConnectionsTab(BuildContext context) {
    return StreamBuilder<List<ConnectionModel>>(
      stream: _acceptedConnectionsStream,
      builder: (context, acceptedSnapshot) {
        if (_isInitialLoad(acceptedSnapshot)) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.goldMedium),
          );
        }
        final accepted = acceptedSnapshot.data ?? const <ConnectionModel>[];

        return StreamBuilder<Map<String, dynamic>?>(
          stream: _myProfileStream,
          builder: (context, profileSnap) {
            final myProfile = profileSnap.data ?? const <String, dynamic>{};
            final blockedUids = Set<String>.from(
              myProfile['blockedUids'] ?? [],
            );
            final reportedUids = Set<String>.from(
              myProfile['reportedUids'] ?? [],
            );
            final hiddenUids = {...blockedUids, ...reportedUids};

            final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
            final connections = accepted.where((c) {
              final otherUserId = c.senderId == currentUid
                  ? c.receiverId
                  : c.senderId;
              if (otherUserId.isEmpty || otherUserId == currentUid) {
                return false;
              }
              return !hiddenUids.contains(otherUserId);
            }).toList();

            if (connections.isEmpty) {
              return const Center(
                child: _MessageEmptyState(
                  icon: Icons.people_alt_outlined,
                  message: "No connections yet",
                  subMessage:
                      "Accepted connections will show up here so you can view profiles and manage them.",
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              itemCount: connections.length,
              itemBuilder: (context, index) {
                final connection = connections[index];
                final otherUserId = connection.senderId == currentUid
                    ? connection.receiverId
                    : connection.senderId;
                return _ConnectionTile(
                  connection: connection,
                  otherUserId: otherUserId,
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Tab 3: Chats (real chats + accepted connections) ───
  Widget _buildChatsTab(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _myChatsStream,
      builder: (context, chatsSnapshot) {
        if (_isInitialLoad(chatsSnapshot)) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.goldMedium),
          );
        }
        final chats = chatsSnapshot.data ?? const <Map<String, dynamic>>[];
        return StreamBuilder<List<ConnectionModel>>(
          stream: _acceptedConnectionsStream,
          builder: (context, acceptedSnapshot) {
            final accepted =
                acceptedSnapshot.data ?? const <ConnectionModel>[];

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
                final hiddenUids = {...blockedUids, ...reportedUids};
                final mergedChats = _mergeAcceptedConnections(
                  chats,
                  accepted,
                  hiddenUids,
                );

                return _buildMessageContent(
                  context,
                  title: "Chats",
                  emptyMessage: "No conversations yet.",
                  emptySub:
                      "Accept a connection request to start chatting.",
                  icon: Icons.chat_bubble_outline,
                  chats: mergedChats,
                );
              },
            );
          },
        );
      },
    );
  }

  /// Adaptation of the old `_mergeAcceptedInterests`: synthesizes a
  /// placeholder "chat" entry for every accepted connection that doesn't yet
  /// have a real `chats` doc, so the user can tap straight into the
  /// conversation.
  List<Map<String, dynamic>> _mergeAcceptedConnections(
    List<Map<String, dynamic>> chats,
    List<ConnectionModel> acceptedConnections,
    Set<String> hiddenUids,
  ) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty) return chats;

    final existingUserIds = <String>{};
    for (final chat in chats) {
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

    final merged = List<Map<String, dynamic>>.from(chats);
    for (final connection in acceptedConnections) {
      final otherUserId = connection.senderId == currentUid
          ? connection.receiverId
          : connection.senderId;
      if (otherUserId.isEmpty || otherUserId == currentUid) continue;
      if (hiddenUids.contains(otherUserId)) continue;
      if (existingUserIds.contains(otherUserId)) continue;

      merged.add(<String, dynamic>{
        'participants': <String>[currentUid, otherUserId],
        'lastMessage': 'You are connected. Start your chat.',
        'lastMessageSenderId': otherUserId,
      });
      existingUserIds.add(otherUserId);
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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

// ─── Requests Tab: Received row ───
/// True when [profile] (another user) has blocked the current user. Their
/// doc carries their blockedUids, so this needs no extra reads — it covers
/// pairs blocked before blocking also ended the connection server-side.
bool _hasBlockedMe(Map<String, dynamic> profile) {
  final me = FirebaseAuth.instance.currentUser?.uid;
  final blocked = profile['blockedUids'];
  return me != null && blocked is List && blocked.contains(me);
}

class _ReceivedRequestTile extends StatelessWidget {
  final ConnectionModel connection;

  const _ReceivedRequestTile({required this.connection});

  String _photoFromProfile(Map<String, dynamic> profile) {
    final photos = profile['photos'] ?? profile['images'];
    if (photos is List && photos.isNotEmpty) {
      return photos.first.toString();
    }
    return (profile['profilePicture'] ?? profile['photoUrl'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: UserService.instance.watchUserProfile(connection.senderId),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? const <String, dynamic>{};
        // Someone who blocked me disappears from all my lists.
        if (_hasBlockedMe(profile)) return const SizedBox.shrink();
        final name =
            (profile['name'] ?? profile['firstName'] ?? 'Member').toString();
        final photoUrl = _photoFromProfile(profile);

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ConnectionRequestDetailPage(connection: connection),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white10,
                  backgroundImage:
                      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.white54)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        connection.topic.isEmpty
                            ? 'Sent you a connection request'
                            : connection.topic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.goldMedium,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.2),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Requests Tab: Sent row ───
class _SentRequestTile extends StatelessWidget {
  final ConnectionModel connection;

  const _SentRequestTile({required this.connection});

  String _photoFromProfile(Map<String, dynamic> profile) {
    final photos = profile['photos'] ?? profile['images'];
    if (photos is List && photos.isNotEmpty) {
      return photos.first.toString();
    }
    return (profile['profilePicture'] ?? profile['photoUrl'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: UserService.instance.watchUserProfile(connection.receiverId),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? const <String, dynamic>{};
        // Someone who blocked me disappears from all my lists.
        if (_hasBlockedMe(profile)) return const SizedBox.shrink();
        final name =
            (profile['name'] ?? profile['firstName'] ?? 'Member').toString();
        final photoUrl = _photoFromProfile(profile);
        final isExpired = connection.status.toLowerCase() == 'expired';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white10,
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white54)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (connection.topic.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        connection.topic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isExpired
                      ? Colors.white.withOpacity(0.08)
                      : AppColors.goldMedium.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isExpired
                        ? Colors.white24
                        : AppColors.goldMedium.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  isExpired ? 'Expired' : 'Waiting for response',
                  style: TextStyle(
                    color: isExpired ? Colors.white54 : AppColors.goldMedium,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatThreadTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final String otherUserId;

  const _ChatThreadTile({required this.chat, required this.otherUserId});

  String _photoFromProfile(Map<String, dynamic> profile) {
    final photos = profile['photos'] ?? profile['images'];
    if (photos is List && photos.isNotEmpty) {
      return photos.first.toString();
    }
    return (profile['profilePicture'] ?? profile['photoUrl'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    if (otherUserId.isEmpty) return const SizedBox.shrink();

    final lastMessage = (chat['lastMessage'] ?? '').toString();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: UserService.instance.watchUserProfile(otherUserId),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? const <String, dynamic>{};
        // Someone who blocked me disappears from all my lists.
        if (_hasBlockedMe(profile)) return const SizedBox.shrink();
        final isDeletedUser = DeletedUserHelper.isDeleted(
          snapshot.hasData ? profile : null,
        );
        final name = isDeletedUser
            ? 'Deleted Account'
            : (profile['name'] ?? profile['firstName'] ?? 'Member').toString();
        final city = isDeletedUser
            ? 'This account no longer exists'
            : (profile['city'] ?? '').toString();

        return _buildChatTile(
          context,
          profile,
          name,
          city,
          lastMessage,
          otherUserId,
          isDeletedUser,
          photoUrl: _photoFromProfile(profile),
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
    bool isDeletedUser, {
    String photoUrl = '',
  }) {
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
                  clipBehavior: Clip.none,
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
                              profile['idVerified'] == true ||
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
                          color:
                              lastMessage == 'You are connected. Start your chat.'
                                  ? AppColors.goldMedium
                                  : Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                          fontWeight:
                              lastMessage == 'You are connected. Start your chat.'
                                  ? FontWeight.w600
                                  : FontWeight.normal,
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

// ─── Connections Tab: accepted-connection row ───
class _ConnectionTile extends StatelessWidget {
  final ConnectionModel connection;
  final String otherUserId;

  const _ConnectionTile({required this.connection, required this.otherUserId});

  String _photoFromProfile(Map<String, dynamic> profile) {
    final photos = profile['photos'] ?? profile['images'];
    if (photos is List && photos.isNotEmpty) {
      return photos.first.toString();
    }
    return (profile['profilePicture'] ?? profile['photoUrl'] ?? '').toString();
  }

  static const List<Map<String, String>> _reportCategories = [
    {'label': '🚨 Harassment / Threats', 'value': 'harassment'},
    {'label': '👤 Fake Profile / Catfish', 'value': 'fake_profile'},
    {'label': '💰 Scam / Fraud', 'value': 'scam'},
    {'label': '🔞 Inappropriate Content', 'value': 'inappropriate'},
    {'label': '👶 Underage User', 'value': 'underage'},
    {'label': '📩 Spam / Solicitation', 'value': 'spam'},
    {'label': '📋 Other', 'value': 'other'},
  ];

  Future<void> _openProfile(
    BuildContext context,
    Map<String, dynamic> profile,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MatchProfileDetailPage(profile: profile)),
    );
  }

  Future<void> _showActionsSheet(
    BuildContext context,
    String name,
    Map<String, dynamic> profile,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.link_off_rounded,
                  color: AppColors.goldMedium,
                ),
                title: const Text(
                  'Disconnect',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDisconnect(context, name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.orangeAccent),
                title: const Text(
                  'Block',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmBlock(context, name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_rounded, color: Colors.redAccent),
                title: const Text(
                  'Report',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showReportDialog(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDisconnect(BuildContext context, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Disconnect', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to disconnect from $name? '
          'You can reconnect later by sending a new connection request.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('disconnectConnection')
          .call(<String, dynamic>{'connectionId': connection.id});
      if (!context.mounted) return;
      showLinearMessage(context, 'Disconnected from $name.');
    } catch (e) {
      if (!context.mounted) return;
      showLinearMessage(context, _readableError(e), isError: true);
    }
  }

  Future<void> _confirmBlock(BuildContext context, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Block Profile', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to block $name?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    try {
      await UserService.instance.blockUser(otherUserId);
      if (!context.mounted) return;
      showLinearMessage(context, 'Profile blocked');
    } catch (e) {
      if (!context.mounted) return;
      showLinearMessage(context, _readableError(e), isError: true);
    }
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final reasonController = TextEditingController();
    String selectedCategory = '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Report Profile', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report this connection for abuse? Our team will review it.',
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
                  children: _reportCategories.map((cat) {
                    final isSelected = selectedCategory == cat['value'];
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedCategory = cat['value']!;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            color: isSelected ? Colors.redAccent : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Please describe the issue...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent),
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
              child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Report', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );

    final reason = reasonController.text.trim();
    final chosenCategory = selectedCategory;
    reasonController.dispose();

    if (confirm != true) return;
    if (chosenCategory.isEmpty) {
      if (!context.mounted) return;
      showLinearMessage(context, 'Please select a report category.', isError: true);
      return;
    }
    if (reason.isEmpty) {
      if (!context.mounted) return;
      showLinearMessage(context, 'You must provide a reason to report.', isError: true);
      return;
    }

    try {
      await UserService.instance.reportUser(
        otherUserId,
        reason: reason,
        category: chosenCategory,
      );
      if (!context.mounted) return;
      showLinearMessage(context, 'Thanks — this profile has been reported.');
    } catch (e) {
      if (!context.mounted) return;
      showLinearMessage(context, _readableError(e), isError: true);
    }
  }

  String _readableError(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    if (otherUserId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: UserService.instance.watchUserProfile(otherUserId),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? const <String, dynamic>{};
        // Someone who blocked me disappears from all my lists.
        if (_hasBlockedMe(profile)) return const SizedBox.shrink();
        final isDeletedUser = DeletedUserHelper.isDeleted(
          snapshot.hasData ? profile : null,
        );
        final name = isDeletedUser
            ? 'Deleted Account'
            : (profile['name'] ?? profile['firstName'] ?? 'Member').toString();
        final photoUrl = _photoFromProfile(profile);
        final mergedProfile = <String, dynamic>{...profile, 'uid': otherUserId};

        return InkWell(
          onTap: () {
            if (isDeletedUser) {
              showLinearMessage(context, 'This account no longer exists.', isError: true);
              return;
            }
            _openProfile(context, mergedProfile);
          },
          onLongPress: isDeletedUser
              ? null
              : () => _showActionsSheet(context, name, mergedProfile),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                DeletedUserAvatar(
                  photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
                  radius: 26,
                  isDeleted: isDeletedUser,
                  photosHidden: ProfileVisibilityHelper.shouldHidePhotos(profile),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDeletedUser
                            ? 'This account no longer exists'
                            : 'Connected — view profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2)),
              ],
            ),
          ),
        );
      },
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
