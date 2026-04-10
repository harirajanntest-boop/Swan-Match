import 'package:flutter/material.dart';

class AppColors {
  // ─── The True Black & Gold Palette ─────────────────────────────────────────
  static const Color obsidian = Color(0xFF080808); // Deep black background
  static const Color onyx = Color(0xFF151515);     // Slightly lighter black for cards
  
  static const Color goldDark = Color(0xFFB8860B);
  static const Color goldMedium = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF1D592);

  // ─── The Magic Remapping ───────────────────────────────────────────────────
  // These map your previous Ivory/Rose variables to the new Black/Gold palette
  static const Color ivory = obsidian; 
  static const Color warmCream = onyx;
  static const Color deepRose = goldMedium;
  static const Color blush = goldDark;
  static const Color goldLeaf = goldLight;
  static const Color deepMaroon = goldDark;
  static const Color charcoal = Colors.white; // Text turns white against black

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