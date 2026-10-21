// Letak file: mobile/lib/features/donation/donation_history_screen.dart
// Fungsi: Riwayat Donasi dengan Cache SQLite & Sinkronisasi Antrean Offline (PBI-029, PBI-030, FR-26)

import 'package:flutter/material.dart';
import '../../data/local_db.dart';
import '../../core/dio_client.dart';

class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _offlineQueue = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  final List<Map<String, dynamic>> _dummyHistory = [
    {
      'id': 'don_001',
      'child_alias': 'Bintang',
      'amount_original': 250000.0,
      'currency': 'IDR',
      'rate_used': 1.0,
      'amount_idr': 250000.0,
      'frequency': 'Bulanan',
      'created_at': '2026-10-15 14:20',
      'status': 'Terverifikasi di Ledger',
    },
    {
      'id': 'don_002',
      'child_alias': 'Alya',
      'amount_original': 20.0,
      'currency': 'USD',
      'rate_used': 15850.0,
      'amount_idr': 317000.0,
      'frequency': 'Sekali',
      'created_at': '2026-10-10 09:12',
      'status': 'Terverifikasi di Ledger',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    _offlineQueue = await LocalDatabase().getUnsyncedDonations();

    // 1. Baca transaksi tersimpan dari Database Lokal SQLite
    final localDonations = await LocalDatabase().getCachedDonations();

    try {
      // 2. Coba sinkronkan dengan cloud server jika terhubung
      final res = await DioClient().dio.get('/donations/history');
      if (res.statusCode == 200 && res.data is List && (res.data as List).isNotEmpty) {
        _history = List<Map<String, dynamic>>.from(res.data);
      } else {
        _history = localDonations;
      }
    } catch (_) {
      _history = localDonations;
    }

    setState(() => _isLoading = false);
  }

  // Sinkronisasi antrean donasi offline ke server online (PBI-030, FR-20)
  Future<void> _syncOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;

    setState(() => _isSyncing = true);
    int syncedCount = 0;

    for (var item in _offlineQueue) {
      try {
        final res = await DioClient().dio.post('/donations', data: item);
        if (res.statusCode == 200 || res.statusCode == 201) {
          await LocalDatabase().markDonationSynced(item['id']);
          syncedCount++;
        }
      } catch (_) {
        // Abaikan jika masih belum bisa tersambung
      }
    }

    setState(() => _isSyncing = false);
    await _loadHistory();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$syncedCount donasi offline berhasil disinkronkan ke server!'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  String _formatCurrency(double val) {
    return 'Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Riwayat Donasi & Sinkronisasi'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sinkronisasi Donasi Offline',
            onPressed: _isSyncing ? null : _syncOfflineQueue,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Banner Antrean Offline jika ada yang menunggu sync
                  if (_offlineQueue.isNotEmpty)
                    Card(
                      color: Colors.orange.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.orange.shade300),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_upload, color: Colors.orange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_offlineQueue.length} Donasi Tersimpan di Antrean Offline',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Dibuat saat offline dan siap dikirim saat tersambung internet.',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _isSyncing ? null : _syncOfflineQueue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              child: _isSyncing
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Kirim', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const Text(
                    'Daftar Transaksi Donasi Tercatat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (_history.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'Belum Ada Riwayat Donasi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Akun Anda belum pernah melakukan transaksi donasi.\nSemua transaksi baru akan tercatat di sini dan terkunci di blockchain ledger.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _history.length,
                    itemBuilder: (context, idx) {
                      final don = _history[idx];
                      final orig = don['amount_original'] ?? 0.0;
                      final curr = don['currency'] ?? 'IDR';
                      final idr = don['amount_idr'] ?? 0.0;
                      final rate = don['rate_used'] ?? 1.0;

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Donasi untuk ${don['child_alias']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      don['status'] ?? 'Berhasil',
                                      style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$orig $curr',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.teal),
                                  ),
                                  Text(
                                    _formatCurrency(idr.toDouble()),
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (curr != 'IDR') ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Kurs Terpakai: 1 $curr = ${_formatCurrency(rate.toDouble())}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Frekuensi: ${don['frequency'] ?? 'Bulanan'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                  Text(don['created_at']?.toString().substring(0, 10) ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
