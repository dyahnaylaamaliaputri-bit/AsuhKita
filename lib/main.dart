// Letak file: mobile/lib/main.dart
// Fungsi: Titik masuk utama (Entry point) aplikasi Flutter AsuhKita, inisialisasi State Provider, dan Routing Layar

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
          scaffoldBackgroundColor: const Color(0xFFFBF9FF), // Pearl
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFB7A6F0),
            primary: const Color(0xFFB7A6F0),       // Lavender
            secondary: const Color(0xFFF9B9D3),     // Pink
            tertiary: const Color(0xFFA6E3CF),       // Mint
            surface: const Color(0xFFFBF9FF),        // Pearl
            onPrimary: Colors.white,
            onSurface: const Color(0xFF2E2A47),      // Indigo Dark
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: Color(0xFFB7A6F0),     // Lavender
            foregroundColor: Colors.white,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 1.5,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 1,
              backgroundColor: const Color(0xFFB7A6F0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor: Color(0xFFB7A6F0),
            unselectedItemColor: Color(0xFF9E9E9E),
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

// Widget Penjaga Sesi (Auth Gate)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Jika sudah terautentikasi (ada sesi token aktif), masuk ke MainNavigation (5 Tab)
        // Jika belum, tampilkan LoginScreen
        if (auth.isAuthenticated) {
          return const MainNavigation();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
