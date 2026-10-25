// Letak file: mobile/lib/features/home/home_screen.dart
// Fungsi: Layar Beranda utama dengan ringkasan status dan kartu akses ke seluruh fitur aplikasi AsuhKita (PBI-009, Bab 6.7)
// Mendukung pemisahan antarmuka Donatur vs Admin Panti secara ketat sesuai instruksi revisi.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';
import '../auth/auth_provider.dart';
import '../ledger/ledger_screen.dart';
import '../map/map_screen.dart';
import '../schedule/schedule_screen.dart';
import '../steps_game/steps_and_game_screen.dart';
import '../ai_assistant/ai_assistant_screen.dart';
import '../admin/admin_panel_screen.dart';
import '../admin/donation_tracking_screen.dart';
import '../admin/finance_dashboard_screen.dart';
import '../communication/family_room_screen.dart';
import '../sponsor/child_detail_screen.dart';
import 'iot_donation_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _sponsoredCount = 0;
  int _totalPlatformChildren = 0;
  int _totalPlatformDonors = 0;
  int _totalAdminFunds = 0;

  @override
  void initState() {
    super.initState();
    HomeScreen.refreshNotifier.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    HomeScreen.refreshNotifier.removeListener(_loadData);
    super.dispose();
  }

  String _formatCompactRupiah(int val) {
    if (val >= 1000000000) {
      return 'Rp ${(val / 1000000000).toStringAsFixed(1)}M';
    } else if (val >= 1000000) {
      return 'Rp ${(val / 1000000).toStringAsFixed(1)}Jt';
    } else if (val >= 1000) {
      return 'Rp ${(val / 1000).toStringAsFixed(0)}Rb';
    }
    return 'Rp $val';
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localDb = LocalDatabase();
      final localDonations = await localDb.getCachedDonations();

      // ============================================================
      // INTEGRASI: Ambil jumlah anak dari sumber SAMA seperti Ruang Kasih & Sponsor
      // Sumber: Supabase API → SQLite cached_children + new_children
      // ============================================================
      int totalKids = 0;
      try {
        // 1. Coba ambil dari Supabase (sumber utama, sama seperti sponsor & ruang kasih)
        final res = await DioClient().dio.get('/children');
        if (res.statusCode == 200) {
          List<dynamic> apiChildren = [];
          if (res.data is List && (res.data as List).isNotEmpty) {
            apiChildren = res.data as List;
          } else if (res.data is Map && res.data['data'] is List) {
            apiChildren = res.data['data'] as List;
          }
          if (apiChildren.isNotEmpty) {
            totalKids = apiChildren.length;
            // Cache ke SQLite supaya sinkron
            await localDb.cacheChildren(
              List<Map<String, dynamic>>.from(apiChildren),
            );
          }
        }
      } catch (_) {}

      // 2. Fallback: hitung dari SQLite lokal (sama seperti Ruang Kasih)
      if (totalKids == 0) {
        final cachedKids = await localDb.getCachedChildren();
        final newKids = await localDb.getNewChildren();
        // Deduplicate berdasarkan alias (sama seperti Ruang Kasih)
        final seen = <String>{};
        final all = [...cachedKids, ...newKids];
        final uniqueKids = all.where((c) {
          final name = (c['alias'] ?? c['name'] ?? '').toString().toLowerCase();
          if (seen.contains(name) || name.isEmpty) return false;
          seen.add(name);
          return true;
        }).toList();
        totalKids = uniqueKids.length;
      }

      // ============================================================
      // TOTAL DANA & DONATUR TERINTEGRASI SUPABASE + SQLITE (NON STATIS)
      // ============================================================
      final donorSet = <String>{};
      int totalFundsCalculated = 0;

      // 1. Dari donasi lokal SQLite
      for (var d in localDonations) {
        final amt = (d['amount_idr'] is num) ? (d['amount_idr'] as num).toInt() : 0;
        totalFundsCalculated += amt;
        final donorKey = (d['donor_name'] ?? d['sponsorship_id'] ?? '').toString().trim();
        if (donorKey.isNotEmpty) {
          donorSet.add(donorKey.toLowerCase());
        }
      }

      // 2. Coba sinkronisasi riwayat donasi dari Supabase API
      try {
        final donRes = await DioClient().dio.get('/donations');
        if (donRes.statusCode == 200) {
          List<dynamic> apiDonations = [];
          if (donRes.data is List) {
            apiDonations = donRes.data as List;
          } else if (donRes.data is Map && donRes.data['data'] is List) {
            apiDonations = donRes.data['data'] as List;
          }
          for (var ad in apiDonations) {
            final amt = (ad['amount_idr'] is num) ? (ad['amount_idr'] as num).toInt() : 0;
            // Jika belum terhitung di lokal
            final donId = ad['id']?.toString() ?? '';
            final alreadyInLocal = localDonations.any((ld) => ld['id']?.toString() == donId);
            if (!alreadyInLocal && amt > 0) {
              totalFundsCalculated += amt;
              final dName = (ad['donor_name'] ?? ad['donor_email'] ?? '').toString().trim();
              if (dName.isNotEmpty) {
                donorSet.add(dName.toLowerCase());
              }
            }
          }
        }
      } catch (_) {}

      final totalDonors = donorSet.isNotEmpty ? donorSet.length : (localDonations.isNotEmpty ? 1 : 0);

      // Hitung anak asuh yang didampingi oleh donatur yang SEDANG LOGIN (dari riwayat donasi/sponsorship)
      String userEmail = '';
      String userName = '';
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        userEmail = auth.userEmail.toLowerCase().trim();
        userName = auth.userName.toLowerCase().trim();
      } catch (_) {}

      final sponsoredKidSet = <String>{};
      if (userEmail.isNotEmpty || userName.isNotEmpty) {
        for (var d in localDonations) {
          final dEmail = (d['donor_email'] ?? '').toString().toLowerCase().trim();
          final dName = (d['donor_name'] ?? '').toString().toLowerCase().trim();
          final isMatch = (userEmail.isNotEmpty && dEmail == userEmail) ||
              (userName.isNotEmpty && (dName == userName || dName == userEmail));
          if (isMatch) {
            final alias = (d['child_alias'] ?? '').toString().trim();
            if (alias.isNotEmpty) {
              sponsoredKidSet.add(alias.toLowerCase());
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          // Donatur: jumlah anak asuh donatur ini (0 jika belum mendampingi anak asuh)
          _sponsoredCount = sponsoredKidSet.length;
          _totalPlatformChildren = totalKids;
          _totalPlatformDonors = totalDonors;
          _totalAdminFunds = totalFundsCalculated;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isAdmin = auth.userRole == 'admin_panti';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0, top: 10.0, bottom: 10.0),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.volunteer_activism,
              size: 20,
              color: AppColors.primary,
            ),
          ),
        ),
        title: Text(isAdmin ? 'AsuhKita • Pengurus Panti' : 'AsuhKita'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
                gradient: isAdmin ? AppColors.adminGradient : AppColors.donaturGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Halo, ${auth.userName.isNotEmpty ? auth.userName : (isAdmin ? 'Admin Pengurus Panti' : 'Donatur Peduli')} 👋',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isAdmin ? 'Panel Admin' : 'Donatur',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAdmin
                        ? 'Kelola data anak asuh, pantau laporan keuangan terpadu, dan lacak donasi donatur terintegrasi Supabase.'
                        : 'Terima kasih telah membersamai mimpi dan masa depan anak-anak panti asuhan melalui transparansi teknologi.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ==================== 3 FIELD STATUS ATAS ====================
            if (isAdmin)
              Row(
                children: [
                  _buildMetricCard('Anak Terdaftar', '$_totalPlatformChildren Anak', Icons.groups, AppColors.accent3),
                  const SizedBox(width: 10),
                  _buildMetricCard('Total Donatur', '$_totalPlatformDonors Orang', Icons.volunteer_activism, AppColors.primary),
                  const SizedBox(width: 10),
                  _buildMetricCard('Total Dana Masuk', _formatCompactRupiah(_totalAdminFunds), Icons.account_balance_wallet, AppColors.secondary),
                ],
              )
            else
              Row(
                children: [
                  _buildMetricCard(
                    'Anak Asuh',
                    '$_sponsoredCount Anak',
                    Icons.face,
                    AppColors.accent3,
                    onTap: () => _openMySponsoredChildDetail(context),
                  ),
                  const SizedBox(width: 10),
                  _buildMetricCard('Transparansi', '100% SHA-256', Icons.security, AppColors.accent1),
                  const SizedBox(width: 10),
                  _buildMetricCard('IoT Panti', 'Aktif', Icons.sensors, AppColors.accent2),
                ],
              ),
            const SizedBox(height: 24),

            // ==================== DAFTAR MENU FITUR ====================
            Text(
              isAdmin ? 'Fitur & Manajemen Panti Asuhan' : 'Menu & Fasilitas Unggulan',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            if (isAdmin)
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
                    title: 'Tracking Donatur',
                    subtitle: 'Donatur, anak, & nominal',
                    icon: Icons.track_changes,
                    color: AppColors.primary,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DonationTrackingScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Riwayat Donasi Masuk',
                    subtitle: 'Riwayat donasi donatur',
                    icon: Icons.receipt_long,
                    color: AppColors.accent1,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DonationTrackingScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Kelola Anak & Budget',
                    subtitle: 'Multi-kategori & budget',
                    icon: Icons.admin_panel_settings,
                    color: AppColors.primaryDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Laporan Keuangan',
                    subtitle: 'Rekap total per anak',
                    icon: Icons.account_balance_wallet,
                    color: AppColors.accent2,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceDashboardScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Ruang Kasih',
                    subtitle: 'Chat, karya & video call',
                    icon: Icons.favorite,
                    color: AppColors.secondary,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyRoomScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Sahabat Asuh AI',
                    subtitle: 'Bantuan laporan & data',
                    icon: Icons.auto_awesome,
                    color: AppColors.accent3,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Verifikasi Sertifikat',
                    subtitle: 'Cek kredensial donasi',
                    icon: Icons.verified_user,
                    color: AppColors.primaryDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Jadwal Lap. Keuangan',
                    subtitle: 'Audit 4 zona waktu',
                    icon: Icons.schedule,
                    color: AppColors.accent1,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduleScreen())),
                  ),
                ],
              )
            else
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
                    color: AppColors.primary,
                    onTap: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(1);
                      }
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Ruang Kasih',
                    subtitle: 'Chat & video call',
                    icon: Icons.favorite,
                    color: AppColors.secondary,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyRoomScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Verifikasi Sertifikat',
                    subtitle: 'Cek kredensial donasi',
                    icon: Icons.verified_user,
                    color: AppColors.primaryDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Peta Panti LBS',
                    subtitle: 'Jarak & check-in 100m',
                    icon: Icons.map,
                    color: AppColors.accent3,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Jadwal 4 Zona',
                    subtitle: 'WIB, WITA, WIT, London',
                    icon: Icons.schedule,
                    color: AppColors.accent1,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduleScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Sensor & Game',
                    subtitle: 'Langkah & Gyroscope',
                    icon: Icons.sports_esports,
                    color: AppColors.accent2,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StepsAndGameScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Sahabat Asuh AI',
                    subtitle: 'Surat & ringkasan LLM',
                    icon: Icons.auto_awesome,
                    color: AppColors.accent3,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Kotak Amal IoT',
                    subtitle: 'Deteksi sensor koin/uang',
                    icon: Icons.savings,
                    color: AppColors.secondary,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IotDonationScreen())),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Data Offline & Online',
                    subtitle: 'Arsitektur data panti',
                    icon: Icons.cloud_sync,
                    color: AppColors.primary,
                    onTap: () => _showOfflineOnlineDataModal(context),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'Profil Anak Asuh',
                    subtitle: 'Detail & mimpi anak asuh',
                    icon: Icons.badge_outlined,
                    color: AppColors.accent3,
                    onTap: () => _openMySponsoredChildDetail(context),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showOfflineOnlineDataModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.cloud_sync, color: AppColors.primary, size: 24),
                SizedBox(width: 8),
                Text(
                  'Arsitektur Data: Offline vs Online',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Pemisahan peran data lokal (SQLite) dan cloud (Supabase) pada ekosistem AsuhKita.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const Divider(height: 20),
            Expanded(
              child: ListView(
                children: [
                  // 1. DATA OFFLINE (LOKAL SQLITE)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade300, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                              child: const Icon(Icons.storage, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'DATA OFFLINE (Tersimpan di SQLite Lokal)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF8B6914)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Data master statis yang tetap dapat diakses tanpa kuota internet kapan saja:',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        _buildDataBullet('Data Panti Asuhan & Cabang Yayasan', 'Alamat lengkap, kontak resmi, rekening, dan profil panti.'),
                        _buildDataBullet('Panduan SOP & Edukasi Orang Tua Asuh', 'Materi dan prosedur perlindungan anak asuh.'),
                        _buildDataBullet('Cache Histori Percakapan Ruang Kasih', 'Pesan offline yang tersimpan aman di database SQLite lokal.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. DATA ONLINE (CLOUD SUPABASE)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade300, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                              child: const Icon(Icons.cloud_done, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'DATA ONLINE (Cloud Supabase PostgreSQL)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D47A1)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Data dinamis real-time yang langsung terintegrasi antar-perangkat:',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        _buildDataBullet('Daftar Anak Asuh Terkini', 'Nama samaran, kebutuhan mendesak, dan target donasi yang diinput admin.'),
                        _buildDataBullet('Transaksi & Kuitansi Donasi Real-Time', 'Pencatatan dana masuk dari donatur dan penguncian hash SHA-256.'),
                        _buildDataBullet('Sinkronisasi Jadwal & Pesan Baru', 'Pembaruan data instan antar-perangkat (Admin <-> Donatur).'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup Katalog Data'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataBullet(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.black87),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMySponsoredChildDetail(BuildContext context) async {
    final localDb = LocalDatabase();
    final localDonations = await localDb.getCachedDonations();
    final sponsoredAliases = <String>{};
    for (var d in localDonations) {
      final alias = (d['child_alias'] ?? '').toString().trim();
      if (alias.isNotEmpty) {
        sponsoredAliases.add(alias.toLowerCase());
      }
    }

    if (sponsoredAliases.isEmpty) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.face_retouching_natural, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Belum Ada Anak Asuh'),
            ],
          ),
          content: const Text(
            'Anda belum memiliki anak asuh yang didampingi saat ini. Kunjungi menu Sponsor untuk melihat daftar anak asuh yang membutuhkan pendampingan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti Saja'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(1);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Pilih Anak Asuh'),
            ),
          ],
        ),
      );
      return;
    }

    // Ambil detail anak dari SQLite/API
    final cachedKids = await localDb.getCachedChildren();
    final newKids = await localDb.getNewChildren();
    final all = [...cachedKids, ...newKids];

    final myKids = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (var k in all) {
      final name = (k['alias'] ?? k['name'] ?? '').toString().toLowerCase();
      if (sponsoredAliases.contains(name) && !seen.contains(name)) {
        seen.add(name);
        myKids.add(k);
      }
    }

    for (var alias in sponsoredAliases) {
      if (!seen.contains(alias)) {
        seen.add(alias);
        final capName = alias.length > 1 ? '${alias[0].toUpperCase()}${alias.substring(1)}' : alias;
        myKids.add({
          'id': 'sp_$alias',
          'alias': capName,
          'name': capName,
          'age': 10,
          'need_category': 'Pendidikan',
          'orphanage_name': 'Panti Asuhan Peduli Anak',
          'orphanage_city': 'Mataram, Lombok',
          'story': 'Anak asuh yang gigih belajar dan bersemangat menggapai cita-cita.',
          'avatar': '',
        });
      }
    }

    if (!context.mounted) return;

    if (myKids.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChildDetailScreen(childData: myKids.first)),
      );
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Anak Asuh Saya (${myKids.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih anak asuh untuk melihat profil detail & perkembangan belajarnya:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Divider(height: 24),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: myKids.length,
                  itemBuilder: (ctx, idx) {
                    final child = myKids[idx];
                    final name = (child['alias'] ?? child['name'] ?? 'Anak').toString();
                    final city = (child['orphanage_city'] ?? child['city'] ?? 'Mataram').toString();
                    final category = (child['need_category'] ?? 'Pendidikan').toString();
                    final avatar = (child['avatar'] ?? '').toString();

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.surfaceLight,
                        backgroundImage: avatar.startsWith('http') ? NetworkImage(avatar) : null,
                        child: avatar.startsWith('http') ? null : const Icon(Icons.face, color: AppColors.primary),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$category • $city', style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChildDetailScreen(childData: child)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
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
