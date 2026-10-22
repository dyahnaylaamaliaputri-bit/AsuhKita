// Letak file: mobile/lib/features/donation/donation_history_screen.dart
// Fungsi: UI Riwayat Donasi Terverifikasi & Daftar Waiting List Donasi Offline (PBI-029, PBI-030, FR-19, FR-20)

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';

class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _donations = [];
  List<Map<String, dynamic>> _waitingList = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDonations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDonations() async {
    setState(() => _isLoading = true);

    List<Map<String, dynamic>> allDonations = [];

    // 1. Coba ambil riwayat online dari Supabase
    try {
      final res = await DioClient().dio.get('/donations');
      if (res.statusCode == 200) {
        if (res.data is List && (res.data as List).isNotEmpty) {
          allDonations = List<Map<String, dynamic>>.from(res.data);
        } else if (res.data is Map && res.data['data'] is List) {
          allDonations = List<Map<String, dynamic>>.from(res.data['data']);
        }
      }
    } catch (_) {}

    // 2. Ambil dari SQLite lokal
    final localDonations = await LocalDatabase().getCachedDonations();
    if (localDonations.isNotEmpty) {
      final existingIds = allDonations.map((d) => (d['id'] ?? '').toString()).toSet();
      for (var d in localDonations) {
        final id = (d['id'] ?? '').toString();
        if (!existingIds.contains(id)) {
          allDonations.add(d);
        }
      }
    }

    allDonations.sort((a, b) {
      final dateA = a['created_at']?.toString() ?? '';
      final dateB = b['created_at']?.toString() ?? '';
      return dateB.compareTo(dateA);
    });

    // 3. Ambil daftar Antrean Offline (Waiting List) dari SQLite
    final unsynced = await LocalDatabase().getUnsyncedDonations();

    if (mounted) {
      setState(() {
        _donations = allDonations;
        _waitingList = unsynced;
        _isLoading = false;
      });
    }
  }

  // Sinkronisasi seluruh antrean donasi offline ke cloud
  Future<void> _syncOfflineDonations() async {
    if (_waitingList.isEmpty) return;

    setState(() => _isSyncing = true);
    int syncCount = 0;

    for (var donation in _waitingList) {
      try {
        final res = await DioClient().dio.post('/donations', data: {
          'child_id': donation['child_id'],
          'package_id': donation['package_id'],
          'amount_original': donation['amount_original'],
          'currency': donation['currency'],
          'rate_used': donation['rate_used'],
          'amount_idr': donation['amount_idr'],
          'frequency': donation['frequency'],
        });
        if (res.statusCode == 200 || res.statusCode == 201) {
          await LocalDatabase().markDonationSynced(donation['id'] as int);
          syncCount++;
        }
      } catch (_) {
        break;
      }
    }

    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncCount > 0
                ? '✅ $syncCount donasi offline berhasil diunggah dan disinkronkan ke cloud!'
                : 'Belum berhasil terhubung ke server. Donasi tetap aman di waiting list.',
          ),
          backgroundColor: syncCount > 0 ? AppColors.primary : Colors.orange,
        ),
      );
      _loadDonations();
    }
  }

  // Sinkronisasi 1 item antrean offline secara spesifik
  Future<void> _syncSingleDonation(Map<String, dynamic> donation) async {
    setState(() => _isSyncing = true);
    bool success = false;

    try {
      final res = await DioClient().dio.post('/donations', data: {
        'child_id': donation['child_id'],
        'package_id': donation['package_id'],
        'amount_original': donation['amount_original'],
        'currency': donation['currency'],
        'rate_used': donation['rate_used'],
        'amount_idr': donation['amount_idr'],
        'frequency': donation['frequency'],
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        await LocalDatabase().markDonationSynced(donation['id'] as int);
        success = true;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Donasi #${donation['id']} berhasil disinkronkan ke server!'
                : 'Server offline. Donasi #${donation['id']} tetap tersimpan di antrean offline.',
          ),
          backgroundColor: success ? AppColors.primary : Colors.orange,
        ),
      );
      _loadDonations();
    }
  }

  // Simulasi Tambah Donasi Offline untuk pengujian Waiting List (Permintaan Butir 7)
  Future<void> _simulateAddOfflineDonation() async {
    await LocalDatabase().queueOfflineDonation(
      childId: 'ch_offline_${DateTime.now().millisecondsSinceEpoch}',
      packageId: 'pkg_pendidikan',
      amountOriginal: 250000,
      currency: 'IDR',
      rateUsed: 1.0,
      amountIdr: 250000,
      frequency: 'Bulanan',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donasi offline berhasil ditambahkan ke Waiting List!'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
      _loadDonations();
    }
  }

  String _formatRupiah(dynamic val) {
    final num value = val is num ? val : (double.tryParse(val?.toString() ?? '0') ?? 0);
    return 'Rp ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Donasi & Sync'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat Ulang',
            onPressed: _loadDonations,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.verified),
              text: 'Terverifikasi (${_donations.length})',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: _waitingList.isNotEmpty,
                label: Text('${_waitingList.length}'),
                child: const Icon(Icons.pending_actions),
              ),
              text: 'Waiting List (${_waitingList.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                // ==================== TAB 1: RIWAYAT TERVERIFIKASI ====================
                Column(
                  children: [
                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Donasi Anda', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  '${_donations.length} Transaksi',
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total Nominal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                _formatRupiah(_donations.fold<double>(0.0, (sum, d) {
                                  final amt = d['amount_idr'];
                                  if (amt is num) return sum + amt.toDouble();
                                  return sum + (double.tryParse(amt?.toString() ?? '0') ?? 0);
                                })),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Daftar Donasi Terverifikasi
                    if (_donations.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
                              const SizedBox(height: 16),
                              const Text('Belum ada riwayat donasi.', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                              const SizedBox(height: 8),
                              const Text('Mulai berdonasi di halaman Sponsor!', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _donations.length,
                          itemBuilder: (context, idx) {
                            final d = _donations[idx];
                            final alias = d['child_alias'] ?? d['child_name'] ?? '-';
                            final amt = d['amount_idr'] ?? d['amount_original'] ?? 0;
                            final currency = d['currency'] ?? 'IDR';
                            final date = d['created_at']?.toString() ?? '-';
                            final status = d['status']?.toString() ?? 'Tercatat';

                            final isVerified = status.toLowerCase().contains('terverifikasi') || status.toLowerCase().contains('ledger');
                            final isPending = status.toLowerCase().contains('menunggu') || status.toLowerCase().contains('sqlite');

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Donasi untuk $alias',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isVerified
                                                ? AppColors.accent1.withValues(alpha: 0.3)
                                                : isPending
                                                    ? AppColors.accent2.withValues(alpha: 0.4)
                                                    : AppColors.surfaceLight,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isVerified ? '✅ Verified' : isPending ? '⏳ Pending' : '📋 Tercatat',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isVerified
                                                  ? Colors.green.shade700
                                                  : isPending
                                                      ? const Color(0xFF8B6914)
                                                      : AppColors.primaryDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatRupiah(amt),
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                        if (currency != 'IDR')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceLight,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(currency, style: const TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Tanggal: $date', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),

                // ==================== TAB 2: DAFTAR WAITING LIST OFFLINE ====================
                Column(
                  children: [
                    // Banner Penjelasan Waiting List & Tombol Aksi
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.hourglass_top, color: Color(0xFF8B6914), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Antrean Unggah Offline (Waiting List)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF8B6914)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Donasi yang diinput saat perangkat offline tersimpan secara aman di database lokal SQLite. Begitu koneksi tersambung, Anda dapat menekan tombol Sinkronkan untuk mengunggah.',
                            style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: (_isSyncing || _waitingList.isEmpty) ? null : _syncOfflineDonations,
                                  icon: _isSyncing
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Icon(Icons.cloud_upload, size: 16),
                                  label: Text(_isSyncing ? 'Menyinkronkan...' : 'Sinkronkan Semua Antrean'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _simulateAddOfflineDonation,
                                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                                label: const Text('Simulasi Offline', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Daftar Item Waiting List
                    if (_waitingList.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.cloud_done_outlined, size: 56, color: Colors.green),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Antrean Offline Kosong',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Seluruh transaksi donasi Anda telah tersinkronisasi aman ke cloud ledger.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _waitingList.length,
                          itemBuilder: (context, idx) {
                            final item = _waitingList[idx];
                            final id = item['id'];
                            final childId = item['child_id']?.toString() ?? '-';
                            final pkgId = item['package_id']?.toString() ?? '-';
                            final amtIdr = item['amount_idr'] ?? 0;
                            final currency = item['currency'] ?? 'IDR';
                            final date = item['created_at']?.toString() ?? '-';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time_filled, size: 16, color: Colors.orange),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Antrean #$id',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            '⏳ Menunggu Sinkronisasi',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8B6914)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 18),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formatRupiah(amtIdr),
                                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Paket: $pkgId • $currency',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: _isSyncing ? null : () => _syncSingleDonation(item),
                                          icon: const Icon(Icons.sync, size: 14),
                                          label: const Text('Unggah', style: TextStyle(fontSize: 11)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Waktu Input: $date • Target: $childId',
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
