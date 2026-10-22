// Letak file: mobile/lib/features/ledger/ledger_screen.dart
// Fungsi: Layar Ledger Explorer Blockchain & Tombol Verifikasi Integritas Hash Chain SHA-256 (PBI-038, FR-27, FR-28, FR-31)

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  bool _isVerifying = false;
  bool? _isChainValid;
  int? _brokenBlockIndex;

  // Daftar blok simulasi sesuai struktur hash chain SHA-256 (Bab 5.6 & Bab 7.3 SRS)
  List<Map<String, dynamic>> _blocks = [];

  @override
  void initState() {
    super.initState();
    _initChain();
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
        content: Text('Simulasi: Nominal Blok #1 telah diubah! Tekan "Verifikasi Integritas" untuk membuktikan deteksi kecurangan.'),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Ledger Blockchain Sederhana'),
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
      ),
      body: Column(
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
    );
  }
}
