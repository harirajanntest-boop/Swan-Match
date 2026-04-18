import 'package:flutter/material.dart';

// Shared colors for onboarding
class OnboardingColors {
  static const Color background = Color(0xFF0D0D0D);
  static const Color primaryGold = Color(0xFFD4A017);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0x8AFFFFFF); // Colors.white54
  static const Color inputUnderline = Color(0xFFD4A017);
  static const Color selectedBorder = Color(0xFFD4A017);
  static const Color unselectedBorder = Color(0x3DFFFFFF); // Colors.white24
  static const Color cardBackground = Color(0xFF1A1A1A);
  static const Color disabledButton = Color(0x1FFFFFFF); // Colors.white12
  static const Color skipButton = Color(0x61FFFFFF); // Colors.white38
}

// Next Button Widget
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
                colors: [Color(0xFFC8960C), OnboardingColors.primaryGold],
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
                    width: 24,
                    height: 24,
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

// Gold Chip Widget
class GoldChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showCheckmark;

  const GoldChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showCheckmark = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected 
              ? OnboardingColors.primaryGold.withOpacity(0.1)
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
              Icon(
                Icons.check,
                color: OnboardingColors.primaryGold,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Section Divider Widget
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

// Custom TextField with underline style
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
  });

  @override
  State<UnderlineTextField> createState() => _UnderlineTextFieldState();
}

class _UnderlineTextFieldState extends State<UnderlineTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
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
          Text(
            widget.label!,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: OnboardingColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          style: const TextStyle(
            fontSize: 16,
            color: OnboardingColors.textPrimary,
            decoration: TextDecoration.none,
          ),
          cursorColor: OnboardingColors.primaryGold,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
              color: OnboardingColors.textSecondary,
              fontSize: 16,
            ),
            border: InputBorder.none,
            enabledBorder: UnderlineInputBorder(
              borderSide: const BorderSide(color: OnboardingColors.inputUnderline, width: 1),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: const BorderSide(color: OnboardingColors.primaryGold, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: widget.onChanged,
        ),
        if (widget.helper != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.helper!,
            style: const TextStyle(
              fontSize: 13,
              color: OnboardingColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
