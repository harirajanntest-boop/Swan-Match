import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';

class AboutMeScreen extends StatelessWidget {
  const AboutMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.goldMedium, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.person_outline_rounded, color: AppColors.goldMedium, size: 20),
            SizedBox(width: 10),
            Text(
              'About Me',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: UserService.instance.getUserProfile(
          FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.goldMedium));
          }
          final p = snapshot.data ?? const <String, dynamic>{};
          final bio = (p['bio'] ?? p['shortBio'] ?? '').toString();
          final religion = (p['religion'] ?? '').toString();
          final ethnicity = (p['ethnicity'] ?? '').toString();
          final education = (p['educationLevel'] ?? '').toString();
          final profession = (p['profession'] ?? '').toString();
          final industry = (p['industry'] ?? '').toString();
          final smoking = (p['smoking'] ?? '').toString();
          final drinking = (p['drinking'] ?? '').toString();
          final lookingFor = (p['lookingFor'] ?? '').toString();

          final isEmpty = bio.isEmpty && religion.isEmpty && ethnicity.isEmpty &&
              education.isEmpty && profession.isEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: isEmpty
                ? _EmptyNotice()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bio.isNotEmpty) ...[
                        _Section(label: 'Bio', value: bio, isLong: true),
                        const _Divider(),
                      ],
                      if (religion.isNotEmpty) ...[
                        _Section(label: 'Religion', value: religion),
                        const _Divider(),
                      ],
                      if (ethnicity.isNotEmpty) ...[
                        _Section(label: 'Ethnicity', value: ethnicity),
                        const _Divider(),
                      ],
                      if (education.isNotEmpty) ...[
                        _Section(label: 'Education', value: education),
                        const _Divider(),
                      ],
                      if (profession.isNotEmpty) ...[
                        _Section(label: 'Profession', value: profession),
                        const _Divider(),
                      ],
                      if (industry.isNotEmpty) ...[
                        _Section(label: 'Industry', value: industry),
                        const _Divider(),
                      ],
                      if (smoking.isNotEmpty) ...[
                        _Section(label: 'Smoking', value: smoking),
                        const _Divider(),
                      ],
                      if (drinking.isNotEmpty) ...[
                        _Section(label: 'Drinking', value: drinking),
                        const _Divider(),
                      ],
                      if (lookingFor.isNotEmpty)
                        _Section(label: 'Looking For', value: lookingFor),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final String value;
  final bool isLong;
  const _Section({required this.label, required this.value, this.isLong = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.goldMedium.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isLong ? 15 : 16,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: Colors.white10, height: 1);
}

class _EmptyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline_rounded,
              color: AppColors.goldMedium.withOpacity(0.4), size: 64),
          const SizedBox(height: 20),
          const Text(
            'No information added yet.',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Edit Profile" to add your bio and personal details.',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
