import 'package:flutter/material.dart';

/// Paleta de color oficial de HakkinLauncher: "Platino & Noche Lunar"
/// Inspirada en la estética industrial oscura de la Epic Games Store y acentos de platino.
class AppColors {
  AppColors._();

  // Fondos y Superficies (Noche Profunda & Obsidiana)
  static const Color background = Color(0xFF090C12); // Fondo base ultra oscuro
  static const Color surface = Color(0xFF111622); // Paneles y tarjetas
  static const Color surfaceElevated = Color(0xFF181F2E); // Elementos elevados / hover
  static const Color surfaceBorder = Color(0xFF232B3E); // Bordes sutiles

  // Acentos Platino & Lunares
  static const Color platinum = Color(0xFFE2E8F0); // Platino puro brillante
  static const Color platinumSheen = Color(0xFFF1F5F9); // Reflejo blanco platino
  static const Color platinumMuted = Color(0xFF94A3B8); // Plata lunar secundaria
  static const Color platinumDark = Color(0xFF64748B); // Gris platino apagado

  // Acentos Celestiales / Interactivos
  static const Color celestialBlue = Color(0xFF38BDF8); // Enlaces, progreso y foco
  static const Color celestialBlueDark = Color(0xFF0284C7);

  // Estados
  static const Color success = Color(0xFF10B981); // Listo para jugar / Instalado
  static const Color warning = Color(0xFFF59E0B); // Actualización disponible
  static const Color error = Color(0xFFEF4444); // Fallo de hash / Error
  static const Color info = Color(0xFF6366F1); // Información / Staging

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
