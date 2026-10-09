import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadge.installed() {
    return const StatusBadge(
      label: 'INSTALADO',
      backgroundColor: Color(0x2610B981),
      textColor: AppColors.success,
      icon: Icons.check_circle_outline,
    );
  }

  factory StatusBadge.updateAvailable() {
    return const StatusBadge(
      label: 'ACTUALIZAR',
      backgroundColor: Color(0x26F59E0B),
      textColor: AppColors.warning,
      icon: Icons.arrow_circle_up,
    );
  }

  factory StatusBadge.running() {
    return const StatusBadge(
      label: 'EN EJECUCIÓN',
      backgroundColor: Color(0x2638BDF8),
      textColor: AppColors.celestialBlue,
      icon: Icons.play_arrow,
    );
  }

  factory StatusBadge.anomaly() {
    return const StatusBadge(
      label: 'ANOMALÍA',
      backgroundColor: Color(0x26EF4444),
      textColor: Color(0xFFF87171),
      icon: Icons.warning_amber_rounded,
    );
  }

  factory StatusBadge.tag(String tag) {
    return StatusBadge(
      label: tag.toUpperCase(),
      backgroundColor: AppColors.surfaceElevated,
      textColor: AppColors.platinumMuted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
