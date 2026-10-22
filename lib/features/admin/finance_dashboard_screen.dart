// Letak file: mobile/lib/features/admin/finance_dashboard_screen.dart
// Fungsi: Layar Dashboard Laporan Keuangan Panti Asuhan, Transparansi Belanja Per Masing-Masing Anak Asuh (Tanpa Dobel), dan Narasi AI (PBI-039, PBI-062)

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../services/gemini_service.dart';
import '../../data/local_db.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  final GeminiService _gemini = GeminiService();
  final LocalDatabase _localDb = LocalDatabase();
  bool _isLoading = true;
  bool _isGeneratingAiReport = false;
  String? _aiGeneratedNarrative;

  // Rekap Keuangan Riil Panti Asuhan (Terintegrasi Supabase & SQLite)
  int _totalDonasiMasuk = 0;
  int _totalDanaDigunakan = 0;
  int get _saldoKasPanti => _totalDonasiMasuk - _totalDanaDigunakan;

  // Daftar Keuangan Per Masing-Masing Anak (Dikelompokkan, Bebas Duplikasi Nama)
  List<Map<String, dynamic>> _childrenFinances = [];

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Ambil seluruh data anak dari Supabase & SQLite
      List<Map<String, dynamic>> allChildrenRaw = [];
      try {
        final res = await DioClient().dio.get('/children');
        if (res.statusCode == 200) {
          final data = res.data;
          if (data is List && data.isNotEmpty) {
            allChildrenRaw = List<Map<String, dynamic>>.from(data);
          } else if (data is Map && data['data'] is List) {
            allChildrenRaw = List<Map<String, dynamic>>.from(data['data']);
          }
        }
      } catch (_) {}

      final newKids = await _localDb.getNewChildren();
      final cachedKids = await _localDb.getCachedChildren();

      // Gabungkan dan deduplikasi anak berdasarkan nama/alias unik (Case-Insensitive)
      final Map<String, Map<String, dynamic>> uniqueKidsMap = {};

      for (var k in allChildrenRaw) {
        final name = (k['alias'] ?? k['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          uniqueKidsMap[name.toLowerCase()] = {
            'id': k['id']?.toString() ?? '',
            'name': name,
            'age': k['age'] ?? 8,
            'city': k['orphanage_city'] ?? k['city'] ?? 'Peduli Anak Lombok',
            'photo': k['avatar'] ?? k['photo'] ?? '',
            'category': k['need_category'] ?? k['urgentNeeds'] ?? 'Pendidikan',
            'target': (k['target'] is num) ? (k['target'] as num).toDouble() : 500000.0,
          };
        }
      }

      for (var k in cachedKids) {
        final name = (k['alias'] ?? k['name'] ?? '').toString().trim();
        if (name.isNotEmpty && !uniqueKidsMap.containsKey(name.toLowerCase())) {
          uniqueKidsMap[name.toLowerCase()] = {
            'id': k['id']?.toString() ?? '',
            'name': name,
            'age': k['age'] ?? 8,
            'city': k['orphanage_city'] ?? k['city'] ?? 'Peduli Anak Lombok',
            'photo': k['avatar'] ?? k['photo'] ?? '',
            'category': k['need_category'] ?? 'Pendidikan',
            'target': (k['target'] is num) ? (k['target'] as num).toDouble() : 500000.0,
          };
        }
      }

      for (var k in newKids) {
        final name = (k['name'] ?? k['alias'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          uniqueKidsMap[name.toLowerCase()] = {
            'id': k['id']?.toString() ?? '',
            'name': name,
            'age': k['age'] ?? 8,
            'city': k['city'] ?? 'Peduli Anak Lombok',
            'photo': k['photo'] ?? '',
            'category': k['urgentNeeds'] ?? k['need_category'] ?? 'Pendidikan',
            'target': (k['target'] is num) ? (k['target'] as num).toDouble() : 500000.0,
          };
        }
      }

      // 2. Ambil seluruh donasi dari SQLite dan Supabase
      final localDonations = await _localDb.getCachedDonations();
      final allDonations = List<Map<String, dynamic>>.from(localDonations);
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
            final id = ad['id']?.toString() ?? '';
            if (!allDonations.any((d) => d['id']?.toString() == id)) {
              allDonations.add(Map<String, dynamic>.from(ad));
            }
          }
        }
      } catch (_) {}

      // 3. Ambil seluruh receipts pengeluaran belanja
      final receipts = await _localDb.getReceipts();

      // 4. Hitung dan Agregasikan Laporan Keuangan PER MASING-MASING ANAK (Per Child, No Duplicate)
      int totalPlatformDonations = 0;
      int totalPlatformExpenses = 0;
      final List<Map<String, dynamic>> calculatedKids = [];

      for (var entry in uniqueKidsMap.entries) {
        final key = entry.key;
        final childInfo = entry.value;
        final cName = childInfo['name'].toString();

        // Cari semua donasi untuk anak ini
        final childDonations = allDonations.where((d) {
          final alias = (d['child_alias'] ?? '').toString().trim().toLowerCase();
          return alias == key;
        }).toList();

        int childTotalDonations = 0;
        final donorsSet = <String>{};
        for (var d in childDonations) {
          final amt = (d['amount_idr'] is num) ? (d['amount_idr'] as num).toInt() : 0;
          childTotalDonations += amt;
          final dName = (d['donor_name'] ?? d['donor_email'] ?? d['sponsorship_id'] ?? '').toString().trim();
          if (dName.isNotEmpty) donorsSet.add(dName.toLowerCase());
        }

        // Cari semua nota belanja untuk anak ini
        final childReceipts = receipts.where((r) {
          final rName = (r['childName'] ?? r['child_name'] ?? '').toString().trim().toLowerCase();
          return rName == key;
        }).toList();

        int childTotalSpent = 0;
        for (var r in childReceipts) {
          final amt = (r['amount'] is num) ? (r['amount'] as num).toInt() : 0;
          childTotalSpent += amt;
        }

        totalPlatformDonations += childTotalDonations;
        totalPlatformExpenses += childTotalSpent;

        final target = childInfo['target'] as double;
        final balance = childTotalDonations - childTotalSpent;
        final percent = target > 0 ? (childTotalDonations / target * 100).clamp(0.0, 100.0) : 0.0;

        calculatedKids.add({
          'id': childInfo['id'],
          'name': cName,
          'age': childInfo['age'],
          'city': childInfo['city'],
          'photo': childInfo['photo'],
          'category': childInfo['category'],
          'target': target,
          'totalDonations': childTotalDonations,
          'donorCount': donorsSet.isNotEmpty ? donorsSet.length : (childDonations.isNotEmpty ? 1 : 0),
          'totalSpent': childTotalSpent,
          'balance': balance,
          'percent': percent,
          'donationsList': childDonations,
          'receiptsList': childReceipts,
        });
      }

      // Urutkan anak berdasarkan dana yang terkumpul terbanyak
      calculatedKids.sort((a, b) => (b['totalDonations'] as int).compareTo(a['totalDonations'] as int));

      if (mounted) {
        setState(() {
          _childrenFinances = calculatedKids;
          _totalDonasiMasuk = totalPlatformDonations;
          _totalDanaDigunakan = totalPlatformExpenses;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatRupiah(num val) {
    return 'Rp ${val.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Future<void> _generateAiFinancialNarrative() async {
    setState(() => _isGeneratingAiReport = true);

    final kidsSummary = _childrenFinances.map((c) {
      return '- ${c['name']}: Target ${_formatRupiah(c['target'])}, Diterima ${_formatRupiah(c['totalDonations'])} (${c['donorCount']} donatur), Dibelanjakan ${_formatRupiah(c['totalSpent'])}, Sisa ${_formatRupiah(c['balance'])}';
    }).take(8).join('\n');

    final prompt = 'Buatkan narasi laporan akuntansi pertanggungjawaban keuangan resmi panti asuhan untuk donatur: '
        'Total donasi diterima: ${_formatRupiah(_totalDonasiMasuk)}, '
        'Total tersalurkan (nota): ${_formatRupiah(_totalDanaDigunakan)}, '
        'Sisa saldo kas panti: ${_formatRupiah(_saldoKasPanti)}.\n'
        'Berikut ringkasan per anak asuh:\n$kidsSummary\n'
        'Gunakan bahasa profesional akuntansi sosial, transparan per anak, dan penuh ucapan terima kasih kepada seluruh donatur.';

    final res = await _gemini.askFaq(prompt);

    if (mounted) {
      setState(() {
        _aiGeneratedNarrative = res;
        _isGeneratingAiReport = false;
      });
    }
  }

  Widget _buildChildAvatar(String url) {
    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(bytes, width: 50, height: 50, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 50,
          height: 50,
          color: AppColors.surfaceLight,
          child: const Icon(Icons.person, color: AppColors.primary),
        ),
      );
    }
    return Container(
      width: 50,
      height: 50,
      color: AppColors.surfaceLight,
      child: const Icon(Icons.person, color: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan Keuangan Per Anak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Laporan',
            onPressed: _loadFinanceData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // ==================== KARTU RINGKASAN KEUANGAN KESELURUHAN ====================
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: AppColors.primaryDark,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Kas Saldo Panti Asuhan (Real-Time)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_childrenFinances.length} Anak Terdata',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatRupiah(_saldoKasPanti),
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        const Divider(color: Colors.white24, height: 26),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Donasi Masuk', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  _formatRupiah(_totalDonasiMasuk),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Total Tersalurkan (Nota)', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  _formatRupiah(_totalDanaDigunakan),
                                  style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ==================== TOMBOL GENERATE AI NARRATIVE ====================
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  color: AppColors.surfaceLight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'AI: Buat Narasi Laporan Akuntansi Otomatis',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Menganalisis data keuangan per masing-masing anak asuh dan merangkum narasi audit pertanggungjawaban untuk donatur.',
                          style: TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isGeneratingAiReport ? null : _generateAiFinancialNarrative,
                            icon: _isGeneratingAiReport
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.summarize, size: 16),
                            label: const Text('Buat Narasi Laporan Akuntansi dengan AI', style: TextStyle(fontSize: 13)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                          ),
                        ),
                        if (_aiGeneratedNarrative != null) ...[
                          const Divider(height: 20),
                          const Text('Draf Narasi Laporan Akuntansi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                            child: Text(_aiGeneratedNarrative!, style: const TextStyle(fontSize: 12, height: 1.45)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ==================== DAFTAR LAPORAN PER MASING-MASING ANAK (BEBAS DOBEL) ====================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Laporan Keuangan Per Masing-Masing Anak',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${_childrenFinances.length} Anak',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Setiap anak hanya tercatat 1 kali dengan akumulasi total donasi dari seluruh donaturnya.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),

                if (_childrenFinances.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: const Center(
                      child: Text('Belum ada data anak asuh terdaftar.', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                else
                  ..._childrenFinances.map((child) {
                    final target = child['target'] as double;
                    final totalDonations = child['totalDonations'] as int;
                    final totalSpent = child['totalSpent'] as int;
                    final balance = child['balance'] as int;
                    final donorCount = child['donorCount'] as int;
                    final percent = child['percent'] as double;
                    final donations = (child['donationsList'] as List<dynamic>?) ?? [];
                    final receipts = (child['receiptsList'] as List<dynamic>?) ?? [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 1.5,
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _buildChildAvatar(child['photo'] ?? ''),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  child['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '👥 $donorCount Donatur',
                                  style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Kebutuhan: ${child['category']} • ${child['city']}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Diterima: ${_formatRupiah(totalDonations)}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                  Text(
                                    'Budget: ${_formatRupiah(target)}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: percent / 100,
                                  minHeight: 5,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(percent >= 100 ? Colors.green : AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              color: AppColors.surfaceLight.withValues(alpha: 0.4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Baris Ringkasan Arus Kas Anak
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Dana Dibelanjakan', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                              const SizedBox(height: 2),
                                              Text(_formatRupiah(totalSpent), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Sisa Kas Anak', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                              const SizedBox(height: 2),
                                              Text(_formatRupiah(balance), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Rincian Donatur yang Berdonasi
                                  Text(
                                    'Rincian Donatur ($donorCount Donatur):',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  if (donations.isEmpty)
                                    const Text('Belum ada donasi masuk untuk anak ini.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))
                                  else
                                    ...donations.map((d) {
                                      final dName = (d['donor_name'] ?? d['donor_email'] ?? 'Donatur Peduli').toString();
                                      final amt = (d['amount_idr'] is num) ? (d['amount_idr'] as num).toInt() : 0;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('• $dName', style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                                            Text(_formatRupiah(amt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                          ],
                                        ),
                                      );
                                    }),
                                  const SizedBox(height: 10),

                                  // Rincian Nota Belanja
                                  Text(
                                    'Nota Belanja Terverifikasi (${receipts.length} Nota):',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  if (receipts.isEmpty)
                                    const Text('Belum ada nota belanja diinputkan untuk anak ini.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))
                                  else
                                    ...receipts.map((r) {
                                      final title = (r['title'] ?? 'Belanja Kebutuhan').toString();
                                      final amt = (r['amount'] is num) ? (r['amount'] as num).toInt() : 0;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text('🧾 $title', style: const TextStyle(fontSize: 11, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ),
                                            Text(_formatRupiah(amt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
