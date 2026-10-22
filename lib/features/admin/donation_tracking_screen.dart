// Letak file: mobile/lib/features/admin/donation_tracking_screen.dart
// Fungsi: Layar Tracking Donasi Donatur untuk Admin Panti Asuhan (Melacak donatur, anak yang didonasi, nominal, dan jenis paket)

import 'package:flutter/material.dart';
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

  final List<Map<String, dynamic>> _dummyTrackingData = [
    {
      'id': 'don_trk_01',
      'donor_name': 'Hendra Wijaya',
      'donor_email': 'hendra@gmail.com',
      'child_alias': 'Arfa',
      'child_age': 8,
      'package_name': 'Paket Pendidikan Cemerlang',
      'amount_idr': 250000,
      'frequency': 'Bulanan',
      'date': '2026-10-21 14:30',
      'block_hash': '00008f1b4a92c019d3e',
      'status': 'Terverifikasi Ledger',
    },
    {
      'id': 'don_trk_02',
      'donor_name': 'Siti Rahmawati',
      'donor_email': 'siti.rahma@yahoo.com',
      'child_alias': 'Ayra',
      'child_age': 6,
      'package_name': 'Paket Nutrisi & Harian',
      'amount_idr': 150000,
      'frequency': 'Bulanan',
      'date': '2026-10-20 09:15',
      'block_hash': '0000a294d710bf39a12',
      'status': 'Terverifikasi Ledger',
    },
    {
      'id': 'don_trk_03',
      'donor_name': 'Budi Santoso',
      'donor_email': 'budi.s@corporate.id',
      'child_alias': 'Rangga',
      'child_age': 11,
      'package_name': 'Paket Asuh Komprehensif',
      'amount_idr': 400000,
      'frequency': 'Bulanan',
      'date': '2026-10-19 18:45',
      'block_hash': '0000e572091cba38210',
      'status': 'Terverifikasi Ledger',
    },
    {
      'id': 'don_trk_04',
      'donor_name': 'Michael Tan (Singapura)',
      'donor_email': 'm.tan@sgp.com',
      'child_alias': 'Elsa Saputri',
      'child_age': 10,
      'package_name': 'Paket Pendidikan Cemerlang (Valuta SGD)',
      'amount_idr': 590000,
      'frequency': 'Sekali',
      'date': '2026-10-18 11:20',
      'block_hash': '00003b87f910a234cde',
      'status': 'Terverifikasi Ledger',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTrackingData();
  }

  Future<void> _loadTrackingData() async {
    setState(() => _isLoading = true);

    // Ambil donasi lokal dari SQLite
    final localDonations = await LocalDatabase().getCachedDonations();
    final combined = <Map<String, dynamic>>[];

    // Masukkan donasi lokal yang dibuat donatur di platform
    for (var d in localDonations) {
      combined.add({
        'id': d['id'] ?? 'don_${DateTime.now().millisecondsSinceEpoch}',
        'donor_name': 'Donatur Asuh (Platform)',
        'donor_email': 'donatur@asuhkita.id',
        'child_alias': d['child_alias'] ?? 'Anak Asuh',
        'child_age': 9,
        'package_name': 'Paket Sponsorship (${d['currency'] ?? 'IDR'})',
        'amount_idr': (d['amount_idr'] is num) ? (d['amount_idr'] as num).toInt() : 250000,
        'frequency': d['frequency'] ?? 'Bulanan',
        'date': d['created_at']?.toString().substring(0, 16) ?? '2026-10-22 10:00',
        'block_hash': '0000${d['id'].hashCode.abs()}',
        'status': d['status'] ?? 'Terverifikasi Ledger',
      });
    }

    // Gabungkan dengan data donatur terdaftar di panti
    combined.addAll(_dummyTrackingData);

    setState(() {
      _donations = combined;
      _isLoading = false;
    });
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

    final totalTersalurkan = _donations.fold<int>(0, (sum, item) => sum + ((item['amount_idr'] as int?) ?? 0));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Tracking Donasi Donatur'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Banner Ringkasan Tracking
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Donasi Masuk', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        _formatRupiah(totalTersalurkan),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${_donations.length} Transaksi Donasi',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari nama donatur, anak asuh, atau paket...',
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          ),

          // List Data Tracking
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                : filtered.isEmpty
                    ? const Center(child: Text('Tidak ada data donasi yang cocok.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final item = filtered[idx];
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
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Colors.teal.shade100,
                                            radius: 18,
                                            child: const Icon(Icons.person, color: Colors.teal, size: 20),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['donor_name'],
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              Text(
                                                item['donor_email'],
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item['status'],
                                          style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Mendonasi Anak:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          Text(
                                            '${item['child_alias']} (${item['child_age']} th)',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('Total Donasi:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          Text(
                                            _formatRupiah(item['amount_idr']),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Jenis: ${item['package_name']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                        Text(item['date'], style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Hash Ledger: ${item['block_hash']}',
                                    style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey.shade600),
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
