import 'dart:ui';
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
          final blockedUids = List<String>.from(snapshot.data?['blockedUids'] ?? []);

          if (blockedUids.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  Text("No blocked profiles", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: blockedUids.length,
            itemBuilder: (context, index) {
              final uid = blockedUids[index];
              return FutureBuilder<Map<String, dynamic>?>(
                future: UserService.instance.getUserProfile(uid),
                builder: (context, userSnapshot) {
                  final profile = userSnapshot.data;
                  final name = profile?['name'] ?? 'Loading...';
                  final photoUrl = profile?['photoUrl'] ?? '';

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
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty ? const Icon(Icons.person, color: AppColors.goldMedium) : null,
                      ),
                      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Blocked", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () => UserService.instance.unblockUser(uid),
                        child: const Text("Unblock", style: TextStyle(color: AppColors.goldMedium)),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
