import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/intent_verification_service.dart';

/// Confirms current relationship intent. Selecting break/pause hides the user
/// from Discover recommendations.
class IntentVerificationScreen extends StatefulWidget {
  final bool asModal;
  /// When true (Profile menu), opens as an editor with current intent prefilled.
  final bool forceOpen;

  const IntentVerificationScreen({
    super.key,
    this.asModal = true,
    this.forceOpen = false,
  });

  static Future<void> showIfNeeded(BuildContext context) async {
    final should =
        await IntentVerificationService.instance.shouldPromptVerification();
    if (!should || !context.mounted) return;
    // Do NOT mark shown until the user actually confirms — otherwise dismiss
    // suppresses the real verification.
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const IntentVerificationScreen(),
    );
  }

  @override
  State<IntentVerificationScreen> createState() =>
      _IntentVerificationScreenState();
}

class _IntentVerificationScreenState extends State<IntentVerificationScreen> {
  String? _selected;
  String? _savedStatus;
  bool _saving = false;
  bool _loading = true;

  static const _options = [
    (
      IntentVerificationService.marriage,
      'Marriage',
      'I am ready to build a lifelong marriage',
      Icons.favorite_rounded,
    ),
    (
      IntentVerificationService.longTerm,
      'Long-Term Relationship',
      'Serious partnership with marriage potential',
      Icons.diversity_1_rounded,
    ),
    (
      IntentVerificationService.takingBreak,
      'Taking a Break',
      'Pause recommendations for now',
      Icons.pause_circle_outline_rounded,
    ),
    (
      IntentVerificationService.pauseMatching,
      'Pause Matching',
      'Hide my profile from Discover',
      Icons.visibility_off_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final status =
        await IntentVerificationService.instance.currentIntentStatus();
    if (!mounted) return;
    setState(() {
      _savedStatus = status;
      _selected = status;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (_selected == null || _saving) return;
    setState(() => _saving = true);
    try {
      await IntentVerificationService.instance.submitIntent(_selected!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Intent saved.'),
          backgroundColor: AppColors.goldDark,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save. ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alreadySaved = _savedStatus != null && _savedStatus!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.goldMedium.withValues(alpha: 0.35)),
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.goldMedium),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    alreadySaved ? 'Your Intent' : 'Confirm Your Intent',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alreadySaved
                        ? 'Your current intent is saved. Change it below only if your situation has changed.'
                        : 'Swan Match is for people building successful marriages. '
                            'Please confirm what you are looking for right now.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ..._options.map((o) {
                    final selected = _selected == o.$1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _selected = o.$1),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.goldDark.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? AppColors.goldMedium
                                    : Colors.white12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  o.$4,
                                  color: selected
                                      ? AppColors.goldLight
                                      : Colors.white54,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        o.$2,
                                        style: TextStyle(
                                          color: selected
                                              ? AppColors.goldLight
                                              : Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        o.$3,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  color: selected
                                      ? AppColors.goldMedium
                                      : Colors.white24,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selected == null || _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldLight,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black54,
                              ),
                            )
                          : Text(
                              alreadySaved ? 'Update Intent' : 'Confirm Intent',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
