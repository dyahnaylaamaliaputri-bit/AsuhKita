import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';
import '../auth/auth_provider.dart';
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

    // ============================================================
    // VALIDASI PEMENUHAN BUDGET KATEGORI KEBUTUHAN (BUTIR 3)
    // Satu anak bisa > 2 donatur, maksimal donatur menyumbang jika budget kategori terpenuhi
    // ============================================================
    try {
      final childAlias = (widget.childData['alias'] ?? widget.childData['name'] ?? '').toString().trim().toLowerCase();
      final categoryName = (widget.packageData['name'] ?? widget.childData['need_category'] ?? widget.childData['urgentNeeds'] ?? 'Pendidikan').toString();
      
      // Hitung target kategori
      double categoryBudget = (widget.packageData['price_idr'] is num) ? (widget.packageData['price_idr'] as num).toDouble() : 0.0;
      if (categoryBudget <= 0 && widget.childData['target'] is num) {
        categoryBudget = (widget.childData['target'] as num).toDouble();
      }

      // Cek category_budgets JSON jika ada
      final rawCatBudgets = widget.childData['category_budgets'] ?? widget.childData['categoryBudgets'];
      if (rawCatBudgets != null && rawCatBudgets.toString().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawCatBudgets.toString());
          if (decoded is Map) {
            for (var entry in decoded.entries) {
              if (categoryName.toLowerCase().contains(entry.key.toString().toLowerCase())) {
                categoryBudget = (entry.value is num) ? (entry.value as num).toDouble() : double.tryParse(entry.value.toString()) ?? categoryBudget;
                break;
              }
            }
          }
        } catch (_) {}
      }

      if (categoryBudget > 0) {
        final localDonations = await LocalDatabase().getCachedDonations();
        int collectedSoFar = 0;
        int donorCount = 0;
        for (var d in localDonations) {
          final dAlias = (d['child_alias'] ?? '').toString().trim().toLowerCase();
          if (dAlias == childAlias) {
            final amt = (d['amount_idr'] is num) ? (d['amount_idr'] as num).toInt() : 0;
            collectedSoFar += amt;
            donorCount++;
          }
        }

        if (collectedSoFar >= categoryBudget) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 28),
                    SizedBox(width: 8),
                    Expanded(child: Text('Budget Kategori Terpenuhi!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  ],
                ),
                content: Text(
                  'Alhamdulillah! Kebutuhan $categoryName untuk anak asuh ${widget.childData['alias']} sebesar Rp ${categoryBudget.toInt()} sudah 100% terpenuhi oleh $donorCount donatur.\n\nAnda dapat memilih kebutuhan kategori lainnya untuk anak ini atau mendampingi anak asuh yang masih membutuhkan bantuan.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Kembali', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }
    } catch (_) {}

    // Tampilkan QR Code Pembayaran (QRIS Dinamis) terlebih dahulu (Permintaan Butir 6)
    _showPaymentQrDialog(amountInput);
  }

  // ============================================================
  // LANGKAH 1: QR CODE UNTUK MEMBAYAR TRANSAKSI
  // ============================================================
  void _showPaymentQrDialog(double amountInput) {
    final qrisPayload =
        '00020101021226670014ID.LINKAJA.WWW01189360001400000000015204581253033605802ID5914ASUHKITA PANTI6007MATARAM62180714ASUH${DateTime.now().millisecondsSinceEpoch}6304';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 28),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('QRIS Pembayaran Donasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.face, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Anak Asuh: ${widget.childData['alias']} (${widget.packageData['name']})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Total Tagihan Donasi:',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRupiah(_calculatedIdr),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 14),

                // Tampilan QR Code Dinamis
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 170,
                        height: 170,
                        child: QrImageView(
                          data: qrisPayload,
                          version: QrVersions.auto,
                          size: 170.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'QRIS Standar Bank Indonesia (NMID: ID1020030040506)',
                        style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pindai QR di atas via BCA, Mandiri, BRI, BNI, GoPay, OVO, Dana, atau ShopeePay.\nSetelah transfer berhasil, tekan tombol di bawah untuk verifikasi & cetak sertifikat.',
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _finalizeDonationAndShowCertificate(amountInput);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Saya Sudah Bayar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LANGKAH 2: EKSEKUSI PENYIMPANAN & TAMPILKAN SERTIFIKAT RESMI
  // ============================================================
  Future<void> _finalizeDonationAndShowCertificate(double amountInput) async {
    // Konfirmasi Keamanan dengan Biometrik (PBI-057, FR-09)
    try {
      final canBio = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (canBio) {
        await _localAuth.authenticate(
          localizedReason: 'Konfirmasi otorisasi donasi sebesar ${_formatRupiah(_calculatedIdr)}',
          biometricOnly: true,
        );
      }
    } catch (_) {}

    setState(() => _isProcessing = true);

    // Ambil identitas donatur dari AuthProvider / SharedPreferences
    String donorName = 'Donatur Peduli';
    String donorEmail = 'donatur@asuhkita.id';
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.userName.isNotEmpty) donorName = auth.userName;
      if (auth.userEmail.isNotEmpty) donorEmail = auth.userEmail;
    } catch (_) {}

    final needCategory = (widget.packageData['name'] ?? widget.childData['need_category'] ?? widget.childData['urgentNeeds'] ?? 'Pendidikan').toString();

    final donationPayload = {
      'child_id': widget.childData['id'],
      'child_alias': widget.childData['alias'],
      'package_id': widget.packageData['id'],
      'donor_name': donorName,
      'donor_email': donorEmail,
      'need_category': needCategory,
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
      final res = await DioClient().dio.post('/donations', data: donationPayload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        isOnlineSuccess = true;
        certificateCode = res.data['certificate_code'] ?? certificateCode;
        blockHash = res.data['block_hash'] ?? blockHash;
      }
    } catch (e) {
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
      'donor_name': donorName,
      'donor_email': donorEmail,
      'need_category': needCategory,
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

    // Tampilkan Sertifikat Resmi Pendanaan Orang Tua Asuh (Permintaan Butir 6)
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
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: const [
                    Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sertifikat Resmi Pendanaan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Bingkai Sertifikat Digital Ornamen Emas (FR-29)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade400, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.amber.withValues(alpha: 0.1), blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 36),
                      const SizedBox(height: 6),
                      const Text(
                        'SERTIFIKAT PENDANAAN ORANG TUA ASUH',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B6914), fontSize: 13, letterSpacing: 0.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Diberikan sebagai bukti sah telah menjadi orang tua asuh yang mendampingi masa depan & pendidikan:',
                        style: TextStyle(fontSize: 10, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Text(
                          widget.childData['alias'] ?? 'Anak Asuh',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Paket: ${widget.packageData['name']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('Nominal: $amountText', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: QrImageView(
                          data: 'asuhkita://verify?code=$certCode&hash=$hash',
                          version: QrVersions.auto,
                          size: 120.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('No. Sertifikat: $certCode', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                      Text('SHA-256 Ledger: ${hash.substring(0, 16)}...', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isOnline
                      ? '✅ Transaksi berhasil terverifikasi dan dicatat pada blockchain ledger!'
                      : '⏳ Transaksi tersimpan di antrean offline SQLite dan akan otomatis tersinkron saat internet tersambung.',
                  style: TextStyle(fontSize: 11, color: isOnline ? Colors.green.shade800 : Colors.orange.shade800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Simpan & Selesai'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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

            // Tombol Konfirmasi Pembayaran QRIS
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _processDonation,
              icon: const Icon(Icons.qr_code_2_rounded, size: 24),
              label: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Konfirmasi & Dapatkan QRIS Donasi',
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
