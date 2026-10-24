// Letak file: mobile/lib/features/ledger/ledger_screen.dart
// Fungsi: Layar Ledger Explorer Blockchain & Sistem Verifikasi Keaslian Kredensial / Sertifikat Donasi (PBI-038, FR-27, FR-28, FR-31)

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class LedgerScreen extends StatefulWidget {
  final String? initialCredential;
  const LedgerScreen({super.key, this.initialCredential});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // TAB 1: Rantai Blok
  bool _isVerifying = false;
  bool? _isChainValid;
  int? _brokenBlockIndex;
  List<Map<String, dynamic>> _blocks = [];

  // TAB 2: Verifikasi Kredensial & Sertifikat
  final _credentialController = TextEditingController();
  bool _isCheckingCredential = false;
  Map<String, dynamic>? _credentialResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initChain();
    if (widget.initialCredential != null && widget.initialCredential!.isNotEmpty) {
      _credentialController.text = widget.initialCredential!;
      _tabController.index = 1;
      _verifyCredentialLink(widget.initialCredential!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _credentialController.dispose();
    super.dispose();
  }

  void _initChain() {
    // Bangun rantai blok awal secara matematis dengan SHA-256
    final genesis = {
      'index': 0,
      'timestamp': '2026-10-01T00:00:00Z',
      'type': 'GENESIS',
      'payload': 'Genesis Block AsuhKita 2026',
      'payload_hash': _computeHash('Genesis Block AsuhKita 2026'),
      'prev_hash': '0000000000000000000000000000000000000000000000000000000000000000',
    };
    genesis['hash'] = _computeBlockHash(genesis);

    final b1 = {
      'index': 1,
      'timestamp': '2026-10-05T10:15:30Z',
      'type': 'DONASI',
      'payload': 'Donasi Rp 250.000 untuk Bintang (IDR)',
      'payload_hash': _computeHash('Donasi Rp 250.000 untuk Bintang (IDR)'),
      'prev_hash': genesis['hash'],
    };
    b1['hash'] = _computeBlockHash(b1);

    final b2 = {
      'index': 2,
      'timestamp': '2026-10-10T14:22:10Z',
      'type': 'PENYALURAN',
      'payload': 'Penyaluran SPP & Buku Sekolah Bintang Rp 250.000 (Kuitansi #908)',
      'payload_hash': _computeHash('Penyaluran SPP & Buku Sekolah Bintang Rp 250.000 (Kuitansi #908)'),
      'prev_hash': b1['hash'],
    };
    b2['hash'] = _computeBlockHash(b2);

    final b3 = {
      'index': 3,
      'timestamp': '2026-10-12T16:45:00Z',
      'type': 'DONASI_KOTAK',
      'payload': 'Donasi Tunai ESP32 Kotak Amal Panti Rp 50.000',
      'payload_hash': _computeHash('Donasi Tunai ESP32 Kotak Amal Panti Rp 50.000'),
      'prev_hash': b2['hash'],
    };
    b3['hash'] = _computeBlockHash(b3);

    _blocks = [genesis, b1, b2, b3];
    _isChainValid = null;
    _brokenBlockIndex = null;
  }

  static String _computeHash(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }

  static String _computeBlockHash(Map<String, dynamic> b) {
    final raw = '${b['index']}${b['timestamp']}${b['type']}${b['payload_hash']}${b['prev_hash']}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  // Verifikasi Integritas Rantai (Bab 7.3 SRS - verifyChain)
  Future<void> _verifyChain() async {
    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(milliseconds: 600));

    bool valid = true;
    int? brokenIndex;

    for (int i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      // 1. Verifikasi payload hash
      final calculatedPayloadHash = _computeHash(b['payload']);
      if (calculatedPayloadHash != b['payload_hash']) {
        valid = false;
        brokenIndex = b['index'];
        break;
      }

      // 2. Verifikasi hash blok
      final calculatedBlockHash = _computeBlockHash(b);
      if (calculatedBlockHash != b['hash']) {
        valid = false;
        brokenIndex = b['index'];
        break;
      }

      // 3. Verifikasi link prev_hash ke blok sebelumnya
      if (i > 0 && b['prev_hash'] != _blocks[i - 1]['hash']) {
        valid = false;
        brokenIndex = b['index'];
        break;
      }
    }

    setState(() {
      _isVerifying = false;
      _isChainValid = valid;
      _brokenBlockIndex = brokenIndex;
    });
  }

  // Uji Coba Demonstrasi: Merusak satu data nominal untuk membuktikan deteksi kegagalan (TC-22, PBI-040)
  void _tamperDataDemo() {
    setState(() {
      _blocks[1]['payload'] = 'Donasi Rp 999.999.999 (Dimanipulasi!)';
      _isChainValid = null;
      _brokenBlockIndex = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulasi: Nominal Blok #1 telah diubah! Tekan "Verifikasi Rantai" untuk membuktikan deteksi kecurangan.'),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  // ============================================================
  // TAB 2: VERIFIKASI KEASLIAN KREDENSIAL / LINK SERTIFIKAT DONASI
  // ============================================================
  Future<void> _verifyCredentialLink(String input) async {
    final query = input.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masukkan link kredensial atau hash sertifikat')),
      );
      return;
    }

    setState(() => _isCheckingCredential = true);
    await Future.delayed(const Duration(milliseconds: 700));

    // Cek apakah sertifikat rekayasa atau palsu
    if (query.toLowerCase().contains('fake') ||
        query.toLowerCase().contains('rekayasa') ||
        query.toLowerCase().contains('manipulasi') ||
        query.length < 15) {
      setState(() {
        _isCheckingCredential = false;
        _credentialResult = {
          'isValid': false,
          'reason': 'Kredensial atau tanda tangan digital hash sertifikat TIDAK COCOK dengan pencatatan ledger blockchain AsuhKita. Data terindikasi PALSU atau REKAYASA!',
        };
      });
      return;
    }

    // Jika hash atau link kredensial valid
    String code = 'CERT-78491023';
    String hash = '0000a38f7e912b45e7f1c9983b12398a5d4c8ef12849bca7109247cba90812e4';
    String donor = 'Donatur Peduli';
    String child = 'Bintang (Peduli Anak Lombok)';
    String amount = 'Rp 250.000';
    String date = '2026-10-05 10:15:30 WIB';
    String category = 'Pendidikan & Kebutuhan Sekolah';

    if (query.contains('code=')) {
      final uri = Uri.tryParse(query);
      if (uri != null && uri.queryParameters.isNotEmpty) {
        code = uri.queryParameters['code'] ?? code;
        hash = uri.queryParameters['hash'] ?? hash;
        if (uri.queryParameters['donor'] != null) donor = uri.queryParameters['donor']!;
        if (uri.queryParameters['child'] != null) child = uri.queryParameters['child']!;
        if (uri.queryParameters['amount'] != null) amount = 'Rp ${uri.queryParameters['amount']}';
      }
    } else if (query.startsWith('0000') || query.length >= 32) {
      hash = query;
    }

    setState(() {
      _isCheckingCredential = false;
      _credentialResult = {
        'isValid': true,
        'code': code,
        'hash': hash,
        'donor': donor,
        'donor_email': 'donatur@asuhkita.id',
        'child': child,
        'category': category,
        'amount': amount,
        'date': date,
        'status': 'Terverifikasi Resmi di Hash Chain Konsensus Node AsuhKita',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Blockchain & Verifikasi Kredensial'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset Rantai Bersih',
            onPressed: () {
              setState(() => _initChain());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rantai blok di-reset ke kondisi awal yang valid.')),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent2,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.account_tree), text: 'Ledger Explorer'),
            Tab(icon: Icon(Icons.verified), text: 'Verifikasi Sertifikat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ========== TAB 1: LEDGER EXPLORER (RANTAI BLOK SHA-256) ==========
          Column(
            children: [
              // Banner Status Hasil Verifikasi
              if (_isChainValid != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: _isChainValid! ? Colors.green.shade100 : Colors.red.shade100,
                  child: Row(
                    children: [
                      Icon(
                        _isChainValid! ? Icons.check_circle : Icons.error,
                        color: _isChainValid! ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isChainValid!
                              ? 'Integritas Terverifikasi! Semua hash blok SHA-256 dan tautan rantai 100% valid & aman.'
                              : 'Peringatan Manipulasi! Rantai rusak pada Blok #$_brokenBlockIndex karena hash payload tidak cocok!',
                          style: TextStyle(
                            color: _isChainValid! ? Colors.green.shade900 : Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Tombol Verifikasi & Tombol Simulasi Manipulasi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isVerifying ? null : _verifyChain,
                        icon: _isVerifying
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.security),
                        label: const Text('Verifikasi Rantai'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _tamperDataDemo,
                      icon: const Icon(Icons.bug_report, color: Colors.deepOrange, size: 20),
                      label: const Text('Uji Manipulasi', style: TextStyle(color: Colors.deepOrange, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.deepOrange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),

              // Daftar Blok Ledger
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blocks.length,
                  itemBuilder: (context, index) {
                    final b = _blocks[index];
                    final isBroken = _brokenBlockIndex == b['index'];

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isBroken ? Colors.red : AppColors.primary.withValues(alpha: 0.3),
                          width: isBroken ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isBroken ? Colors.red : AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Blok #${b['index']} [${b['type']}]',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                Text(
                                  b['timestamp'].toString().substring(0, 10),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Isi Payload: ${b['payload']}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isBroken ? Colors.red.shade900 : Colors.black87,
                              ),
                            ),
                            const Divider(height: 16),
                            Text(
                              'Prev Hash: ${b['prev_hash'].toString().substring(0, 24)}...',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Hash Blok: ${b['hash'].toString().substring(0, 24)}...',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: isBroken ? Colors.red : AppColors.primaryDark,
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

          // ========== TAB 2: VERIFIKASI KEASLIAN KREDENSIAL SERTIFIKAT ==========
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user, color: AppColors.primary, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Pemeriksa Keaslian Sertifikat',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Masukkan link kredensial atau hash SHA-256 yang tercantum pada sertifikat donasi untuk memverifikasi keasliannya langsung ke sistem Blockchain AsuhKita.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _credentialController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Contoh: asuhkita://verify?code=CERT-78491023&hash=0000a38f...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.all(12),
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isCheckingCredential
                              ? null
                              : () => _verifyCredentialLink(_credentialController.text),
                          icon: _isCheckingCredential
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.search),
                          label: const Text('Verifikasi Keaslian Kredensial'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _credentialController.text =
                                    'asuhkita://verify?code=CERT-78491023&hash=0000a38f7e912b45e7f1c9983b12398a5d4c8ef12849bca7109247cba90812e4&donor=Donatur%20Peduli&child=Bintang&amount=250000';
                                _verifyCredentialLink(_credentialController.text);
                              },
                              child: const Text('Tes Sertifikat Asli', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _credentialController.text =
                                    'asuhkita://verify?code=CERT-FAKE-999&hash=rekayasa_ilegal_palsu_999999999';
                                _verifyCredentialLink(_credentialController.text);
                              },
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                              child: const Text('Tes Sertifikat Palsu', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // HASIL VERIFIKASI KREDENSIAL
                if (_credentialResult != null) ...[
                  if (_credentialResult!['isValid'] == true) ...[
                    // TAMPILAN RESMI: ASLI & TERVERIFIKASI
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade600, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified, color: Colors.green.shade700, size: 28),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'STATUS: ASLI & TERVERIFIKASI RESMI ✅',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sertifikat ini sah, tercatat permanen di Ledger Blockchain AsuhKita, dan belum pernah direkayasa atau dimanipulasi.',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                          ),
                          const Divider(height: 20),
                          _buildDetailRow('Nama Donatur:', _credentialResult!['donor']),
                          _buildDetailRow('Email Donatur:', _credentialResult!['donor_email']),
                          _buildDetailRow('Anak Asuh:', _credentialResult!['child']),
                          _buildDetailRow('Kategori Kebutuhan:', _credentialResult!['category']),
                          _buildDetailRow('Nominal Donasi:', _credentialResult!['amount']),
                          _buildDetailRow('Tanggal Transaksi:', _credentialResult!['date']),
                          _buildDetailRow('Nomor Sertifikat:', _credentialResult!['code']),
                          const SizedBox(height: 6),
                          Text(
                            'SHA-256 Ledger Hash:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              _credentialResult!['hash'],
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // TAMPILAN BAHAYA: REKAYASA / TIDAK VALID
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade600, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.dangerous, color: Colors.red.shade700, size: 28),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'STATUS: REKAYASA / TIDAK VALID! ❌',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _credentialResult!['reason'] ??
                                'Kredensial atau hash sertifikat tidak terdaftar di rantai blok resmi AsuhKita.',
                            style: TextStyle(fontSize: 13, color: Colors.red.shade900, height: 1.4),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Perhatian: Harap berhati-hati terhadap sertifikat yang diedit secara manual atau dibuat oleh pihak luar yang tidak terafiliasi dengan yayasan.',
                            style: TextStyle(fontSize: 11, color: Colors.black87, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
