// Letak file: mobile/lib/features/donation/donation_history_screen.dart
// Fungsi: UI Riwayat Donasi Pengguna + Sinkronisasi SQLite ↔ Supabase (PBI-029, PBI-030, FR-19, FR-20)

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';

class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  List<Map<String, dynamic>> _donations = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  int _unsyncedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    setState(() => _isLoading = true);

    List<Map<String, dynamic>> allDonations = [];

    // 1. Coba ambil dari Supabase
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
      // Merge: prioritas Supabase, tambahkan yang tidak ada
      final existingIds = allDonations.map((d) => (d['id'] ?? '').toString()).toSet();
      for (var d in localDonations) {
        final id = (d['id'] ?? '').toString();
        if (!existingIds.contains(id)) {
          allDonations.add(d);
        }
      }
    }

    // Sort by created_at descending
    allDonations.sort((a, b) {
      final dateA = a['created_at']?.toString() ?? '';
      final dateB = b['created_at']?.toString() ?? '';
      return dateB.compareTo(dateA);
    });

    // Cek unsynced
    final unsynced = await LocalDatabase().getUnsyncedDonations();

    if (mounted) {
      setState(() {
        _donations = allDonations;
        _unsyncedCount = unsynced.length;
        _isLoading = false;
      });
    }
  }

  Future<void> _syncOfflineDonations() async {
    setState(() => _isSyncing = true);

    final unsynced = await LocalDatabase().getUnsyncedDonations();
    int syncCount = 0;

    for (var donation in unsynced) {
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
          content: Text(syncCount > 0
              ? '$syncCount donasi offline berhasil disinkronkan ke Supabase!'
              : 'Tidak ada donasi baru untuk disinkronkan atau gagal terhubung.'),
          backgroundColor: syncCount > 0 ? AppColors.primary : Colors.orange,
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Sync Banner
                if (_unsyncedCount > 0)
                  Container(
                    width: double.infinity,
                    color: AppColors.accent2.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_upload, color: Color(0xFF8B6914), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_unsyncedCount donasi offline menunggu sinkronisasi ke Supabase.',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B6914)),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isSyncing ? null : _syncOfflineDonations,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isSyncing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Sync', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

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
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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

                // Donation list
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
    );
  }
}
