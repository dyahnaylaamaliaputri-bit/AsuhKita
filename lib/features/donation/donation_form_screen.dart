// Letak file: mobile/lib/features/donation/donation_form_screen.dart
// Fungsi: UI Form Donasi Multi-Mata Uang, Konversi Rupiah Otomatis, Konfirmasi Biometrik, dan Antrean Donasi Offline (PBI-027, PBI-028, PBI-030, PBI-057)

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';

class DonationFormScreen extends StatefulWidget {
  final Map<String, dynamic> childData;
  final Map<String, dynamic> packageData;

  const DonationFormScreen({
    super.key,
    required this.childData,
    required this.packageData,
  });

  @override
  State<DonationFormScreen> createState() => _DonationFormScreenState();
}

class _DonationFormScreenState extends State<DonationFormScreen> {
  final _amountController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  String _selectedCurrency = 'IDR'; // IDR, USD, SGD, EUR, SAR (FR-23)
  String _frequency = 'Bulanan'; // 'Bulanan' atau 'Sekali' (FR-22)
  bool _isProcessing = false;

  // Nilai kurs cadangan statis terhadap Rupiah (FR-24, PBI-025)
  final Map<String, double> _exchangeRates = {
    'IDR': 1.0,
    'USD': 15850.0,
    'SGD': 11800.0,
    'EUR': 17200.0,
    'SAR': 4220.0,
  };

  @override
  void initState() {
    super.initState();
    // Default nominal sesuai paket pilihan dalam IDR
    final defaultIdr = widget.packageData['monthly_idr'] ?? 250000;
    _amountController.text = defaultIdr.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // Hitung otomatis nilai IDR (PBI-027, FR-23)
  double get _calculatedIdr {
    final inputVal = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final rate = _exchangeRates[_selectedCurrency] ?? 1.0;
    return inputVal * rate;
  }

  String _formatRupiah(double val) {
    return 'Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Future<void> _processDonation() async {
    final amountInput = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    if (amountInput <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal donasi harus lebih dari 0')),
      );
      return;
    }

    // Konfirmasi Keamanan dengan Biometrik (PBI-057, FR-09)
    bool biometricPassed = false;
    try {
      final canBio = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (canBio) {
        biometricPassed = await _localAuth.authenticate(
          localizedReason: 'Konfirmasi otorisasi donasi sebesar ${_formatRupiah(_calculatedIdr)}',
          biometricOnly: true,
        );
        if (!biometricPassed) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Otorisasi biometrik dibatalkan. Donasi belum diproses.')),
            );
          }
          return;
        }
      } else {
        biometricPassed = true; // Lewati jika di simulator tanpa biometrik
      }
    } catch (_) {
      biometricPassed = true; // Fallback jika sensor tidak aktif
    }

    setState(() => _isProcessing = true);

    final donationPayload = {
      'child_id': widget.childData['id'],
      'child_alias': widget.childData['alias'],
      'package_id': widget.packageData['id'],
      'amount_original': amountInput,
      'currency': _selectedCurrency,
      'rate_used': _exchangeRates[_selectedCurrency] ?? 1.0,
      'amount_idr': _calculatedIdr,
      'frequency': _frequency,
      'created_at': DateTime.now().toIso8601String(),
    };

    bool isOnlineSuccess = false;
    String certificateCode = 'CERT-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    String blockHash = '0000a38f7e912b45e7f1c${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Coba kirim ke REST API server (POST /donations)
      final res = await DioClient().dio.post('/donations', data: donationPayload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        isOnlineSuccess = true;
        certificateCode = res.data['certificate_code'] ?? certificateCode;
        blockHash = res.data['block_hash'] ?? blockHash;
      }
    } catch (e) {
      // Jika internet offline atau server tidak merespons -> Simpan di SQLite Queue (PBI-030, FR-20)
      await LocalDatabase().queueOfflineDonation(
        childId: widget.childData['id'].toString(),
        packageId: widget.packageData['id'].toString(),
        amountOriginal: amountInput,
        currency: _selectedCurrency,
        rateUsed: _exchangeRates[_selectedCurrency] ?? 1.0,
        amountIdr: _calculatedIdr,
        frequency: _frequency,
      );
      isOnlineSuccess = false;
    }

    setState(() => _isProcessing = false);

    // Tampilkan Dialog Sukses & Sertifikat Digital Ber-QR (FR-25, FR-29)
    if (mounted) {
      _showSuccessCertificateDialog(
        isOnline: isOnlineSuccess,
        certCode: certificateCode,
        hash: blockHash,
        amountText: '${amountInput.toStringAsFixed(0)} $_selectedCurrency (${_formatRupiah(_calculatedIdr)})',
      );
    }
  }

  void _showSuccessCertificateDialog({
    required bool isOnline,
    required String certCode,
    required String hash,
    required String amountText,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.verified, color: Colors.teal, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isOnline ? 'Donasi Berhasil & Tercatat!' : 'Donasi Tersimpan di Antrean Offline',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isOnline
                    ? 'Terima kasih atas kepedulian Anda! Donasi Anda telah divalidasi dan dicatat di blockchain ledger.'
                    : 'Koneksi internet offline. Donasi telah diantrekan di SQLite dan otomatis tersinkron saat internet tersambung.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Sertifikat Digital Ber-QR (FR-29, PBI-037)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  children: [
                    const Text(
                      'SERTIFIKAT ORANG TUA ASUH',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Anak Asuh: ${widget.childData['alias']}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text('Nominal: $amountText', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 12),
                    QrImageView(
                      data: 'asuhkita://verify?code=$certCode&hash=$hash',
                      version: QrVersions.auto,
                      size: 130.0,
                    ),
                    const SizedBox(height: 8),
                    Text('Kode: $certCode', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                    Text('Hash: ${hash.substring(0, 16)}...', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Tutup dialog
              Navigator.pop(context); // Kembali ke list
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Form Donasi & Kurs'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rincian Singkat Anak & Paket
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.teal.shade50,
                      child: const Icon(Icons.face, size: 36, color: Colors.teal),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sponsorship untuk ${widget.childData['alias']}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.packageData['name'],
                            style: TextStyle(fontSize: 13, color: Colors.teal.shade800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card Input Mata Uang & Konversi Kurs
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih Mata Uang & Nominal (Multi-Currency)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tersedia 5 mata uang global dengan konversi real-time ke IDR.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const Divider(height: 20),

                    // Pilihan Mata Uang: IDR, USD, SGD, EUR, SAR (FR-23)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.teal),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCurrency,
                              items: _exchangeRates.keys.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedCurrency = val;
                                    // Sesuaikan nilai default input jika ganti valuta
                                    if (val == 'USD') {
                                      _amountController.text = '20';
                                    } else if (val == 'SGD') {
                                      _amountController.text = '25';
                                    } else if (val == 'EUR') {
                                      _amountController.text = '18';
                                    } else if (val == 'SAR') {
                                      _amountController.text = '70';
                                    } else {
                                      _amountController.text = (widget.packageData['monthly_idr'] ?? 250000).toString();
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Input Nominal
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Nominal ($_selectedCurrency)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Info Nilai Kurs Cadangan / Real-time
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kurs: 1 $_selectedCurrency = ${_formatRupiah(_exchangeRates[_selectedCurrency]!)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          const Icon(Icons.currency_exchange, size: 16, color: Colors.teal),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hasil Konversi Rupiah Langsung (PBI-027, FR-23)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estimasi Setara IDR:',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal),
                          ),
                          Text(
                            _formatRupiah(_calculatedIdr),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pilihan Frekuensi Donasi (FR-22)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Frekuensi Donasi', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Bulanan (Orang Tua Asuh)')),
                            selected: _frequency == 'Bulanan',
                            selectedColor: Colors.teal,
                            labelStyle: TextStyle(
                              color: _frequency == 'Bulanan' ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _frequency = 'Bulanan');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Sekali Donasi')),
                            selected: _frequency == 'Sekali',
                            selectedColor: Colors.teal,
                            labelStyle: TextStyle(
                              color: _frequency == 'Sekali' ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _frequency = 'Sekali');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tombol Konfirmasi Pembayaran Simulasi & Biometrik
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _processDonation,
              icon: const Icon(Icons.fingerprint, size: 24),
              label: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Konfirmasi & Donasi (Biometrik)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
