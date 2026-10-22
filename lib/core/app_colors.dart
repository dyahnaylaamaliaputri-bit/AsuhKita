// Letak file: mobile/lib/core/app_colors.dart
// Fungsi: Konstanta warna tema aplikasi AsuhKita (Revisi Palet Warna)

import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Prevent instantiation

  // === Primary & Secondary ===
  static const Color primary = Color(0xFFB7A6F0);       // Lavender
  static const Color primaryDark = Color(0xFF9B86E0);    // Lavender darker
  static const Color secondary = Color(0xFFF9B9D3);      // Pink
  static const Color secondaryDark = Color(0xFFE8A0BC);  // Pink darker

  // === Accents ===
  static const Color accent1 = Color(0xFFA6E3CF);        // Mint
  static const Color accent2 = Color(0xFFFFE9A8);         // Lemon Cream
  static const Color accent3 = Color(0xFFA9CDF5);         // Baby Blue

  // === Background & Text ===
  static const Color background = Color(0xFFFBF9FF);      // Pearl
  static const Color textPrimary = Color(0xFF2E2A47);      // Indigo Dark
  static const Color textSecondary = Color(0xFF6E6A87);    // Lighter indigo
  static const Color textHint = Color(0xFFABA7C3);         // Hint color

  // === Surface & Cards ===
  static const Color cardBackground = Colors.white;
  static const Color surfaceLight = Color(0xFFF3F0FF);     // Light lavender

  // === Gradients ===
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFB7A6F0), Color(0xFFA9CDF5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFF9B9D3), Color(0xFFFFE9A8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient adminGradient = LinearGradient(
    colors: [Color(0xFF9B86E0), Color(0xFFB7A6F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient donaturGradient = LinearGradient(
    colors: [Color(0xFFB7A6F0), Color(0xFFA6E3CF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // === Kategori Kebutuhan (Unified) ===
  static const List<String> needCategories = [
    'Semua',
    'Pendidikan',
    'Kesehatan',
    'Nutrisi',
    'Kebutuhan Harian',
    'Perawatan Esensial',
  ];

  // Only for filter (without 'Semua')
  static const List<String> needCategoriesInput = [
    'Pendidikan',
    'Kesehatan',
    'Nutrisi',
    'Kebutuhan Harian',
    'Perawatan Esensial',
  ];
}
