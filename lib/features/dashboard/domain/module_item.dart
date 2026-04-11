import 'package:flutter/material.dart';

class ModuleItem {
  const ModuleItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.resourcePath,
  });

  final IconData icon;
  final String title;
  final String description;
  final String resourcePath;
}
