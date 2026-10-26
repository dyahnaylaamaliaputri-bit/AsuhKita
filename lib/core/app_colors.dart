


import 'package:flutter/material.dart';

class AppColors {
  AppColors._();


  static const Color primary = Color(0xFF00796B);
  static const Color primaryDark = Color(0xFF004D40);
  static const Color primaryLight = Color(0xFFE0F2F1);


  static const Color secondary = Color(0xFFF57C00);
  static const Color secondaryDark = Color(0xFFE65100);
  static const Color secondaryLight = Color(0xFFFFF3E0);


  static const Color accent1 = Color(0xFF0288D1);
  static const Color accent2 = Color(0xFFFFB300);
  static const Color accent3 = Color(0xFF43A047);
  static const Color accentRed = Color(0xFFE53935);


  static const Color background = Color(0xFFF5F9F8);
  static const Color cardBackground = Colors.white;
  static const Color surfaceLight = Color(0xFFE8F5F1);

  static const Color textPrimary = Color(0xFF14241E);
  static const Color textSecondary = Color(0xFF486156);
  static const Color textHint = Color(0xFF8FA89E);


  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00796B), Color(0xFF0288D1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFF57C00), Color(0xFFFFB300)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient adminGradient = LinearGradient(
    colors: [Color(0xFF004D40), Color(0xFF00796B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient donaturGradient = LinearGradient(
    colors: [Color(0xFF00796B), Color(0xFF43A047)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );


  static const List<String> needCategories = [
    'Semua',
    'Pendidikan',
    'Kesehatan',
    'Nutrisi',
    'Kebutuhan Harian',
    'Perawatan Esensial',
  ];

  static const List<String> needCategoriesInput = [
    'Pendidikan',
    'Kesehatan',
    'Nutrisi',
    'Kebutuhan Harian',
    'Perawatan Esensial',
  ];
}
