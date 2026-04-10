import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class SuccessStoriesPage extends StatelessWidget {
  const SuccessStoriesPage({super.key});

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
          "Success Stories",
          style: TextStyle(color: Colors.white, fontFamily: 'serif', letterSpacing: 1, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Premium Stats Banner ───
            _buildStatsBanner(),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Text(
                "Success stories for the day",
                style: TextStyle(color: AppColors.goldMedium, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif'),
              ),
            ),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('successStories')
                  .orderBy('postedAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.goldMedium),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                    child: Center(
                      child: Text(
                        'No success stories available right now.',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    ),
                  );
                }

                final stories = docs.map((doc) {
                  final data = doc.data();
                  final posted = data['postedAt'] is Timestamp
                      ? (data['postedAt'] as Timestamp).toDate()
                      : DateTime.now();
                  final marriage = data['marriageDate'] is Timestamp
                      ? (data['marriageDate'] as Timestamp).toDate()
                      : posted;

                  return <String, String>{
                    'names': (data['names'] ?? 'Couple').toString(),
                    'posted': _formatDate(posted),
                    'marriageDate': _formatDate(marriage),
                    'quote': (data['quote'] ?? '').toString(),
                  };
                }).toList();

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 40),
                  itemCount: stories.length,
                  itemBuilder: (context, index) {
                    return _SuccessStoryCard(story: stories[index]);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  // ─── The Luxury Stats Banner ───
  Widget _buildStatsBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.goldMedium.withOpacity(0.3), width: 1),
        gradient: LinearGradient(
          colors: [AppColors.onyx, Colors.white.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.workspace_premium, color: AppColors.goldLight, size: 36),
                const SizedBox(height: 12),
                const Text(
                  "Lakhs of Happy Marriages",
                  style: TextStyle(color: AppColors.goldLight, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Recognized globally for the highest number of documented marriages online.",
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(height: 1, color: Colors.white.withOpacity(0.05)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(Icons.verified_user_outlined, "100%", "Verified\nprofiles"),
                    Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                    _buildStatItem(Icons.handshake_outlined, "4 Crore+", "Customers\nserved"),
                    Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                    _buildStatItem(Icons.history_edu, "26 Years", "Successful\nmatchmaking"),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Icon(icon, color: AppColors.goldMedium, size: 24),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
      ],
    );
  }
}

// ─── The Story Card ───
class _SuccessStoryCard extends StatelessWidget {
  final Map<String, String> story;

  const _SuccessStoryCard({required this.story});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Area with Gradient Overlay
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Placeholder for actual couple image
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF2A2A2A), Color(0xFF111111)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    ),
                    child: const Center(child: Icon(Icons.favorite, color: Colors.white10, size: 60)),
                  ),
                  // Gradient for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Text(
                      story["names"]!,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'serif', letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Text Content Area
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Posted on: ${story["posted"]}", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                const SizedBox(height: 4),
                Text("Marriage date: ${story["marriageDate"]}", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote, color: AppColors.goldMedium, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.5),
                          children: [
                            TextSpan(text: story["quote"]),
                            const TextSpan(text: " Read more >", style: TextStyle(color: AppColors.goldMedium, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}