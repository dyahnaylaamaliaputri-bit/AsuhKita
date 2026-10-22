import 'package:shared_preferences/shared_preferences.dart';
// Letak file: mobile/lib/features/donation/donation_form_screen.dart
// Fungsi: UI Form Donasi Multi-Mata Uang, Konversi Rupiah Otomatis, Konfirmasi Biometrik, dan Antrean Donasi Offline (PBI-027, PBI-028, PBI-030, PBI-057)
// Upgrade : Kurs real-time via ExchangeRateService (PBI-048, FR-43)

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';
import '../../services/exchange_rate_service.dart';

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
  bool _isFetchingRates = false;

  // Kurs aktif (diperbarui dari ExchangeRateService saat online, FR-43, PBI-048)
  Map<String, double> _exchangeRates = {
    'IDR': 1.0,
    'USD': 15850.0,
    'SGD': 11800.0,
    'EUR': 17200.0,
    'SAR': 4220.0,
  };
  bool _isUsingRealtimeRates = false;
  final ExchangeRateService _rateService = ExchangeRateService();

  @override
  void initState() {
    super.initState();
    // Default nominal sesuai paket pilihan dalam IDR
    final defaultIdr = widget.packageData['monthly_idr'] ?? 250000;
    _amountController.text = defaultIdr.toString();
    // Fetch kurs real-time (FR-43, PBI-048)
    _fetchRealTimeRates();
  }

  Future<void> _fetchRealTimeRates() async {
    setState(() => _isFetchingRates = true);
    final rates = await _rateService.fetchRates();
    setState(() {
      _exchangeRates = rates;
      _isUsingRealtimeRates = _rateService.isUsingRealtime;
      _isFetchingRates = false;
    });
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

    
    // SIMPAN PERSISTEN KE DATABASE LOKAL SQLITE agar riwayat donasi & beranda realtime
    await LocalDatabase().insertDonation({
      'id': 'don_${DateTime.now().millisecondsSinceEpoch}',
      'sponsorship_id': 'sp_${DateTime.now().millisecondsSinceEpoch}',
      'child_alias': widget.childData['alias'],
      'amount_original': amountInput,
      'currency': _selectedCurrency,
      'rate_used': _exchangeRates[_selectedCurrency] ?? 1.0,
      'amount_idr': _calculatedIdr,
      'created_at': DateTime.now().toString().substring(0, 16),
      'status': isOnlineSuccess ? 'Terverifikasi di Ledger Cloud' : 'Tersimpan di SQLite (Menunggu Sync)',
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentSponsored = prefs.getInt('asuhkita_user_sponsored_count') ?? 0;
      await prefs.setInt('asuhkita_user_sponsored_count', currentSponsored + 1);
    } catch (_) {}

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
            const Icon(Icons.verified, color: AppColors.primary, size: 28),
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
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'SERTIFIKAT ORANG TUA ASUH',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
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
              backgroundColor: AppColors.primary,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Form Donasi & Kurs'),
        backgroundColor: AppColors.primary,
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
                      backgroundColor: AppColors.surfaceLight,
                      child: const Icon(Icons.face, size: 36, color: AppColors.primary),
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
                            style: const TextStyle(fontSize: 13, color: AppColors.primaryDark),
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
                            border: Border.all(color: AppColors.primary),
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
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

                    // Info Nilai Kurs Real-time / Cadangan (FR-43, PBI-048)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isUsingRealtimeRates
                            ? AppColors.accent1.withValues(alpha: 0.2)
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isUsingRealtimeRates
                              ? AppColors.accent1.withValues(alpha: 0.5)
                              : Colors.orange.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _isFetchingRates
                                  ? 'Memuat kurs terkini...'
                                  : 'Kurs: 1 $_selectedCurrency = ${_formatRupiah(_exchangeRates[_selectedCurrency] ?? 1.0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          _isFetchingRates
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.primary),
                                )
                              : Row(
                                  children: [
                                    Icon(
                                      _isUsingRealtimeRates
                                          ? Icons.wifi
                                          : Icons.wifi_off,
                                      size: 14,
                                      color: _isUsingRealtimeRates
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isUsingRealtimeRates
                                          ? 'Real-time'
                                          : 'Cadangan',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _isUsingRealtimeRates
                                            ? AppColors.primaryDark
                                            : Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hasil Konversi Rupiah Langsung (PBI-027, FR-23)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estimasi Setara IDR:',
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                          Text(
                            _formatRupiah(_calculatedIdr),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
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
                            selectedColor: AppColors.primary,
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
                            selectedColor: AppColors.primary,
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
                backgroundColor: AppColors.primary,
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
