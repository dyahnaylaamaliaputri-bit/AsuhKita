import '../../data/local_db.dart';
// Letak file: mobile/lib/features/home/home_screen.dart
// Fungsi: Layar Beranda utama dengan ringkasan status dan kartu akses ke seluruh fitur aplikasi AsuhKita (PBI-009, Bab 6.7)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';
import '../ledger/ledger_screen.dart';
import '../map/map_screen.dart';
import '../schedule/schedule_screen.dart';
import '../steps_game/steps_and_game_screen.dart';
import '../ai_assistant/ai_assistant_screen.dart';
import '../admin/admin_panel_screen.dart';
import '../donation/donation_history_screen.dart';
import 'iot_donation_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isNotificationActive = true;
  int _sponsoredCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotificationState();
  }

  Future<void> _loadNotificationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localDonations = await LocalDatabase().getCachedDonations();
      final count = localDonations.isNotEmpty
          ? localDonations.length
          : (prefs.getInt('asuhkita_user_sponsored_count') ?? 0);
      final notifActive = prefs.getBool('asuhkita_notif_active') ?? true;

      if (mounted) {
        setState(() {
          _isNotificationActive = notifActive;
          _sponsoredCount = count;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleNotification() async {
    final newState = !_isNotificationActive;
    setState(() => _isNotificationActive = newState);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('asuhkita_notif_active', newState);
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newState
                ? '🔔 Notifikasi Lokal DIAKTIFKAN: Pengingat donasi & pembaruan anak asuh aktif!'
                : '🔕 Notifikasi Lokal DINONAKTIFKAN.',
          ),
          backgroundColor: newState ? Colors.teal : Colors.grey.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('AsuhKita'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isNotificationActive ? Icons.notifications_active : Icons.notifications_off_outlined,
              color: _isNotificationActive ? Colors.amberAccent : Colors.white70,
            ),
            tooltip: _isNotificationActive ? 'Notifikasi Aktif' : 'Notifikasi Mati',
            onPressed: _toggleNotification,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Sambutan Pengguna
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade700, Colors.teal.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.teal.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, ${auth.userName.isNotEmpty ? auth.userName : 'Donatur Peduli'} 👋',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Terima kasih telah membersamai mimpi dan masa depan anak-anak panti asuhan melalui transparansi teknologi.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Ringkasan Cepat Dinamis
            Row(
              children: [
                _buildMetricCard('Anak Asuh', '$_sponsoredCount Anak', Icons.face, Colors.blue),
                const SizedBox(width: 12),
                _buildMetricCard('Transparansi', '100% SHA-256', Icons.security, Colors.green),
                const SizedBox(width: 12),
                _buildMetricCard('IoT Panti', 'Aktif', Icons.sensors, Colors.orange),
              ],
            ),
            const SizedBox(height: 24),

            // Pintasan Fitur Utama AsuhKita (Bab 6.7 SRS Mockup)
            const Text(
              'Menu & Fasilitas Unggulan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _buildFeatureCard(
                  context,
                  title: 'Sponsori Anak',
                  subtitle: 'Cari & filter paket anak',
                  icon: Icons.volunteer_activism,
                  color: Colors.teal,
                  onTap: () {
                    if (widget.onNavigateTab != null) {
                      widget.onNavigateTab!(1); // Pindah ke tab Sponsor
                    }
                  },
                ),
                _buildFeatureCard(
                  context,
                  title: 'Blockchain Ledger',
                  subtitle: 'Hash chain & verifikasi',
                  icon: Icons.link,
                  color: Colors.deepPurple,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerScreen())),
                ),
                _buildFeatureCard(
                  context,
                  title: 'Peta Panti LBS',
                  subtitle: 'Jarak & check-in 100m',
                  icon: Icons.map,
                  color: Colors.blue,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())),
                ),
                _buildFeatureCard(
                  context,
                  title: 'Jadwal 4 Zona',
                  subtitle: 'WIB, WITA, WIT, London',
                  icon: Icons.schedule,
                  color: Colors.indigo,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduleScreen())),
                ),
                _buildFeatureCard(
                  context,
                  title: 'Sensor & Game',
                  subtitle: 'Langkah & Gyroscope',
                  icon: Icons.sports_esports,
                  color: Colors.amber.shade800,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StepsAndGameScreen())),
                ),
                _buildFeatureCard(
                  context,
                  title: 'Sahabat Asuh AI',
                  subtitle: 'Surat & ringkasan LLM',
                  icon: Icons.auto_awesome,
                  color: Colors.cyan.shade700,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantScreen())),
                ),
                _buildFeatureCard(
                  context,
                  title: 'Kotak Amal IoT',
                  subtitle: 'Deteksi sensor ESP32',
                  icon: Icons.savings,
                  color: Colors.pink.shade700,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IotDonationScreen())),
                ),
                _buildFeatureCard(
                  context,
                  title: 'Riwayat & Sync',
                  subtitle: 'Offline queue SQLite',
                  icon: Icons.history,
                  color: Colors.green.shade700,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DonationHistoryScreen())),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Panel Khusus Pengurus Panti jika role admin (FR-06, PBI-039)
            if (auth.userRole == 'admin_panti') ...[
              const Text(
                'Menu Khusus Pengurus Panti',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.admin_panel_settings, color: Colors.white)),
                  title: const Text('Buka Panel Admin Panti', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Kelola anak asuh dan unggah bukti kuitansi belanja untuk blok ledger.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
