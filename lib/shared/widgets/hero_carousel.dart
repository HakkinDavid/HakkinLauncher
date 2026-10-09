import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../features/catalog/data/models/app_entry.dart';
import 'hakkin_button.dart';
import 'status_badge.dart';

class HeroCarousel extends StatelessWidget {
  final AppEntry featuredApp;
  final VoidCallback onDetailsPressed;

  const HeroCarousel({
    super.key,
    required this.featuredApp,
    required this.onDetailsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (featuredApp.assets.banner != null &&
                featuredApp.assets.banner!.startsWith('http'))
              Image.network(
                featuredApp.assets.banner!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
            else
              _buildPlaceholder(),

            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xF0090C12),
                    Color(0xCC090C12),
                    Color(0x33090C12),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.45, 0.75, 1.0],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      StatusBadge.tag(featuredApp.category),
                      const SizedBox(width: 8),
                      Text(
                        'DESTACADO',
                        style: TextStyle(
                          color: AppColors.celestialBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    featuredApp.title,
                    style: const TextStyle(
                      color: AppColors.platinum,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 500,
                    child: Text(
                      featuredApp.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.platinumMuted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      HakkinButton(
                        text: 'Ver en la Tienda',
                        icon: Icons.explore_outlined,
                        variant: HakkinButtonVariant.primaryPlatinum,
                        onPressed: onDetailsPressed,
                      ),
                      const SizedBox(width: 12),
                      HakkinButton(
                        text: 'v${featuredApp.latestVersion}',
                        variant: HakkinButtonVariant.secondary,
                        onPressed: null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (featuredApp.id == 'dev.bonsanbec.hakkinlauncher' ||
        featuredApp.id == 'hakkin_launcher' ||
        featuredApp.id == 'HakkinLauncher') {
      return Image.asset(AppConstants.appIconPath, fit: BoxFit.cover);
    }
    return Container(
      color: AppColors.surfaceElevated,
      child: const Center(
        child: Icon(Icons.auto_awesome, size: 64, color: AppColors.surfaceBorder),
      ),
    );
  }
}
