// Letak file: mobile/lib/core/app_colors.dart
// Fungsi: Konstanta warna tema aplikasi AsuhKita (Palet Tegas, Kontras, Menarik, Ramah Anak, Tanpa Warna Ungu)

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // === Primary: Deep Ocean Emerald / Teal Pekat (Tegas, Berwibawa, Kontras Tinggi) ===
  static const Color primary = Color(0xFF00796B);       // Deep Teal Pekat
  static const Color primaryDark = Color(0xFF004D40);   // Dark Emerald
  static const Color primaryLight = Color(0xFFE0F2F1);  // Mint Pastel Lembut

  // === Secondary: Vibrant Sunset Tangerine / Oranye Hangat (Ceria, Mencolok, Khas Anak-anak) ===
  static const Color secondary = Color(0xFFF57C00);     // Warm Tangerine Pekat
  static const Color secondaryDark = Color(0xFFE65100); // Deep Orange
  static const Color secondaryLight = Color(0xFFFFF3E0);// Peach Lembut

  // === Aksen Tambahan: Kontras & Ceria ===
  static const Color accent1 = Color(0xFF0288D1);       // Cerulean Sky Blue (Info / Air)
  static const Color accent2 = Color(0xFFFFB300);       // Sunflower Gold (Bintang / Poin)
  static const Color accent3 = Color(0xFF43A047);       // Apple Green (Sukses / Tunas)
  static const Color accentRed = Color(0xFFE53935);     // Crimson Red (Peringatan / Hapus)

  // === Background & Teks ===
  static const Color background = Color(0xFFF5F9F8);    // Clean Pearl Mint Lembut
  static const Color cardBackground = Colors.white;
  static const Color surfaceLight = Color(0xFFE8F5F1);   // Light Mint Surface

  static const Color textPrimary = Color(0xFF14241E);    // Hijau Hitam Pekat (Sangat Jelas & Tajam)
  static const Color textSecondary = Color(0xFF486156);  // Medium Slate Green
  static const Color textHint = Color(0xFF8FA89E);       // Muted Mint Grey

  // === Gradients Menarik (Tanpa Warna Ungu) ===
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

  // === Kategori Kebutuhan (Unified) ===
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
