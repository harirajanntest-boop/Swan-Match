import 'package:flutter/material.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

class OnboardingStep2Status extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStep2Status({super.key, required this.data, required this.onNext, required this.onBack});

  @override
  State<OnboardingStep2Status> createState() => _OnboardingStep2StatusState();
}

class _OnboardingStep2StatusState extends State<OnboardingStep2Status> {
  String? _lookingFor;
  String? _maritalStatus;
  bool? _hasChildren;
  bool? _willingToRelocate;
  late TextEditingController _childrenDetailsCtrl;

  final List<Map<String, dynamic>> _lookingForOptions = [
    {'label': 'Marriage', 'icon': Icons.favorite, 'subtitle': 'Looking for a life partner'},
    {'label': 'Long-term Relationship', 'icon': Icons.people, 'subtitle': 'Building something serious'},
  ];

  final List<String> _maritalOptions = ['Never Married', 'Divorced', 'Widowed', 'Separated'];

  @override
  void initState() {
    super.initState();
    _lookingFor = widget.data.lookingFor.isNotEmpty ? widget.data.lookingFor : null;
    _maritalStatus = widget.data.maritalStatus.isNotEmpty ? widget.data.maritalStatus : null;
    _hasChildren = widget.data.hasChildren;
    _willingToRelocate = widget.data.willingToRelocate;
    _childrenDetailsCtrl = TextEditingController(text: widget.data.childrenDetails);
  }

  @override
  void dispose() {
    _childrenDetailsCtrl.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_lookingFor == null) {
      _showError('Please select what you\'re looking for');
      return;
    }
    if (_maritalStatus == null) {
      _showError('Please select your marital status');
      return;
    }
    if (_hasChildren == null) {
      _showError('Please indicate if you have children');
      return;
    }
    if (_willingToRelocate == null) {
      _showError('Please indicate if you\'re willing to relocate');
      return;
    }

    widget.data.lookingFor = _lookingFor!;
    widget.data.maritalStatus = _maritalStatus!;
    widget.data.hasChildren = _hasChildren;
    widget.data.childrenDetails = _childrenDetailsCtrl.text.trim();
    widget.data.willingToRelocate = _willingToRelocate;

    widget.onNext();
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
          const Text('Status & Intent', style: TextStyle(color: Colors.white, fontSize: 26, fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('What are you looking for?', style: TextStyle(color: Colors.white54, fontSize: 15)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Looking For
                  const SectionTitle(title: 'I\'m looking for'),
                  const SizedBox(height: 12),
                  ..._lookingForOptions.map((opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PremiumSelectionCard(
                      text: opt['label'],
                      subtitle: opt['subtitle'],
                      icon: opt['icon'],
                      isSelected: _lookingFor == opt['label'],
                      onTap: () => setState(() => _lookingFor = opt['label']),
                    ),
                  )),
                  const SizedBox(height: 20),

                  // Marital Status
                  const SectionTitle(title: 'Marital Status'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: _maritalOptions.map((s) => GoldChip(
                      label: s,
                      selected: _maritalStatus == s,
                      onTap: () => setState(() => _maritalStatus = s),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Children
                  PremiumToggle(
                    label: 'Do you have children?',
                    value: _hasChildren,
                    onChanged: (v) => setState(() => _hasChildren = v),
                  ),
                  if (_hasChildren == true) ...[
                    const SizedBox(height: 12),
                    PremiumTextField(
                      label: 'CHILDREN DETAILS',
                      hint: 'e.g., 2 kids, ages 5 and 8',
                      controller: _childrenDetailsCtrl,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Willing to Relocate
                  PremiumToggle(
                    label: 'Willing to relocate?',
                    value: _willingToRelocate,
                    onChanged: (v) => setState(() => _willingToRelocate = v),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          NextButton(label: 'Next', onPressed: _handleNext),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
