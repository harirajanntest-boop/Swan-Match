import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../models/message_model.dart';
import '../../../../services/chat_service.dart';

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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    await ChatService.instance.sendMessage(receiverId: widget.otherUserId, text: text);
    if (!mounted) return;
    _messageController.clear();
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: AppColors.obsidian,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.goldMedium),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.goldMedium.withOpacity(0.2),
              child: const Icon(Icons.person, color: AppColors.goldMedium, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.obsidian,
                    AppColors.obsidian.withOpacity(0.96),
                    AppColors.onyx.withOpacity(0.98),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.goldMedium.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.goldMedium.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: ChatService.instance.watchMessages(widget.otherUserId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.goldMedium),
                      );
                    }

                    final messages = snapshot.data ?? const <MessageModel>[];
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          'Start your conversation 👋',
                          style: TextStyle(color: Colors.white.withOpacity(0.6)),
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
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? AppColors.goldMedium.withOpacity(0.16)
                                        : Colors.white.withOpacity(0.06),
                                    border: Border.all(
                                      color: isMe
                                          ? AppColors.goldMedium.withOpacity(0.5)
                                          : Colors.white.withOpacity(0.08),
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.text,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _hhmm(msg.sentAt),
                                        style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
                        hintText: 'Type a message',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.obsidian),
                            )
                          : const Icon(Icons.send, size: 20),
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

  String _hhmm(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
