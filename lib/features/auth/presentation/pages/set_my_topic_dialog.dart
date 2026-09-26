import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/helpers/topic_suggestions.dart';
import '../../../../shared/widgets/gold_button.dart';

/// Shown on first login (or any login while the user still hasn't set one) —
/// lets the user set the personal topic that `ConnectRecordPage` shows to
/// whoever taps "Connect" on their profile, instead of a random pool topic.
/// Skippable: dismissing just leaves `myTopic` unset, so the Connect flow
/// keeps using the random-pool fallback until the user sets one (here or
/// later from Settings).
class SetMyTopicDialog extends StatefulWidget {
  const SetMyTopicDialog({super.key});

  /// Shows the dialog if not already open elsewhere; returns true if the
  /// user actually saved a topic (false if skipped/dismissed).
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SetMyTopicDialog(),
    );
    return result ?? false;
  }

  @override
  State<SetMyTopicDialog> createState() => _SetMyTopicDialogState();
}

class _SetMyTopicDialogState extends State<SetMyTopicDialog> {
  final TextEditingController _controller = TextEditingController();
  List<String> _suggestions = [];
  bool _loadingSuggestions = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
    _prefillExistingTopic();
  }

  /// Pre-fills the field when reopened from Settings to edit an
  /// already-set topic — first-time (popup) callers have nothing to prefill.
  Future<void> _prefillExistingTopic() async {
    final profile = await UserService.instance.getCurrentUserProfile();
    final existing = (profile?['myTopic'] ?? '').toString().trim();
    if (existing.isNotEmpty && mounted) {
      setState(() => _controller.text = existing);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final topics = await fetchActiveTopics(limit: 8);
    if (!mounted) return;
    setState(() {
      _suggestions = topics;
      _loadingSuggestions = false;
    });
  }

  void _pickSuggestion(String topic) {
    setState(() => _controller.text = topic);
  }

  Future<void> _save() async {
    final topic = _controller.text.trim();
    if (topic.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
        'myTopic': topic,
        'myTopicSetAt': DateTime.now(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your topic. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _controller.text.trim().isNotEmpty && !_saving;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        backgroundColor: AppColors.obsidian.withOpacity(0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.goldMedium.withOpacity(0.3)),
        ),
        title: const Column(
          children: [
            Icon(Icons.forum_rounded, color: AppColors.goldMedium, size: 44),
            SizedBox(height: 12),
            Text(
              'Set Your Connect Topic',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 19),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text(
                'This is the question others will answer with a video when they want to connect with you. Write your own, or pick a suggestion below.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 2,
                maxLength: 140,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'e.g. What does a perfect weekend look like to you?',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                  counterStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Or choose a suggestion',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (_loadingSuggestions)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.goldMedium),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: Column(
                      children: _suggestions.map((topic) {
                        final selected = _controller.text.trim() == topic;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _pickSuggestion(topic),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.goldMedium.withOpacity(0.18)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.goldMedium.withOpacity(0.6)
                                      : Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Text(
                                topic,
                                style: TextStyle(
                                  color: selected ? AppColors.goldMedium : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GoldGradientButton(
                text: 'Save Topic',
                enabled: canSave,
                isLoading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: Text(
                  'Skip for now',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
