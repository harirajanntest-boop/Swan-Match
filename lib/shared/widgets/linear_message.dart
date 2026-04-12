import 'package:flutter/material.dart';

// ─── Gold-themed in-app snackbar ─────────────────────────────────────────────
void showLinearMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      // Override global theme for the icon colour row
      backgroundColor: isError
          ? const Color(0xFF1A0A00) // dark amber-red for errors
          : const Color(0xFF1A1400), // dark gold for success
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      duration: const Duration(seconds: 3),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isError
              ? const Color(0xFFB8860B).withOpacity(0.6)  // muted gold-amber border on error
              : const Color(0xFFD4AF37),                  // gold border on success
          width: 1.2,
        ),
      ),
      content: Row(
        children: [
          // ── Icon ──
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isError
                  ? const Color(0xFFB8860B).withOpacity(0.15)
                  : const Color(0xFFD4AF37).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isError ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: isError ? const Color(0xFFFFB300) : const Color(0xFFD4AF37),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // ── Message ──
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFF1D592), // goldLight
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
