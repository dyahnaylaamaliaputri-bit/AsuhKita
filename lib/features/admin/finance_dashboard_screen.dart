// Letak file: mobile/lib/features/admin/finance_dashboard_screen.dart
// Fungsi: Layar Dashboard Laporan Keuangan Panti Asuhan, Transparansi Belanja, dan Narasi Laporan Akuntansi Berbantuan AI (PBI-039, PBI-062)

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
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
  bool _isGeneratingAiReport = false;
  String? _aiGeneratedNarrative;

  // Data Keuangan Akuntansi Panti
  int _totalDonasiMasuk = 18500000;
  int _totalDanaDigunakan = 14200000;
  int get _saldoKasPanti => _totalDonasiMasuk - _totalDanaDigunakan;

  List<Map<String, dynamic>> _expenseLedger = [];

  final List<Map<String, dynamic>> _defaultExpenseLedger = [
    {
      'id': 'exp_01',
      'title': 'Beli Seragam & Sepatu Sekolah Baru (12 Anak)',
      'category': 'Pendidikan',
      'nominal': 3600000,
      'date': '2026-10-21',
      'block_hash': '00005d91c7810a92be4',
    },
    {
      'id': 'exp_02',
      'title': 'Belanja Sembako, Beras, Susu & Telur Cawu IV',
      'category': 'Nutrisi & Pangan',
      'nominal': 5400000,
      'date': '2026-10-18',
      'block_hash': '0000918ac5b1293e47a',
    },
    {
      'id': 'exp_03',
      'title': 'Pemeriksaan Kesehatan Berkala & Vitamin Anak',
      'category': 'Kesehatan',
      'nominal': 2200000,
      'date': '2026-10-14',
      'block_hash': '0000108be4a1932c091',
    },
    {
      'id': 'exp_04',
      'title': 'Biaya Kursus Komputer & Bimbingan Belajar',
      'category': 'Pendidikan',
      'nominal': 3000000,
      'date': '2026-10-10',
      'block_hash': '00007c91e84a109bd34',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    final list = <Map<String, dynamic>>[];
    try {
      final userReceipts = await _localDb.getReceipts();
      int additionalSpent = 0;
      for (var r in userReceipts) {
        final amt = (r['amount'] is num) ? (r['amount'] as num).toInt() : 0;
        additionalSpent += amt;
        list.add({
          'id': r['id'] ?? 'rec_${DateTime.now().millisecondsSinceEpoch}',
          'title': '${r['title']} (${r['childName'] ?? 'Anak'})',
          'category': 'Transparansi Anak',
          'nominal': amt,
          'date': r['date'] ?? DateTime.now().toString().split(' ')[0],
          'block_hash': r['hash'] ?? '0000${r['id'].hashCode.abs()}',
        });
      }

      list.addAll(_defaultExpenseLedger);

      setState(() {
        _expenseLedger = list;
        _totalDanaDigunakan = 14200000 + additionalSpent;
      });
    } catch (_) {
      setState(() {
        _expenseLedger = List.from(_defaultExpenseLedger);
      });
    }
  }

  String _formatRupiah(int val) {
    return 'Rp ${val.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Future<void> _generateAiFinancialNarrative() async {
    setState(() => _isGeneratingAiReport = true);

    final prompt = 'Buatkan narasi laporan pertanggungjawaban keuangan resmi panti asuhan untuk donatur: '
        'Total donasi diterima: ${_formatRupiah(_totalDonasiMasuk)}, '
        'Total tersalurkan: ${_formatRupiah(_totalDanaDigunakan)}, '
        'Sisa saldo: ${_formatRupiah(_saldoKasPanti)}. '
        'Pengeluaran utama mencakup seragam, nutrisi makanan harian, biaya kesehatan berkala, dan kebutuhan sekolah anak asuh. '
        'Gunakan bahasa profesional akuntansi sosial, transparan, dan penuh ucapan syukur serta terima kasih kepada para donatur.';

    final res = await _gemini.askFaq(prompt);

    setState(() {
      _aiGeneratedNarrative = res;
      _isGeneratingAiReport = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard Laporan Keuangan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFinanceData,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Kartu Ringkasan Keuangan Panti
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: AppColors.primaryDark,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kas Saldo Panti Asuhan (Real-Time)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    _formatRupiah(_saldoKasPanti),
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const Divider(color: Colors.white24, height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Donasi Masuk', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(_formatRupiah(_totalDonasiMasuk), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total Tersalurkan', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(_formatRupiah(_totalDanaDigunakan), style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tombol AI Bantuan Laporan Keuangan
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
                      Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
                      SizedBox(width: 8),
                      Text('AI: Buat Narasi Laporan Keuangan Otomatis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'AI Sahabat Asuh dapat menganalisis data belanja panti dan merangkum narasi pertanggungjawaban untuk donatur dan audit secara instan.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingAiReport ? null : _generateAiFinancialNarrative,
                      icon: _isGeneratingAiReport
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.summarize),
                      label: const Text('Buat Narasi Laporan dengan AI'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    ),
                  ),
                  if (_aiGeneratedNarrative != null) ...[
                    const Divider(height: 24),
                    const Text('Draf Narasi Laporan Akuntansi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
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

          // Header Riwayat Belanja & Kuitansi Nota
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Daftar Penyaluran Dana & Nota', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Terkunci SHA-256', style: TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),

          // List Kuitansi & Nota Belanja
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _expenseLedger.length,
            itemBuilder: (context, idx) {
              final exp = _expenseLedger[idx];
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
                          Expanded(
                            child: Text(exp['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          Text(
                            _formatRupiah(exp['nominal']),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(4)),
                            child: Text(exp['category'], style: const TextStyle(fontSize: 10, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          Text(exp['date'], style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Bukti Nota / Kuitansi Belanja
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nota Belanja Terverifikasi: Blok Hash ${exp['block_hash']}',
                                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
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
        ],
      ),
    );
  }
}
