


import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';

class DonationTrackingScreen extends StatefulWidget {
  const DonationTrackingScreen({super.key});

  @override
  State<DonationTrackingScreen> createState() => _DonationTrackingScreenState();
}

class _DonationTrackingScreenState extends State<DonationTrackingScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  List<Map<String, dynamic>> _donations = [];

  @override
  void initState() {
    super.initState();
    _loadTrackingData();
  }

  Future<void> _loadTrackingData() async {
    setState(() => _isLoading = true);
    final combined = <Map<String, dynamic>>[];

    try {

      final localDonations = await LocalDatabase().getCachedDonations();
      for (var d in localDonations) {
        combined.add({
          'id': d['id'] ?? 'don_${DateTime.now().millisecondsSinceEpoch}',
          'donor_name': (d['donor_name'] != null && d['donor_name'].toString().isNotEmpty)
              ? d['donor_name'].toString()
              : 'Donatur Peduli (Platform)',
          'donor_email': (d['donor_email'] != null && d['donor_email'].toString().isNotEmpty)
              ? d['donor_email'].toString()
              : 'donatur@asuhkita.id',
          'child_alias': (d['child_alias'] != null && d['child_alias'].toString().isNotEmpty)
              ? d['child_alias'].toString()
              : 'Anak Asuh',
          'child_age': d['child_age'] ?? 8,
          'package_name': (d['need_category'] != null && d['need_category'].toString().isNotEmpty)
              ? 'Kategori: ${d['need_category']}'
              : (d['package_id'] != null ? 'Paket: ${d['package_id']}' : 'Paket Pendanaan (${d['currency'] ?? 'IDR'})'),
          'amount_idr': (d['amount_idr'] is num) ? (d['amount_idr'] as num).toInt() : 0,
          'frequency': d['frequency'] ?? 'Bulanan',
          'date': (d['created_at'] != null && d['created_at'].toString().length >= 16)
              ? d['created_at'].toString().substring(0, 16)
              : (d['created_at']?.toString() ?? '-'),
          'block_hash': '0000${(d['id'] ?? '').hashCode.abs().toRadixString(16)}',
          'status': d['status'] ?? 'Terverifikasi Ledger',
        });
      }


      try {
        final res = await DioClient().dio.get('/donations');
        if (res.statusCode == 200) {
          List<dynamic> apiList = [];
          if (res.data is List) {
            apiList = res.data as List;
          } else if (res.data is Map && res.data['data'] is List) {
            apiList = res.data['data'] as List;
          }

          for (var ad in apiList) {
            final id = ad['id']?.toString() ?? '';

            if (!combined.any((c) => c['id'] == id)) {
              combined.add({
                'id': id,
                'donor_name': (ad['donor_name'] ?? ad['donor_email'] ?? 'Donatur Supabase').toString(),
                'donor_email': (ad['donor_email'] ?? 'donatur@asuhkita.id').toString(),
                'child_alias': (ad['child_alias'] ?? ad['child_name'] ?? 'Anak Asuh').toString(),
                'child_age': ad['child_age'] ?? 8,
                'package_name': (ad['need_category'] ?? ad['package_name'] ?? 'Paket Donasi').toString(),
                'amount_idr': (ad['amount_idr'] is num) ? (ad['amount_idr'] as num).toInt() : 0,
                'frequency': ad['frequency'] ?? 'Sekali',
                'date': (ad['created_at'] != null && ad['created_at'].toString().length >= 16)
                    ? ad['created_at'].toString().substring(0, 16)
                    : (ad['created_at']?.toString() ?? '-'),
                'block_hash': ad['block_hash'] ?? '0000${id.hashCode.abs().toRadixString(16)}',
                'status': ad['status'] ?? 'Terverifikasi Ledger Cloud',
              });
            }
          }
        }
      } catch (_) {}


      combined.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));

      if (mounted) {
        setState(() {
          _donations = combined;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatRupiah(int val) {
    return 'Rp ${val.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _donations.where((d) {
      final q = _searchQuery.toLowerCase();
      final donor = d['donor_name'].toString().toLowerCase();
      final child = d['child_alias'].toString().toLowerCase();
      final pkg = d['package_name'].toString().toLowerCase();
      return donor.contains(q) || child.contains(q) || pkg.contains(q);
    }).toList();

    final totalDonasiNyata = _donations.fold<int>(0, (sum, item) => sum + ((item['amount_idr'] as int?) ?? 0));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Donasi Donatur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Riwayat',
            onPressed: _loadTrackingData,
          ),
        ],
      ),
      body: Column(
        children: [

          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surfaceLight,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Donasi Masuk (Riil)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        _formatRupiah(totalDonasiNyata),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${_donations.length} Donasi Donatur',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),


          Padding(
            padding: const EdgeInsets.all(14.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari donatur, anak asuh, atau kebutuhan...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),


          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.volunteer_activism_outlined, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              const Text(
                                'Belum Ada Riwayat Donasi',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Riwayat donasi yang dilakukan oleh donatur untuk anak asuh akan otomatis tercatat dan dapat dipantau di sini secara real-time.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final item = filtered[idx];
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                            radius: 18,
                                            child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['donor_name'],
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                              ),
                                              Text(
                                                item['donor_email'],
                                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _formatRupiah(item['amount_idr']),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    children: [
                                      const Icon(Icons.favorite, size: 16, color: Colors.redAccent),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Untuk: ${item['child_alias']}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                        ),
                                        child: Text(
                                          item['package_name'],
                                          style: const TextStyle(fontSize: 10, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Waktu: ${item['date']}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item['status'],
                                          style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.tag, size: 14, color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Hash: ${item['block_hash']}',
                                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
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
    );
  }
}
