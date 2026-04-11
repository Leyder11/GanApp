import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../controllers/auth_controller.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.authController.restoreSession();
      if (!mounted) {
        return;
      }

      final target = widget.authController.isAuthenticated
          ? AppRoutes.dashboard
          : AppRoutes.login;

      Navigator.of(context).pushReplacementNamed(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
