import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';

class BlockedProfilesPage extends StatelessWidget {
  const BlockedProfilesPage({super.key});

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
          "Blocked Profiles",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: UserService.instance.watchCurrentUserProfile(),
        builder: (context, snapshot) {
          final blockedUidsRaw = List<String>.from(snapshot.data?['blockedUids'] ?? []);
          final reportedUids = List<String>.from(snapshot.data?['reportedUids'] ?? []);

          final purelyBlockedUids = blockedUidsRaw.where((uid) => !reportedUids.contains(uid)).toList();
          final allReportedUids = reportedUids.toList();

          if (purelyBlockedUids.isEmpty && allReportedUids.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  Text("No blocked or reported profiles", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (purelyBlockedUids.isNotEmpty) ...[
                const Text("Blocked Users", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...purelyBlockedUids.map((uid) => _buildUserTile(uid, false)),
                const SizedBox(height: 24),
              ],
              if (allReportedUids.isNotEmpty) ...[
                const Text("Reported Users", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...allReportedUids.map((uid) => _buildUserTile(uid, true)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserTile(String uid, bool isReported) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserService.instance.getUserProfile(uid),
      builder: (context, userSnapshot) {
        final profile = userSnapshot.data;
        final name = profile?['firstName'] ?? profile?['name'] ?? 'Loading...';
        String photoUrl = profile?['profilePicture'] ?? '';
        if (photoUrl.isEmpty) {
          final photos = profile?['photos'] as List?;
          if (photos != null && photos.isNotEmpty) {
            photoUrl = photos.first.toString();
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColors.onyx,
              backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
              child: photoUrl.isEmpty ? const Icon(Icons.person, color: AppColors.goldMedium) : null,
            ),
            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              isReported ? "Reported & Permanently Blocked" : "Blocked", 
              style: TextStyle(color: isReported ? Colors.redAccent : Colors.white.withOpacity(0.6), fontSize: 12)
            ),
            trailing: isReported 
              ? const Text("Reported", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13))
              : TextButton(
                  onPressed: () => UserService.instance.unblockUser(uid),
                  child: const Text("Unblock", style: TextStyle(color: AppColors.goldMedium)),
                ),
          ),
        );
      },
    );
  }
}
