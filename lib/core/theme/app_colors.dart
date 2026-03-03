import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors - Industrial & Professional
  static const Color primary = Color(0xFF007AFF); // Status Blue
  static const Color primaryDark = Color(0xFF0056B3);
  static const Color secondary = Color(0xFFFF9500); // Warning Orange
  
  // Neutral Colors - Industrial Contrast
  // Neutral Colors - Industrial Contrast (Dark)
  static const Color background = Color(0xFF121214); // Deep matte black
  static const Color surface = Color(0xFF1C1C1E); // Elevated surface
  static const Color surfaceLight = Color(0xFF2C2C2E); // For borders/dividers
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);

  // Neutral Colors - Industrial Contrast (Light)
  static const Color backgroundLight = Color(0xFFF2F2F7); // iOS System Gray 6
  static const Color surfaceLightMode = Color(0xFFFFFFFF); // Pure white surface
  static const Color borderLight = Color(0xFFD1D1D6); // System Gray 4
  static const Color textPrimaryLight = Color(0xFF000000);
  
  // Accents & State
  static const Color success = Color(0xFF34C759);
  static const Color error = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFF9500);
  
  // Premium Gradients - Subdued/Functional
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF007AFF), Color(0xFF0056B3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1C1C1E), Color(0xFF121214)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
