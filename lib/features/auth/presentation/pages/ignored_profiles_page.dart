import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';

class IgnoredProfilesPage extends StatelessWidget {
  const IgnoredProfilesPage({super.key});

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
          "Ignored Profiles",
          style: TextStyle(color: Colors.white, fontFamily: 'serif', fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: UserService.instance.watchCurrentUserProfile(),
        builder: (context, snapshot) {
          final ignoredMap = Map<String, dynamic>.from(snapshot.data?['ignoredProfiles'] ?? {});
          final now = DateTime.now();
          
          final activeIgnoredUids = ignoredMap.entries.where((e) {
            final expiry = (e.value as Timestamp).toDate();
            return expiry.isAfter(now);
          }).map((e) => e.key).toList();

          if (activeIgnoredUids.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_off, size: 64, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  Text("No ignored profiles", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: activeIgnoredUids.length,
            itemBuilder: (context, index) {
              final uid = activeIgnoredUids[index];
              final expiry = (ignoredMap[uid] as Timestamp).toDate();

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
                      subtitle: Text(
                        "Hidden until ${DateFormat('dd MMM, hh:mm a').format(expiry)}", 
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)
                      ),
                      trailing: TextButton(
                        onPressed: () => UserService.instance.unignoreUser(uid),
                        child: const Text("Show Now", style: TextStyle(color: AppColors.goldMedium)),
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
