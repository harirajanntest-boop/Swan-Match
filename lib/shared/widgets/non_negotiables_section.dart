import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../helpers/dealbreaker_matcher.dart';

/// Multi-select chips for "My Non-Negotiables" (onboarding + edit profile).
class NonNegotiablesSection extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final bool compact;

  const NonNegotiablesSection({
    super.key,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  void _toggle(String id) {
    final next = List<String>.from(selected);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      // Mutually exclusive children preferences
      if (id == DealbreakerCatalog.wantsChildren) {
        next.remove(DealbreakerCatalog.noChildren);
      } else if (id == DealbreakerCatalog.noChildren) {
        next.remove(DealbreakerCatalog.wantsChildren);
      }
      next.add(id);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Non-Negotiables',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Only recommend people who match these marriage values.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DealbreakerCatalog.allIds.map((id) {
            final isOn = selected.contains(id);
            return GestureDetector(
              onTap: () => _toggle(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isOn
                      ? AppColors.goldLight
                      : AppColors.goldDark.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOn
                        ? AppColors.goldMedium
                        : AppColors.goldMedium.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  DealbreakerCatalog.labelFor(id),
                  style: TextStyle(
                    color: isOn ? Colors.black : Colors.white70,
                    fontSize: 12.5,
                    fontWeight: isOn ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
