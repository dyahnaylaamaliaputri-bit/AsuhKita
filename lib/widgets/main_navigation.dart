// Letak file: mobile/lib/widgets/main_navigation.dart
// Fungsi: Kerangka Navigasi Bawah Tab Dinamis (Donatur vs Admin Panti) dan Dialog Konfirmasi Logout (PBI-009, PBI-013, FR-10, FR-14)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/auth/auth_provider.dart';
import '../features/home/home_screen.dart';
import '../features/sponsor/sponsor_screen.dart';
import '../features/admin/admin_panel_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/feedback/feedback_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  int _profileKeyCounter = 0;

  void _navigateToTab(int index) {
    setState(() {
      if (index == 2) {
        _profileKeyCounter++;
      }
      _currentIndex = index;
    });
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.logout, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Konfirmasi Keluar'),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun AsuhKita? Sesi Anda akan dicabut secara aman.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              auth.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isAdmin = auth.userRole == 'admin_panti';

    // Jika admin: Ganti tab sponsor menjadi kelola panti (Revisi instruksi: navigasi sponsor dihapus untuk admin)
    final List<Widget> pages = isAdmin
        ? [
            HomeScreen(onNavigateTab: _navigateToTab),
            const AdminPanelScreen(),
            ProfileScreen(key: ValueKey('profile_admin_$_profileKeyCounter')),
            const FeedbackScreen(),
            const SizedBox.shrink(),
          ]
        : [
            HomeScreen(onNavigateTab: _navigateToTab),
            const SponsorScreen(),
            ProfileScreen(key: ValueKey('profile_donatur_$_profileKeyCounter')),
            const FeedbackScreen(),
            const SizedBox.shrink(),
          ];

    final List<BottomNavigationBarItem> items = isAdmin
        ? const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Icon(Icons.admin_panel_settings),
              label: 'Kelola Panti',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.rate_review_outlined),
              activeIcon: Icon(Icons.rate_review),
              label: 'Saran & Kesan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.logout, color: Colors.redAccent),
              label: 'Keluar',
            ),
          ]
        : const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.volunteer_activism_outlined),
              activeIcon: Icon(Icons.volunteer_activism),
              label: 'Sponsor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.rate_review_outlined),
              activeIcon: Icon(Icons.rate_review),
              label: 'Saran & Kesan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.logout, color: Colors.redAccent),
              label: 'Keluar',
            ),
          ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFB7A6F0),
        unselectedItemColor: Colors.grey.shade600,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        onTap: (index) {
          if (index == 4) {
            _showLogoutDialog();
          } else {
            setState(() {
              if (index == 2) {
                _profileKeyCounter++;
              }
              _currentIndex = index;
            });
          }
        },
        items: items,
      ),
    );
  }
}
