import 'package:flutter/material.dart';

import 'di/app_scope.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'theme/app_theme.dart';

class GanApp extends StatefulWidget {
  const GanApp({super.key});

  @override
  State<GanApp> createState() => _GanAppState();
}

class _GanAppState extends State<GanApp> {
  late final AppDependencies _dependencies;

  @override
  void initState() {
    super.initState();
    _dependencies = AppDependencies.create();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GanApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.gate,
      builder: (context, child) {
        return AppScope(
          authController: _dependencies.authController,
          dashboardController: _dependencies.dashboardController,
          moduleRecordsRepository: _dependencies.moduleRecordsRepository,
          syncLocalStore: _dependencies.syncLocalStore,
          child: child ?? const SizedBox.shrink(),
        );
      },
      onGenerateRoute: (settings) {
        return AppRouter.onGenerateRoute(
          settings,
          _dependencies.authController,
          _dependencies.dashboardController,
        );
      },
    );
  }
}
