import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF4F46E5);
  static const Color accent = Color(0xFFA7B0E0);
  static const Color panel = Color(0xFF1F2937);
  static const Color deep = Color(0xFFF1F5F9);

  static const Color surfaceSoft = Color(0xFF253246);
  static const Color textMain = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFFA7B0E0);
  static const Color background = Color(0xFF182232);
  static const Color panelSoft = Color(0xFF2C3A4F);
  static const Color stroke = Color(0x4DF1F5F9);

  static const LinearGradient appGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F2937), Color(0xFF253246), Color(0xFF182232)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFFA7B0E0), Color(0xFF1F2937)],
  );
}
