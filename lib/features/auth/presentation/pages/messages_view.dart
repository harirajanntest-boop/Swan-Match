import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'chat_conversation_page.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/interest_service.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/linear_message.dart';

class MessagesView extends StatefulWidget {
  const MessagesView({super.key});

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _onlyUnread = false;

  // ─── STREAMS CACHED IN STATE ───
  late final Stream<List<Map<String, dynamic>>> _myChatsStream;
  late final Stream<List<dynamic>> _mySentInterestsStream;
  late final Stream<List<dynamic>> _interestsForMeStream;

  @override
  void initState() {
    super.initState();
    _myChatsStream = ChatService.instance.watchMyChats();
    _mySentInterestsStream = InterestService.instance.watchMySentInterests();
    _interestsForMeStream = InterestService.instance.watchInterestsForMe();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
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

            // ─── Main Tab Bar ───
            TabBar(
              dividerColor: Colors.white.withOpacity(0.05),
              indicatorColor: AppColors.goldMedium,
              indicatorWeight: 3,
              labelColor: AppColors.goldMedium,
              unselectedLabelColor: Colors.white.withOpacity(0.4),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
              tabs: const [
                Tab(text: "Messages"),
                Tab(text: "Calls"),
              ],
            ),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _myChatsStream,
                builder: (context, chatsSnapshot) {
                  if (chatsSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.goldMedium),
                    );
                  }
                  final chats = chatsSnapshot.data ?? const <Map<String, dynamic>>[];
                  return StreamBuilder<List<dynamic>>(
                    stream: _mySentInterestsStream,
                    builder: (context, sentSnapshot) {
                      if (sentSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.goldMedium),
                        );
                      }
                      return StreamBuilder<List<dynamic>>(
                        stream: _interestsForMeStream,
                        builder: (context, receivedSnapshot) {
                          if (receivedSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: AppColors.goldMedium),
                            );
                          }
                          final sent = sentSnapshot.data ?? const <dynamic>[];
                          final received = receivedSnapshot.data ?? const <dynamic>[];
                          final mergedChats = _mergeAcceptedInterests(chats, sent, received);

                          return TabBarView(
                            children: [
                              _buildMessageContent(
                                context,
                                title: "Incoming messages",
                                emptyMessage: "No messages received yet.",
                                emptySub: "When someone messages you, it will appear here.",
                                icon: Icons.chat_bubble_outline,
                                chats: mergedChats,
                                incomingOnly: true,
                              ),
                              _buildMessageContent(
                                context,
                                title: "Your recent call history",
                                emptyMessage: "No recent calls.",
                                emptySub: "Call history will appear here.",
                                icon: Icons.phone_in_talk_outlined,
                                chats: const <Map<String, dynamic>>[],
                                incomingOnly: true,
                              ),
                            ],
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
  ) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty) return chats;

    final existingUserIds = <String>{};
    for (final chat in chats) {
      final participants = (chat['participants'] as List<dynamic>? ?? const <dynamic>[])
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
        if (toUserId.isNotEmpty) acceptedUserIds.add(toUserId);
      }
    }
    for (final item in received) {
      final status = (item.status ?? '').toString().toLowerCase();
      if (status == 'accepted' || status == 'replied') {
        final fromUserId = (item.fromUserId ?? '').toString();
        if (fromUserId.isNotEmpty) acceptedUserIds.add(fromUserId);
      }
    }

    final merged = List<Map<String, dynamic>>.from(chats);
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
    required bool incomingOnly,
  }) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final filteredChats = chats.where((chat) {
      final lastSender = (chat['lastMessageSenderId'] ?? '').toString();
      if (currentUid.isEmpty || lastSender.isEmpty) return true;
      final directionMatches = incomingOnly ? lastSender != currentUid : lastSender == currentUid;
      if (!directionMatches) return false;
      if (_onlyUnread && !(lastSender != currentUid)) return false;

      if (_searchQuery.isEmpty) return true;
      final lastMessage = (chat['lastMessage'] ?? '').toString().toLowerCase();
      final participants = (chat['participants'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString().toLowerCase())
          .join(' ');
      return lastMessage.contains(_searchQuery) || participants.contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        // ─── Sub-Header & Actions ───
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
              const SizedBox(width: 12),
              // Action Buttons (Filter)
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _onlyUnread = !_onlyUnread),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _onlyUnread ? AppColors.goldMedium.withOpacity(0.16) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tune, color: Colors.white.withOpacity(0.8), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            _onlyUnread ? 'Unread only' : 'All',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search messages, user id or text',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
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
          child: filteredChats.isEmpty
              ? Center(
                  child: _MessageEmptyState(
                    icon: icon,
                    message: emptyMessage,
                    subMessage: emptySub,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];
                    final participants = (chat['participants'] as List<dynamic>? ?? const <dynamic>[])
                        .map((item) => item.toString())
                        .toList();
                    final otherUserId = participants.firstWhere(
                      (uid) => uid != currentUid,
                      orElse: () => '',
                    );
                    return _ChatThreadTile(chat: chat, otherUserId: otherUserId);
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
      future: otherUserId.isEmpty ? Future.value(null) : UserService.instance.getUserProfile(otherUserId),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.goldMedium),
                ),
                SizedBox(width: 12),
                Text('Loading chat...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          );
        }

        final profile = snapshot.data ?? const <String, dynamic>{};
        final name = (profile['name'] ?? 'Member').toString();
        final city = (profile['city'] ?? '').toString();
        final lastMessage = (chat['lastMessage'] ?? '').toString();

        Future<void> openConversation() async {
          if (otherUserId.isEmpty) {
            showLinearMessage(context, 'Chat user unavailable.', isError: true);
            return;
          }
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

        return GestureDetector(
          onTap: openConversation,
          child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.goldMedium.withOpacity(0.2),
                backgroundImage: (profile['showPhotosToEveryone'] != false && (profile['photoUrl'] ?? '').isNotEmpty)
                    ? NetworkImage(profile['photoUrl'])
                    : null,
                child: (profile['showPhotosToEveryone'] == false || (profile['photoUrl'] ?? '').isEmpty)
                    ? const Icon(Icons.person, color: AppColors.goldMedium)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: openConversation,
                      child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastMessage.isEmpty ? city : lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chat_bubble_outline, color: AppColors.goldMedium.withOpacity(0.9), size: 20),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.4)),
            ],
          ),
        ));
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
          // Glowing Glass Icon Ring
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.goldMedium.withOpacity(0.1), blurRadius: 40, spreadRadius: 10)],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.03),
                      border: Border.all(color: AppColors.goldMedium.withOpacity(0.2), width: 1.5),
                    ),
                    child: Center(
                      child: Icon(icon, color: AppColors.goldMedium, size: 32),
                    ),
                  ),
                ),
              ),
              // Floating Particles
              Positioned(top: -5, right: 5, child: Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.goldLight))),
              Positioned(bottom: 5, left: -5, child: Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.goldMedium.withOpacity(0.5)))),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            subMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}