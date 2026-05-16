import 'package:flutter/material.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

class OnboardingStep8Exclusivity extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onComplete;
  final VoidCallback onBack;
  final bool isLoading;

  const OnboardingStep8Exclusivity({super.key, required this.data, required this.onComplete, required this.onBack, this.isLoading = false});

  @override
  State<OnboardingStep8Exclusivity> createState() => _OnboardingStep8ExclusivityState();
}

class _OnboardingStep8ExclusivityState extends State<OnboardingStep8Exclusivity> {
  late TextEditingController _inviteCodeCtrl;
  String? _visibility;

  final List<Map<String, dynamic>> _visibilityOptions = [
    {
      'label': 'Public',
      'subtitle': 'Visible to all verified members on the platform',
      'icon': Icons.public,
    },
    {
      'label': 'Private',
      'subtitle': 'Hidden from other users — only you control who connects with you',
      'icon': Icons.lock_outline,
    },
  ];

  @override
  void initState() {
    super.initState();
    _inviteCodeCtrl = TextEditingController(text: widget.data.inviteCode);
    // Default to Public if no prior selection, or if it was the removed 'Curated Matches Only'
    final prev = widget.data.profileVisibility;
    _visibility = (prev == 'Public' || prev == 'Private') ? prev : 'Public';
  }

  @override
  void dispose() {
    _inviteCodeCtrl.dispose();
    super.dispose();
  }

  void _handleComplete() {
    if (_visibility == null) {
      _showError('Please select your profile visibility');
      return;
    }

    widget.data.inviteCode = _inviteCodeCtrl.text.trim();
    widget.data.profileVisibility = _visibility!;

    widget.onComplete();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Exclusivity', style: TextStyle(color: Colors.white, fontSize: 26, fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Choose how others discover your profile', style: TextStyle(color: Colors.white54, fontSize: 15)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Invite Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          OnboardingColors.primaryGold.withOpacity(0.08),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OnboardingColors.primaryGold.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.vpn_key, color: OnboardingColors.primaryGold, size: 20),
                            SizedBox(width: 8),
                            Text('Invite Code', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Have an invite code? Enter it for priority access and exclusive benefits.',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _inviteCodeCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 3),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'XXXX-XXXX',
                            hintStyle: TextStyle(color: Colors.white12, fontSize: 18, letterSpacing: 3),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Profile Visibility
                  const SectionTitle(
                    title: 'Profile Visibility',
                    subtitle: 'Public — visible to everyone. Private — hidden from discovery.',
                  ),
                  const SizedBox(height: 14),
                  ..._visibilityOptions.map((opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PremiumSelectionCard(
                      text: opt['label'],
                      subtitle: opt['subtitle'],
                      icon: opt['icon'],
                      isSelected: _visibility == opt['label'],
                      onTap: () => setState(() => _visibility = opt['label']),
                    ),
                  )),
                  const SizedBox(height: 28),

                  // Profile Summary
                  _buildProfileSummary(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          NextButton(
            label: 'Complete Profile',
            onPressed: _handleComplete,
            isLoading: widget.isLoading,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProfileSummary() {
    final d = widget.data;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnboardingColors.fieldBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize, color: OnboardingColors.primaryGold, size: 18),
              SizedBox(width: 8),
              Text('Profile Summary', style: TextStyle(color: OnboardingColors.primaryGold, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          _summaryRow('Name', d.fullName),
          _summaryRow('Age', '${d.age ?? "–"}'),
          _summaryRow('Location', d.location),
          _summaryRow('Looking for', d.lookingFor),
          _summaryRow('Education', d.educationLevel),
          _summaryRow('Profession', d.profession),
          _summaryRow('Religion', d.religion),
          _summaryRow('Photos', '${d.photos.length} uploaded'),
          _summaryRow('Bio', d.bio.isNotEmpty ? '${d.bio.split(' ').take(10).join(' ')}...' : '–'),
          _summaryRow('Verification', d.idVerified ? 'Pending Admin Approval' : '✗ Not yet'),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '–' : value, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
