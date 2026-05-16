import 'package:flutter/material.dart';

class AppColors {
  // ─── The True Black & Gold Palette ─────────────────────────────────────────
  static const Color obsidian = Color(0xFF080808); // Deep black background
  static const Color onyx = Color(0xFF151515);     // Slightly lighter black for cards
  
  static const Color goldDark = Color(0xFFa08840);   // deeper tone of #c6a85c
  static const Color goldMedium = Color(0xFFc6a85c); // requested brand gold
  static const Color goldLight = Color(0xFFdec47e);  // lighter highlight

  // ─── The Magic Remapping ───────────────────────────────────────────────────
  // These map your previous Ivory/Rose variables to the new Black/Gold palette
  static const Color ivory = obsidian; 
  static const Color warmCream = onyx;
  static const Color deepRose = goldMedium;
  static const Color blush = goldDark;
  static const Color goldLeaf = goldLight;
  static const Color deepMaroon = goldDark;
  static const Color charcoal = Colors.white; // Text turns white against black

  // ─── Text Colors ─────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70%
  static const Color textMuted = Color(0x8AFFFFFF); // 54%
  static const Color textFaint = Color(0x61FFFFFF); // 38%
  static const Color textSubtle = Color(0x4DFFFFFF); // 30%

  // ─── Status / Banner Colors ─────────────────────────────────────────────
  static const Color warningRed = Color(0xFFB84A4A);
  static const Color warningRedDark = Color(0xFF8A2E2E);
  static const Color warningBg = Color(0x1FB84A4A);
  static const Color warningBorder = Color(0x66B84A4A);

  static const Color infoBg = Color(0x14FFFFFF);
  static const Color infoBorder = Color(0x33FFFFFF);

  static const Color successGreen = Color(0xFF1F8A4C);
  static const Color errorRed = Color(0xFFB03535);

  // ─── Gradients ─────────────────────────────────────────────────────────────
  
  // A subtle, dark glowing background gradient
  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF050505), Color(0xFF111111), Color(0xFF000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Converts the old rose gradient buttons to pure gold
  static const LinearGradient roseGradient = LinearGradient(
    colors: [goldDark, goldMedium, goldLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldDark, goldMedium, goldLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Bridge for your login/create account pages
  static const Color champagneGold = goldMedium;
}