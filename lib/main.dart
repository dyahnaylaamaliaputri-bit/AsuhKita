// Letak file: mobile/lib/main.dart
// Fungsi: Titik masuk utama (Entry point) aplikasi Flutter AsuhKita, inisialisasi State Provider, dan Routing Layar (Tema Kontras & Tegas, Tanpa Ungu)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_colors.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'widgets/main_navigation.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inisialisasi Notifikasi Lokal (PBI-055, FR-40, FR-41)
  await NotificationService().initialize();
  // Stub FCM (PBI-056, FR-42)
  NotificationService().initFcmStub();
  runApp(const AsuhKitaApp());
}

class AsuhKitaApp extends StatelessWidget {
  const AsuhKitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'AsuhKita Mobile',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            tertiary: AppColors.accent1,
            surface: AppColors.background,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2EEE8), width: 1),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor: AppColors.primary,
            unselectedItemColor: Color(0xFF789086),
            backgroundColor: Colors.white,
            elevation: 8,
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

// Widget Penjaga Sesi (Auth Gate) - Cek Persistent Session
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Jika sedang loading pengecekan sesi tersimpan saat splash/buka app
        if (auth.isLoading && !auth.isAuthenticated) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        // Jika sudah terautentikasi (ada sesi token aktif), langsung masuk ke MainNavigation
        // Jika aplikasi ditutup tapi belum logout, session tetap aktif
        if (auth.isAuthenticated) {
          return const MainNavigation();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
