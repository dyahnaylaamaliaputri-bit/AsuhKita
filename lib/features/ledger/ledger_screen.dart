



import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';

class LedgerScreen extends StatefulWidget {
  final String? initialCredential;

  const LedgerScreen({super.key, this.initialCredential});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final TextEditingController _credentialController = TextEditingController();
  bool _isVerifying = false;
  Map<String, dynamic>? _verificationResult;

  @override
  void initState() {
    super.initState();
    if (widget.initialCredential != null && widget.initialCredential!.isNotEmpty) {
      _credentialController.text = widget.initialCredential!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyCertificateCredential();
      });
    }
  }

  @override
  void dispose() {
    _credentialController.dispose();
    super.dispose();
  }

  Future<void> _verifyCertificateCredential() async {
    final input = _credentialController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masukkan link kredensial atau kode sertifikat.')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _verificationResult = null;
    });

    final uri = Uri.tryParse(input);
    final code = uri?.queryParameters['cert'] ??
        uri?.queryParameters['code'] ??
        input;
    final hash = uri?.queryParameters['hash'] ?? '';

    try {
      final response = await DioClient().dio.get(
        '/donations/certificates/verify/${Uri.encodeComponent(code)}',
        queryParameters: hash.isEmpty ? null : {'hash': hash},
      );
      final responseData =
          response.data is Map ? response.data['data'] : null;
      final certificate =
          responseData is Map ? responseData['certificate'] : null;
      final isValid =
          responseData is Map && responseData['valid'] == true && certificate is Map;

      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verificationResult = isValid
            ? {
                'isValid': true,
                'data': Map<String, dynamic>.from(certificate),
              }
            : {
                'isValid': false,
                'reason': responseData is Map
                    ? responseData['message']?.toString() ??
                        'Kredensial tidak ditemukan di catatan donasi.'
                    : 'Respons verifikasi dari server tidak valid.',
              };
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verificationResult = {
          'isValid': false,
          'isError': true,
          'reason': 'Verifikasi gagal terhubung ke server: $error',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verifikasi Sertifikat Donasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Container(
              padding: const EdgeInsets.all(18),
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
                    'Masukkan link kredensial, nomor sertifikat, atau hash SHA-256 yang tercantum pada sertifikat donasi untuk memverifikasi keasliannya langsung ke sistem Blockchain AsuhKita.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _credentialController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Tempel link sertifikat AsuhKita, kode CERT-..., atau hash SHA-256',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isVerifying ? null : _verifyCertificateCredential,
                      icon: _isVerifying
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.search_rounded),
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

                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      const Text('Uji Contoh: ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ActionChip(
                        avatar: const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                        backgroundColor: const Color(0xFFFFEBEE),
                        side: const BorderSide(color: Color(0xFFEF9A9A)),
                        label: const Text(
                          "🚨 Sertifikat Rekayasa/Palsu (Demo Dosen)",
                          style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          _credentialController.text =
                              "https://asuhkita.id/verify?cert=CERT-REKAYASA-9981&hash=forged_d41d8cd98f00b204e9800998ecf8427e_unauthorized_party&donor=Pihak%20Luar%20Tak%20Dikenal&child=Rizky&amount=100000000";
                          _verifyCertificateCredential();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),


            if (_verificationResult != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _verificationResult!['isValid'] ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _verificationResult!['isValid'] ? Colors.green.shade400 : Colors.red.shade400,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _verificationResult!['isValid'] ? Icons.check_circle : Icons.cancel,
                          color: _verificationResult!['isValid'] ? Colors.green.shade700 : Colors.red.shade700,
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _verificationResult!['isValid']
                                ? 'SERTIFIKAT ASLI & TERVERIFIKASI'
                                : (_verificationResult!['isError'] == true
                                    ? 'VERIFIKASI GAGAL'
                                    : 'KREDENSIAL TIDAK DITEMUKAN'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _verificationResult!['isValid'] ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_verificationResult!['isValid']) ...[
                      const Text(
                        'Sertifikat ini sah, tercatat permanen di Ledger Blockchain AsuhKita, dan belum pernah direkayasa atau dimanipulasi.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      const Divider(height: 20),
                      _buildVerifyRow('No. Sertifikat', _verificationResult!['data']['certCode']),
                      _buildVerifyRow('Nama Donatur', _verificationResult!['data']['donor']),
                      _buildVerifyRow('Penerima Manfaat', _verificationResult!['data']['child']),
                      _buildVerifyRow('Panti Asuhan', _verificationResult!['data']['orphanage']),
                      _buildVerifyRow('Nominal Donasi', _verificationResult!['data']['amount']),
                      _buildVerifyRow('Waktu Pencatatan', _verificationResult!['data']['timestamp']),
                      const SizedBox(height: 8),
                      const Text('SHA-256 Blockchain Hash:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: SelectableText(
                          _verificationResult!['data']['hash'],
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black87),
                        ),
                      ),
                    ] else ...[
                      Text(
                        _verificationResult!['reason'],
                        style: TextStyle(fontSize: 13, color: Colors.red.shade900, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          const Text(': ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
