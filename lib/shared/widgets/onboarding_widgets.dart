import 'package:flutter/material.dart';

// ─── Shared Colors ──────────────────────────────────────────────────────────
// Aligned with AppColors (core/constants/colors.dart) — muted warm gold palette
class OnboardingColors {
  static const Color background = Color(0xFF080808);   // AppColors.obsidian
  static const Color primaryGold = Color(0xFFc6a85c);  // AppColors.goldMedium
  static const Color goldDark = Color(0xFFa08840);     // AppColors.goldDark
  static const Color goldLight = Color(0xFFdec47e);    // AppColors.goldLight
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0x8AFFFFFF);
  static const Color inputUnderline = Color(0xFFc6a85c);
  static const Color selectedBorder = Color(0xFFc6a85c);
  static const Color unselectedBorder = Color(0x3DFFFFFF);
  static const Color cardBackground = Color(0xFF151515); // AppColors.onyx
  static const Color fieldBackground = Color(0xFF1E1E1E);
  static const Color disabledButton = Color(0x1FFFFFFF);
  static const Color skipButton = Color(0x61FFFFFF);
}

// ─── Next Button ────────────────────────────────────────────────────────────
class NextButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final bool isLoading;

  const NextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
                colors: [OnboardingColors.goldDark, OnboardingColors.primaryGold, OnboardingColors.goldLight],
              )
            : null,
        color: enabled ? null : OnboardingColors.disabledButton,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: enabled && !isLoading ? onPressed : null,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        enabled ? Colors.black : Colors.grey,
                      ),
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: enabled ? Colors.black : Colors.grey,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Gold Chip ──────────────────────────────────────────────────────────────
class GoldChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showCheckmark;
  final IconData? icon;

  const GoldChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showCheckmark = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? OnboardingColors.primaryGold.withOpacity(0.15)
              : Colors.transparent,
          border: Border.all(
            color: selected ? OnboardingColors.selectedBorder : OnboardingColors.unselectedBorder,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: selected ? OnboardingColors.primaryGold : Colors.white54, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? OnboardingColors.primaryGold : OnboardingColors.textPrimary,
              ),
            ),
            if (showCheckmark && selected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, color: OnboardingColors.primaryGold, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Section Divider ────────────────────────────────────────────────────────
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: OnboardingColors.unselectedBorder,
      margin: const EdgeInsets.symmetric(vertical: 24),
    );
  }
}

// ─── Underline Text Field ───────────────────────────────────────────────────
class UnderlineTextField extends StatefulWidget {
  final String? hint;
  final String? label;
  final String? helper;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool autofocus;
  final int? maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  /// When set, the underline turns red and this message is shown below.
  final String? errorText;

  const UnderlineTextField({
    super.key,
    this.hint,
    this.label,
    this.helper,
    this.controller,
    this.keyboardType,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.errorText,
  });

  @override
  State<UnderlineTextField> createState() => _UnderlineTextFieldState();
}

class _UnderlineTextFieldState extends State<UnderlineTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: OnboardingColors.textPrimary)),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          style: const TextStyle(fontSize: 16, color: OnboardingColors.textPrimary),
          cursorColor: OnboardingColors.primaryGold,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: OnboardingColors.textSecondary, fontSize: 16),
            border: InputBorder.none,
            enabledBorder: UnderlineInputBorder(
              borderSide: widget.errorText != null
                  ? const BorderSide(color: Colors.redAccent, width: 1.5)
                  : const BorderSide(color: OnboardingColors.inputUnderline, width: 1),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: widget.errorText != null
                    ? Colors.redAccent
                    : OnboardingColors.primaryGold,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            counterText: "",
          ),
          onChanged: widget.onChanged,
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ],
        if (widget.helper != null) ...[
          const SizedBox(height: 8),
          Text(widget.helper!, style: const TextStyle(fontSize: 13, color: OnboardingColors.textSecondary, height: 1.4)),
        ],
      ],
    );
  }
}

// ─── Premium Card Text Field ────────────────────────────────────────────────
class PremiumTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool readOnly;
  final Widget? suffix;
  final int maxLines;
  final int? maxLength;

  const PremiumTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.readOnly = false,
    this.suffix,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: OnboardingColors.fieldBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(color: OnboardingColors.primaryGold, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ),
              if (suffix != null) suffix!,
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              counterText: "",
              counterStyle: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Premium Dropdown ───────────────────────────────────────────────────────
class PremiumDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const PremiumDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: OnboardingColors.fieldBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: OnboardingColors.primaryGold, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              isDense: true,
              value: value,
              hint: Text(hint, style: const TextStyle(color: Colors.white38)),
              dropdownColor: const Color(0xFF2C2C2C),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Premium Selection Card ─────────────────────────────────────────────────
class PremiumSelectionCard extends StatelessWidget {
  final String text;
  final String? subtitle;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const PremiumSelectionCard({
    super.key,
    required this.text,
    this.subtitle,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? OnboardingColors.primaryGold.withOpacity(0.1) : OnboardingColors.fieldBackground,
          border: Border.all(
            color: isSelected ? OnboardingColors.primaryGold : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: isSelected ? OnboardingColors.primaryGold : Colors.white54, size: 22),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isSelected ? OnboardingColors.primaryGold : Colors.white,
                      fontSize: 15, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: OnboardingColors.primaryGold, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Premium Toggle ─────────────────────────────────────────────────────────
class PremiumToggle extends StatelessWidget {
  final String label;
  final bool? value;
  final ValueChanged<bool> onChanged;
  final String trueLabel;
  final String falseLabel;

  const PremiumToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.trueLabel = 'Yes',
    this.falseLabel = 'No',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildOption(trueLabel, value == true, () => onChanged(true))),
            const SizedBox(width: 12),
            Expanded(child: _buildOption(falseLabel, value == false, () => onChanged(false))),
          ],
        ),
      ],
    );
  }

  Widget _buildOption(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? OnboardingColors.primaryGold.withOpacity(0.15) : OnboardingColors.fieldBackground,
          border: Border.all(
            color: selected ? OnboardingColors.primaryGold : Colors.white12,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: selected ? OnboardingColors.primaryGold : Colors.white70,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Verified Badge ─────────────────────────────────────────────────────────
class VerifiedBadge extends StatelessWidget {
  final String label;

  const VerifiedBadge({super.key, this.label = 'Verified'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, color: Colors.green, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Section Title ──────────────────────────────────────────────────────────
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ],
    );
  }
}

// ─── Premium Slider with Labels ─────────────────────────────────────────────
class PremiumLabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) labelBuilder;
  final ValueChanged<double> onChanged;

  const PremiumLabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: OnboardingColors.primaryGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(labelBuilder(value), style: const TextStyle(color: OnboardingColors.primaryGold, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: OnboardingColors.primaryGold,
            inactiveTrackColor: Colors.white12,
            thumbColor: OnboardingColors.primaryGold,
            overlayColor: OnboardingColors.primaryGold.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
