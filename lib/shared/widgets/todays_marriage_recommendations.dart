import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../models/user_model.dart';
import '../../services/curated_recommendation_service.dart';
import '../../features/auth/presentation/pages/match_profile_detail_page.dart';

/// Horizontal "Today's Marriage Recommendations" strip for Discover home.
class TodaysMarriageRecommendations extends StatelessWidget {
  final UserModel me;
  final List<UserModel> candidates;
  final void Function(UserModel user)? onOpenProfile;

  const TodaysMarriageRecommendations({
    super.key,
    required this.me,
    required this.candidates,
    this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final items = CuratedRecommendationService.instance.buildToday(
      me: me,
      candidates: candidates,
    );
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            "Today's Marriage Recommendations",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Curated by Swan AI from shared values — not endless swiping.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final user = item.user;
              final photo = user.photos.isNotEmpty
                  ? user.photos.first
                  : (user.profilePicture.isNotEmpty
                      ? user.profilePicture
                      : '');
              final name = user.firstName.isNotEmpty
                  ? user.firstName
                  : (user.name.isNotEmpty ? user.name : 'Member');

              return GestureDetector(
                onTap: () {
                  if (onOpenProfile != null) {
                    onOpenProfile!(user);
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchProfileDetailPage(
                        profile: user.toMap(),
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 168,
                  decoration: BoxDecoration(
                    color: const Color(0xFF151515),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.goldMedium.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: SizedBox(
                          height: 96,
                          width: double.infinity,
                          child: photo.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: photo,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.white10,
                                  child: const Icon(
                                    Icons.person,
                                    color: AppColors.goldLight,
                                  ),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.score}%',
                                  style: const TextStyle(
                                    color: AppColors.goldLight,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...item.reasons.take(2).map(
                                  (r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      '✓ $r',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.65,
                                        ),
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
