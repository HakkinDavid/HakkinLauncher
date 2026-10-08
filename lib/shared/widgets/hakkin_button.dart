import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum HakkinButtonVariant {
  primaryPlatinum,
  secondary,
  successPlay,
  danger,
}

class HakkinButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final HakkinButtonVariant variant;
  final double? width;
  final double height;

  const HakkinButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.variant = HakkinButtonVariant.primaryPlatinum,
    this.width,
    this.height = 44,
  });

  @override
  State<HakkinButton> createState() => _HakkinButtonState();
}

class _HakkinButtonState extends State<HakkinButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color borderColor;
    Gradient? gradient;
    Color? solidColor;

    switch (widget.variant) {
      case HakkinButtonVariant.primaryPlatinum:
        textColor = const Color(0xFF090C12);
        borderColor = Colors.transparent;
        gradient = widget.onPressed != null
            ? (_isHovered
                ? const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFE2E8F0)],
                  )
                : AppColors.platinumButtonGradient)
            : const LinearGradient(
                colors: [Color(0xFF64748B), Color(0xFF475569)],
              );
        break;

      case HakkinButtonVariant.secondary:
        textColor = AppColors.platinum;
        borderColor = _isHovered ? AppColors.platinum : AppColors.surfaceBorder;
        solidColor = _isHovered ? AppColors.surfaceElevated : AppColors.surface;
        break;

      case HakkinButtonVariant.successPlay:
        textColor = Colors.white;
        borderColor = Colors.transparent;
        solidColor = _isHovered ? const Color(0xFF059669) : AppColors.success;
        break;

      case HakkinButtonVariant.danger:
        textColor = Colors.white;
        borderColor = Colors.transparent;
        solidColor = _isHovered ? const Color(0xFFDC2626) : AppColors.error;
        break;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onPressed != null && !widget.isLoading
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: solidColor,
            gradient: gradient,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: _isHovered && widget.onPressed != null
                ? [
                    BoxShadow(
                      color: widget.variant == HakkinButtonVariant.primaryPlatinum
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: textColor),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
