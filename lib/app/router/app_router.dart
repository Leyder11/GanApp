import 'package:flutter/material.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/pages/auth_gate_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/dashboard/presentation/controllers/dashboard_controller.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import 'app_routes.dart';

class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings,
    AuthController authController,
    DashboardController dashboardController,
  ) {
    switch (settings.name) {
      case AppRoutes.gate:
        return MaterialPageRoute<void>(
          builder: (_) => AuthGatePage(authController: authController),
          settings: settings,
        );
      case AppRoutes.login:
        return MaterialPageRoute<void>(
          builder: (_) => LoginPage(authController: authController),
          settings: settings,
        );
      case AppRoutes.register:
        return MaterialPageRoute<void>(
          builder: (_) => RegisterPage(authController: authController),
          settings: settings,
        );
      case AppRoutes.dashboard:
        if (!authController.isAuthenticated) {
          return MaterialPageRoute<void>(
            builder: (_) => LoginPage(authController: authController),
            settings: const RouteSettings(name: AppRoutes.login),
          );
        }

        return MaterialPageRoute<void>(
          builder: (_) => DashboardPage(
            authController: authController,
            controller: dashboardController,
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => LoginPage(authController: authController),
          settings: const RouteSettings(name: AppRoutes.login),
        );
    }
  }
}
