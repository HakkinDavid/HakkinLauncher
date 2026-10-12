import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_technical_strings.dart';
import 'core/platform/background_check_service.dart';
import 'core/theme/app_theme.dart';
import 'features/app_detail/presentation/screens/app_detail_screen.dart';
import 'features/catalog/presentation/screens/store_screen.dart';
import 'features/library/presentation/screens/library_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'shared/layout/shell_navigation_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppTechnicalStrings.routeRoot,
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return ShellNavigationScaffold(child: child);
      },
      routes: [
        GoRoute(
          path: AppTechnicalStrings.routeRoot,
          builder: (context, state) => const StoreScreen(),
        ),
        GoRoute(
          path: AppTechnicalStrings.routeLibrary,
          builder: (context, state) => const LibraryScreen(),
        ),
        GoRoute(
          path: AppTechnicalStrings.routeSettings,
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: AppTechnicalStrings.routeAppDetail,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters[AppTechnicalStrings.paramId] ??
            AppTechnicalStrings.empty;
        return AppDetailScreen(appId: id);
      },
    ),
  ],
);

class HakkinLauncherApp extends StatefulWidget {
  const HakkinLauncherApp({super.key});

  @override
  State<HakkinLauncherApp> createState() => _HakkinLauncherAppState();
}

class _HakkinLauncherAppState extends State<HakkinLauncherApp> {
  void _onRouteChanged() {
    BackgroundCheckService.instance.recordUserNavigation();
  }

  @override
  void initState() {
    super.initState();
    appRouter.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    appRouter.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) =>
          BackgroundCheckService.instance.recordUserNavigation(),
      onPointerMove: (_) =>
          BackgroundCheckService.instance.recordUserNavigation(),
      onPointerHover: (_) =>
          BackgroundCheckService.instance.recordUserNavigation(),
      onPointerSignal: (_) =>
          BackgroundCheckService.instance.recordUserNavigation(),
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (_, __) {
          BackgroundCheckService.instance.recordUserNavigation();
          return KeyEventResult.ignored;
        },
        child: MaterialApp.router(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
