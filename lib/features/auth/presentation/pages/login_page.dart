import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await widget.authController.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.authController.errorMessage ?? 'Error al iniciar sesion',
        ),
      ),
    );
  }

  Future<void> _onForgotPassword() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
    final email = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recuperar contrasena'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electronico',
              hintText: 'usuario@correo.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Enviar enlace'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (!mounted || email == null || email.isEmpty) {
      return;
    }

    final success = await widget.authController.requestPasswordReset(
      email: email,
    );
    if (!mounted) {
      return;
    }

    final message = success
        ? 'Si el correo existe, se envio el enlace de recuperacion.'
        : (widget.authController.errorMessage ??
              'No se pudo enviar el enlace.');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: ListView(
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.agriculture_rounded,
                        color: AppColors.primary,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'GanApp',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Iniciar sesion',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Controla tu finca sin enredos.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: AppColors.deep.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Correo electronico',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Ingresa tu correo';
                                }
                                if (!value.contains('@')) {
                                  return 'Correo invalido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa tu contraseña';
                                }
                                if (value.length < 8) {
                                  return 'Minimo 8 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: widget.authController.isLoading
                                    ? null
                                    : _onForgotPassword,
                                child: const Text('Recuperar contraseña'),
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedBuilder(
                              animation: widget.authController,
                              builder: (context, _) {
                                return ElevatedButton(
                                  onPressed: widget.authController.isLoading
                                      ? null
                                      : _onSubmit,
                                  child: widget.authController.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Entrar'),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton(
                                onPressed: widget.authController.isLoading
                                    ? null
                                    : () => Navigator.of(
                                        context,
                                      ).pushNamed(AppRoutes.register),
                                child: const Text(
                                  '¿No tienes cuenta? Registrate',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
