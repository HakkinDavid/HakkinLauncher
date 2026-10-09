import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../features/catalog/data/models/app_entry.dart';
import 'status_badge.dart';

class AppCard extends StatefulWidget {
  final AppEntry app;
  final bool isInstalled;
  final bool hasUpdate;
  final bool isRunning;
  final VoidCallback onTap;

  const AppCard({
    super.key,
    required this.app,
    this.isInstalled = false,
    this.hasUpdate = false,
    this.isRunning = false,
    required this.onTap,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? AppColors.celestialBlue : AppColors.surfaceBorder,
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.celestialBlue.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster Art de la Aplicación
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.app.assets.poster != null &&
                          widget.app.assets.poster!.startsWith('http'))
                        Image.network(
                          widget.app.assets.poster!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      else
                        _buildPlaceholder(),

                      // Gradiente de sombra
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x99000000),
                            ],
                          ),
                        ),
                      ),

                      // Status Badge en esquina superior derecha
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _buildStatusPill(),
                      ),

                      // Categoría en esquina superior izquierda
                      Positioned(
                        top: 10,
                        left: 10,
                        child: StatusBadge.tag(widget.app.category),
                      ),
                    ],
                  ),
                ),
              ),

              // Metadatos y Título
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.app.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.platinum,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.app.developer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.platinumMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Barra inferior de compatibilidad
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'v${widget.app.latestVersion}',
                          style: const TextStyle(
                            color: AppColors.platinumDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            if (widget.app.platforms.containsKey('windows-x64'))
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.window, size: 13, color: AppColors.platinumMuted),
                              ),
                            if (widget.app.platforms.containsKey('macos-arm64') ||
                                widget.app.platforms.containsKey('macos-x64'))
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.apple, size: 14, color: AppColors.platinumMuted),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    if (widget.isRunning) {
      return StatusBadge.running();
    } else if (widget.hasUpdate) {
      return StatusBadge.updateAvailable();
    } else if (widget.isInstalled) {
      return StatusBadge.installed();
    }
    return const SizedBox.shrink();
  }

  Widget _buildPlaceholder() {
    if (widget.app.id == 'com.hakkin.launcher' || widget.app.id == 'hakkin_launcher') {
      return Image.asset(AppConstants.appIconPath, fit: BoxFit.cover);
    }
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Icon(
          widget.app.category == 'game' ? Icons.sports_esports : Icons.apps,
          size: 48,
          color: AppColors.surfaceBorder,
        ),
      ),
    );
  }
}
