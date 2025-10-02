import 'package:flutter/material.dart';

class AppColors {
  // Primary gradient colors from the design
  static const Color primaryGreen = Color(0xFF4A9B8E);
  static const Color primaryGreenDark = Color(0xFF2D6B5F);
  static const Color primaryGreenLight = Color(0xFF5BA59A);
  
  // Accent colors
  static const Color accentOrange = Color(0xFFFF8C42);
  static const Color accentYellow = Color(0xFFFFB347);
  
  // Background colors
  static const Color backgroundLight = Color(0xFFF8FAF9);
  static const Color backgroundDark = Color(0xFF1A2F2A);
  
  // Text colors
  static const Color textPrimary = Color(0xFF2D3748);
  static const Color textSecondary = Color(0xFF718096);
  static const Color textLight = Color(0xFFFFFFFF);
  
  // Button colors
  static const Color buttonPrimary = Color(0xFF4A9B8E);
  static const Color buttonSecondary = Color(0xFFE2E8F0);
  static const Color buttonGoogle = Color(0xFFFFFFFF);
  
  // Additional colors
  static const Color success = Color(0xFF48BB78);
  static const Color error = Color(0xFFF56565);
  static const Color warning = Color(0xFFED8936);
  static const Color info = Color(0xFF4299E1);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF6BB8A8),
      Color(0xFF4A9B8E),
      Color(0xFF2D6B5F),
    ],
  );
  
  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF81E6D9),
      Color(0xFF4FD1C7),
      Color(0xFF38B2AC),
    ],
  );
}
