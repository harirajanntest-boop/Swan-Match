import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';

class ValuesScreen extends StatelessWidget {
  const ValuesScreen({super.key});

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
            Icon(Icons.favorite_border_rounded, color: AppColors.goldMedium, size: 20),
            SizedBox(width: 10),
            Text(
              'Values & Lifestyle',
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
          final familyValues = (p['familyValuesImportance'] ?? '').toString();
          final traits = (p['personalityTraits'] ?? p['lifestyleTags'] ?? []);
          final traitList = (traits is List)
              ? traits.map((e) => e.toString()).toList()
              : <String>[];
          final maritalStatus = (p['maritalStatus'] ?? '').toString();
          final children = (p['hasChildren'] ?? '').toString();
          final relocate = p['willingToRelocate'];
          final lookingFor = (p['lookingFor'] ?? '').toString();
          final spiritualLevel = (p['spiritualLevel'] ?? '').toString();
          final interests = (p['interests'] ?? []);
          final interestList = (interests is List)
              ? interests.map((e) => e.toString()).toList()
              : <String>[];

          final isEmpty = maritalStatus.isEmpty && familyValues.isEmpty && traitList.isEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: isEmpty
                ? _EmptyNotice()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (lookingFor.isNotEmpty) ...[
                        _Section(label: 'Looking For', value: lookingFor),
                        const _Divider(),
                      ],
                      if (maritalStatus.isNotEmpty) ...[
                        _Section(label: 'Marital Status', value: maritalStatus),
                        const _Divider(),
                      ],
                      if (children.isNotEmpty) ...[
                        _Section(
                          label: 'Children',
                          value: children == 'true' ? 'Yes' : children == 'false' ? 'No' : children,
                        ),
                        const _Divider(),
                      ],
                      if (relocate != null) ...[
                        _Section(
                          label: 'Willing to Relocate',
                          value: relocate == true ? 'Yes' : 'No',
                        ),
                        const _Divider(),
                      ],
                      if (familyValues.isNotEmpty && familyValues != '0') ...[
                        _Section(
                          label: 'Family Values Importance',
                          value: '$familyValues / 5',
                        ),
                        const _Divider(),
                      ],
                      if (spiritualLevel.isNotEmpty) ...[
                        _Section(label: 'Spiritual Level', value: spiritualLevel),
                        const _Divider(),
                      ],
                      if (traitList.isNotEmpty) ...[
                        _TagSection(label: 'Lifestyle Tags', tags: traitList),
                        const _Divider(),
                      ],
                      if (interestList.isNotEmpty)
                        _TagSection(label: 'Interests', tags: interestList),
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
  const _Section({required this.label, required this.value});

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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  final String label;
  final List<String> tags;
  const _TagSection({required this.label, required this.tags});

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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.goldMedium.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.goldMedium.withOpacity(0.3)),
              ),
              child: Text(t,
                  style: const TextStyle(color: AppColors.goldLight, fontSize: 13)),
            )).toList(),
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
          Icon(Icons.favorite_border_rounded,
              color: AppColors.goldMedium.withOpacity(0.4), size: 64),
          const SizedBox(height: 20),
          const Text(
            'No values added yet.',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your profile to share your values and lifestyle.',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
