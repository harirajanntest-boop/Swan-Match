import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../models/interest_model.dart';
import '../../../../services/interest_service.dart';
import '../../../../services/user_service.dart';
import 'main_dashboard.dart';
import 'match_profile_detail_page.dart';

class InterestsView extends StatefulWidget {
  const InterestsView({super.key});

  @override
  State<InterestsView> createState() => _InterestsViewState();
}

class _InterestsViewState extends State<InterestsView> with SingleTickerProviderStateMixin {
  String _selectedTier = 'Regular'; 
  String _selectedFilter = 'All';
  final interestService = InterestService.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ─── STREAMS CACHED IN STATE ───
  late final Stream<List<InterestModel>> _receivedInterestsStream;
  late final Stream<List<InterestModel>> _sentInterestsStream;

  @override
  void initState() {
    super.initState();
    _receivedInterestsStream = InterestService.instance.watchInterestsForMe();
    _sentInterestsStream = InterestService.instance.watchMySentInterests();
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
          children: [
            // ─── Header & Tier Toggle ───
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Interests",
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: 1),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.onyx,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.goldMedium.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTierToggle("Regular"),
                        _buildTierToggle("PRIME"),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Main Tab Bar (Received / Sent) ───
            TabBar(
              dividerColor: Colors.white.withOpacity(0.05),
              indicatorColor: AppColors.goldMedium,
              indicatorWeight: 3,
              labelColor: AppColors.goldMedium,
              unselectedLabelColor: Colors.white.withOpacity(0.4),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
              tabs: const [
                Tab(text: "Interests Received"),
                Tab(text: "Interests Sent"),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search interests by name',
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
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // ─── Dynamic Content Area ───
            Expanded(
              child: TabBarView(
                children: [
                  _buildContentArea(isReceived: true),
                  _buildContentArea(isReceived: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helper: Tier Toggle ───
  Widget _buildTierToggle(String title) {
    bool isSelected = _selectedTier == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedTier = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.goldGradient : null,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            if (title == "PRIME" && !isSelected) ...[
              Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.goldMedium, shape: BoxShape.circle)),
              const SizedBox(width: 4),
            ],
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white.withOpacity(0.7),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helper: Content Area (Header + Empty State) ───
  Widget _buildContentArea({required bool isReceived}) {
    final baseStream = isReceived
        ? _receivedInterestsStream
        : _sentInterestsStream;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<InterestModel>>(
            stream: baseStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.goldMedium),
                );
              }

              final interests = snapshot.data ?? const <InterestModel>[];
              final byOtherUser = <String, InterestModel>{};
              for (final item in interests) {
                final key = isReceived ? item.fromUserId : item.toUserId;
                final previous = byOtherUser[key];
                if (previous == null || item.updatedAt.isAfter(previous.updatedAt)) {
                  byOtherUser[key] = item;
                }
              }

              final uniqueInterests = byOtherUser.values.toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

              final filtered = uniqueInterests.where((item) {
                if (_selectedFilter == 'All') return true;
                final status = item.status.toLowerCase();
                if (_selectedFilter == 'Pending') return status == 'pending';
                if (_selectedFilter == 'Declined') return status == 'declined' || status == 'rejected';
                return status == 'accepted' || status == 'replied';
              }).where((item) {
                if (_searchQuery.isEmpty) return true;
                final otherUserId = isReceived ? item.fromUserId : item.toUserId;
                return otherUserId.toLowerCase().contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: _PremiumEmptyState(
                    icon: isReceived ? Icons.favorite_border : Icons.send_outlined,
                    message: "No interests found.",
                    subMessage: isReceived
                        ? "When someone sends you an interest, it will appear here."
                        : "Start exploring profiles and send interests to connect!",
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final otherUserId = isReceived ? item.fromUserId : item.toUserId;
                  return _InterestTile(
                    interest: item,
                    otherUserId: otherUserId,
                    isReceived: isReceived,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InterestTile extends StatelessWidget {
  final InterestModel interest;
  final String otherUserId;
  final bool isReceived;

  const _InterestTile({required this.interest, required this.otherUserId, required this.isReceived});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserService.instance.getUserProfile(otherUserId),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? <String, dynamic>{};
        final name = (profile['name'] ?? 'Member').toString();
        final city = (profile['city'] ?? 'Unknown').toString();
        final status = interest.status.toUpperCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (profile.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchProfileDetailPage(profile: profile),
                          ),
                        );
                      }
                    },
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: AppColors.goldMedium)),
                            const SizedBox(height: 2),
                            Text(city, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.goldMedium.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.goldMedium.withOpacity(0.4)),
                    ),
                    child: Text(status, style: const TextStyle(color: AppColors.goldLight, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (isReceived && interest.status.toLowerCase() == 'pending') ...[
                const SizedBox(height: 12),
                Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await InterestService.instance.updateInterestStatus(
                        interestId: interest.id,
                        status: 'declined',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.25)),
                      foregroundColor: Colors.white70,
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await InterestService.instance.updateInterestStatus(
                            interestId: interest.id,
                            status: 'accepted',
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.goldMedium,
                          foregroundColor: AppColors.obsidian,
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Premium Glassmorphic Empty State ───
class _PremiumEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subMessage;

  const _PremiumEmptyState({
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
              // Ambient Glow
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.goldMedium.withOpacity(0.15), blurRadius: 40, spreadRadius: 10)],
                ),
              ),
              // Frosted Glass Ring
              ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: AppColors.goldMedium.withOpacity(0.3), width: 1.5),
                    ),
                    child: Center(
                      child: Icon(icon, color: AppColors.goldMedium, size: 40),
                    ),
                  ),
                ),
              ),
              // Decorative Accent Dots
              Positioned(top: 0, right: 10, child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.goldLight))),
              Positioned(bottom: 10, left: 0, child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.goldMedium.withOpacity(0.5)))),
            ],
          ),
          
          const SizedBox(height: 32),
          
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
          
          const SizedBox(height: 40),
          
          // Call to Action (Explore Matches)
          GestureDetector(
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainDashboard(initialIndex: 1)),
                (route) => false,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.goldMedium.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(30),
                color: AppColors.goldMedium.withOpacity(0.05),
              ),
              child: const Text("Explore Matches", style: TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}