import 'package:flutter/material.dart';

/// Paleta de colores de HakkinLauncher.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF090C12);
  static const Color surface = Color(0xFF111622);
  static const Color surfaceElevated = Color(0xFF181F2E);
  static const Color surfaceBorder = Color(0xFF232B3E);

  static const Color platinum = Color(0xFFE2E8F0);
  static const Color platinumSheen = Color(0xFFF1F5F9);
  static const Color platinumMuted = Color(0xFF94A3B8);
  static const Color platinumDark = Color(0xFF64748B);

  static const Color celestialBlue = Color(0xFF38BDF8);
  static const Color celestialBlueDark = Color(0xFF0284C7);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF6366F1);

  // Degradados
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x99090C12),
      Color(0xFF090C12),
    ],
  );

  static const LinearGradient platinumButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8FAFC),
      Color(0xFFE2E8F0),
      Color(0xFFCBD5E1),
    ],
  );

  static const LinearGradient cardHoverGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x1A38BDF8),
      Colors.transparent,
    ],
  );
}
