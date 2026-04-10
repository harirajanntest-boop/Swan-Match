import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../services/interest_service.dart';
import '../../../../shared/widgets/linear_message.dart';

class MatchProfileDetailPage extends StatelessWidget {
  final Map<String, dynamic> profile;

  const MatchProfileDetailPage({super.key, required this.profile});

  String _read(String key, {String fallback = '-'}) {
    final raw = profile[key];
    if (raw == null) return fallback;
    final text = raw.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final uid = _read('uid', fallback: '');
    final name = _read('name', fallback: 'Member');
    final photoUrl = [
      profile['photoUrl'],
      profile['profileImageUrl'],
      profile['imageUrl'],
    ].firstWhere(
      (value) => value != null && value.toString().trim().isNotEmpty,
      orElse: () => '',
    ).toString();

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.goldMedium),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile Details',
          style: TextStyle(color: Colors.white, fontFamily: 'serif'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withOpacity(0.04),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: photoUrl.isEmpty
                  ? const Center(
                      child: Icon(Icons.person, color: AppColors.goldMedium, size: 90),
                    )
                  : Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.person, color: AppColors.goldMedium, size: 90),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              color: AppColors.goldLight,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 10),
          ..._buildAllInfoTiles(),
          const SizedBox(height: 18),
          StreamBuilder<Set<String>>(
            stream: InterestService.instance.watchMyPendingSentInterestUserIds(),
            builder: (context, snapshot) {
              final pendingIds = snapshot.data ?? const <String>{};
              final isPending = pendingIds.contains(uid);

              return OutlinedButton(
                onPressed: (uid.isEmpty || isPending)
                    ? null
                    : () async {
                        final result = await InterestService.instance.sendInterest(toUserId: uid);
                        if (!context.mounted) return;
                        showLinearMessage(
                          context,
                          result == InterestSendResult.pending
                              ? 'Interest already pending'
                              : result == InterestSendResult.alreadyAccepted
                                  ? 'Interest already accepted. You can message now.'
                                  : 'Interest sent successfully',
                        );
                      },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isPending ? Colors.white54 : AppColors.goldMedium,
                    width: 1.5,
                  ),
                  foregroundColor: isPending ? Colors.white70 : AppColors.goldMedium,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(isPending ? 'Pending' : 'Send Interest'),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAllInfoTiles() {
    final lifestyle = profile['lifestyle'] is Map
        ? Map<String, dynamic>.from(profile['lifestyle'] as Map)
        : const <String, dynamic>{};

    final items = <MapEntry<String, String>>[
      MapEntry('Age', _read('age')),
      MapEntry('Gender', _read('gender')),
      MapEntry('Height', _read('height')),
      MapEntry('Weight', _read('weight')),
      MapEntry('Date of Birth', _formatDateOfBirth(profile['dateOfBirth'])),
      MapEntry('Marital Status', _read('maritalStatus')),
      MapEntry('Mother Tongue', _read('motherTongue')),
      MapEntry('Physical Status', _read('physicalStatus')),
      MapEntry('Body Type', _read('bodyType')),
      MapEntry('Profile Created By', _read('profileFor')),
      MapEntry('Religion', _read('religion')),
      MapEntry('Caste', _read('caste')),
      MapEntry('Sub Caste', _read('subCaste')),
      MapEntry('Gothram', _read('gothram')),
      MapEntry('Zodiac', _read('zodiac')),
      MapEntry('Star', _read('star')),
      MapEntry('Rassi', _read('rassi')),
      MapEntry('Dosham', _read('dosham')),
      MapEntry('Education', _read('educationDegree')),
      MapEntry('College / Institution', _read('collegeName')),
      MapEntry('Occupation', _read('occupation')),
      MapEntry('Employed In', _read('employmentSector')),
      MapEntry('Annual Income', _read('annualIncome')),
      MapEntry('Country', _read('country')),
      MapEntry('State', _read('state')),
      MapEntry('City', _read('city')),
      MapEntry('Citizenship', _read('citizenship')),
      MapEntry('Family Values', _read('familyValues')),
      MapEntry('Family Type', _read('familyType')),
      MapEntry('Family Status', _read('familyStatus')),
      MapEntry('Father Occupation', _read('fatherOccupation')),
      MapEntry('Mother Occupation', _read('motherOccupation')),
      MapEntry('Eating Habits', (lifestyle['eatingHabits'] ?? '-').toString()),
      MapEntry('Drinking Habits', (lifestyle['drinkingHabits'] ?? '-').toString()),
      MapEntry('Smoking Habits', (lifestyle['smokingHabits'] ?? '-').toString()),
      MapEntry('About Me', _read('aboutMe')),
    ];

    return items
        .where((entry) => entry.value.trim().isNotEmpty && entry.value.trim() != '-')
        .map((entry) => _InfoTile(label: entry.key, value: entry.value))
        .toList();
  }

  String _formatDateOfBirth(dynamic rawDob) {
    DateTime? dob;
    if (rawDob is DateTime) {
      dob = rawDob;
    } else if (rawDob != null && rawDob.runtimeType.toString() == 'Timestamp') {
      try {
        dob = rawDob.toDate() as DateTime;
      } catch (_) {
        dob = null;
      }
    }

    if (dob == null) return _read('dateOfBirth');
    return DateFormat('dd MMM yyyy').format(dob);
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
          ),
          const Text(': ', style: TextStyle(color: Colors.white54)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
