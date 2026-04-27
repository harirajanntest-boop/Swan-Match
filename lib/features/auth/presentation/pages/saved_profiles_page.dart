import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';

class SavedProfilesPage extends StatelessWidget {
  const SavedProfilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.goldMedium,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Saved Profiles',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: UserService.instance.watchCurrentUserProfile(),
        builder: (context, snapshot) {
          final savedIds =
              (snapshot.data?['savedMatchIds'] as List<dynamic>? ?? [])
                  .map((e) => e.toString())
                  .toList();

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.goldMedium),
            );
          }

          if (savedIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 72,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No saved profiles yet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the bookmark icon on a profile to save it here.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            itemCount: savedIds.length,
            itemBuilder: (context, index) {
              final uid = savedIds[index];

              return FutureBuilder<Map<String, dynamic>?>(
                future: UserService.instance.getUserProfile(uid),
                builder: (context, userSnapshot) {
                  final profile = userSnapshot.data;

                  // Build display values
                  final name =
                      (profile?['name'] ??
                          profile?['firstName'] ??
                          '').toString();
                  final photos = profile?['photos'] as List?;
                  final photoUrl =
                      (photos != null && photos.isNotEmpty)
                          ? photos.first.toString()
                          : (profile?['photoUrl'] ?? '').toString();

                  final age = _calcAge(profile?['dateOfBirth']);
                  final city =
                      (profile?['city'] ?? '').toString().trim();
                  final country =
                      (profile?['country'] ?? '').toString().trim();
                  final location = [city, country]
                      .where((s) => s.isNotEmpty)
                      .join(', ');

                  if (userSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      profile == null) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.07),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.onyx,
                        backgroundImage: photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(photoUrl)
                            : null,
                        child: photoUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                color: AppColors.goldMedium,
                                size: 26,
                              )
                            : null,
                      ),
                      title: Text(
                        age > 0 ? '$name, $age' : name.isNotEmpty ? name : 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: location.isNotEmpty
                          ? Text(
                              location,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.bookmark_remove_rounded,
                          color: AppColors.goldMedium,
                          size: 22,
                        ),
                        tooltip: 'Remove from saved',
                        onPressed: () async {
                          final myProfile = await UserService.instance
                              .getCurrentUserProfile();
                          final cur =
                              ((myProfile?['savedMatchIds'] ?? []) as List)
                                  .map((e) => e.toString())
                                  .toSet();
                          cur.remove(uid);
                          await UserService.instance
                              .updateCurrentUserProfile(<String, dynamic>{
                            'savedMatchIds': cur.toList(),
                          });
                        },
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

  int _calcAge(dynamic dob) {
    if (dob == null) return 0;
    try {
      final d = (dob as dynamic).toDate() as DateTime;
      final now = DateTime.now();
      int a = now.year - d.year;
      if (now.month < d.month ||
          (now.month == d.month && now.day < d.day)) a--;
      return a;
    } catch (_) {
      return 0;
    }
  }
}
