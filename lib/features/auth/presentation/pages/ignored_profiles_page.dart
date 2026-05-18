import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
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
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: UserService.instance.watchCurrentUserProfile(),
        builder: (context, snapshot) {
          final ignoredMatchIds = (snapshot.data?['ignoredMatchIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

          if (ignoredMatchIds.isEmpty) {
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
            itemCount: ignoredMatchIds.length,
            itemBuilder: (context, index) {
              final uid = ignoredMatchIds[index];

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
                        "Permanently Hidden", 
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)
                      ),
                      trailing: TextButton(
                        onPressed: () => UserService.instance.unignoreUser(uid),
                        child: const Text("Un-ignore", style: TextStyle(color: AppColors.goldMedium)),
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
