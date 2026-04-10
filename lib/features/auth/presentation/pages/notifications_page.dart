import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Interactions', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.1, 1.0, curve: Curves.easeOut)));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)));

    Future.delayed(const Duration(milliseconds: 50), () {
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
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.goldMedium, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white, fontFamily: 'serif', letterSpacing: 1, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Filter Pills ───
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: _filters.map((filter) {
                      bool isSelected = _selectedFilter == filter;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = filter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppColors.goldGradient : null,
                            color: isSelected ? null : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1)),
                            boxShadow: isSelected ? [BoxShadow(color: AppColors.goldDark.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                          ),
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? AppColors.obsidian : Colors.white.withOpacity(0.7),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ─── Section Header ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  "Recent Activity",
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),

              // ─── Notifications List ───
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseAuth.instance.currentUser == null
                      ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
                      : FirebaseFirestore.instance
                          .collection('notifications')
                          .where('toUserId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.goldMedium),
                      );
                    }

                    final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final notifications = docs
                        .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
                        .where((item) {
                          if (_selectedFilter == 'All') return true;
                          final type = (item['type'] ?? '').toString().toLowerCase();
                          if (_selectedFilter == 'Interactions') {
                            return type == 'interaction';
                          }
                          return type == 'urgent';
                        })
                        .toList()
                      ..sort((a, b) {
                        final aTs = a['createdAt'];
                        final bTs = b['createdAt'];
                        final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
                        final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
                        return bMs.compareTo(aMs);
                      });

                    if (notifications.isEmpty) {
                      return Center(
                        child: Text(
                          'No notifications yet.',
                          style: TextStyle(color: Colors.white.withOpacity(0.6)),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 40),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        final createdAt = item['createdAt'];
                        DateTime when = DateTime.now();
                        if (createdAt is Timestamp) {
                          when = createdAt.toDate();
                        }

                        return _NotificationTile(
                          item: {
                            'name': (item['name'] ?? item['title'] ?? 'System').toString(),
                            'action': (item['action'] ?? item['message'] ?? '').toString(),
                            'time': _timeAgo(when),
                            'isNew': item['isRead'] != true,
                            'isSystem': (item['isSystem'] ?? false) == true,
                          },
                          index: index,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = (diff.inDays / 7).floor();
    return '${weeks}w';
  }
}

// ─── Reusable Glass Notification Tile ───
class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;

  const _NotificationTile({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    bool isSystem = item["isSystem"] ?? false;
    bool isNew = item["isNew"] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isNew ? AppColors.goldMedium.withOpacity(0.05) : Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isNew ? AppColors.goldMedium.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Avatar ───
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSystem ? null : AppColors.goldGradient,
                    color: isSystem ? Colors.white.withOpacity(0.1) : null,
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.obsidian,
                    child: Icon(
                      isSystem ? Icons.campaign : Icons.person,
                      color: isSystem ? Colors.white70 : AppColors.goldMedium,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // ─── Content ───
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text Message
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 14, height: 1.4),
                          children: [
                            TextSpan(
                              text: "${item["name"]} ",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: item["action"],
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Action Button
                      if (!isSystem)
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.goldMedium.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.goldMedium.withOpacity(0.5)),
                            ),
                            child: const Text(
                              "View profile",
                              style: TextStyle(color: AppColors.goldMedium, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () {},
                          child: const Text(
                            "Upgrade Now >",
                            style: TextStyle(color: AppColors.goldMedium, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // ─── Time & Menu ───
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item["time"],
                      style: TextStyle(color: isNew ? AppColors.goldMedium : Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: isNew ? FontWeight.bold : FontWeight.normal),
                    ),
                    const SizedBox(height: 8),
                    Icon(Icons.more_horiz, color: Colors.white.withOpacity(0.3), size: 18),
                    if (isNew) ...[
                      const SizedBox(height: 8),
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}