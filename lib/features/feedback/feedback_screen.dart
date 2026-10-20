// Letak file: mobile/lib/features/feedback/feedback_screen.dart
// Fungsi: Layar pengisian Saran dan Kesan Mata Kuliah Pemrograman Aplikasi Mobile (PAM) beserta riwayat pada halaman yang sama (PBI-012, FR-13)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../../core/dio_client.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _saranController = TextEditingController();
  final _kesanController = TextEditingController();
  int _rating = 5;
  bool _isSubmitting = false;

  // Riwayat feedback lokal / tersimpan
  final List<Map<String, dynamic>> _feedbackHistory = [
    {
      'name': 'Dyah Nayla (Mobile UI)',
      'rating': 5,
      'saran': 'Materi praktikum Flutter dan integrasi sensor mobile sangat seru jika ditambah contoh arsitektur Clean Code di pertemuan awal.',
      'kesan': 'Mata kuliah PAM sangat menantang dan bermanfaat untuk mengasah kemampuan membuat aplikasi mobile nyata berbasis multi-fitur!',
      'date': '2026-10-18',
    },
    {
      'name': 'Salsabila Yufli (Backend)',
      'rating': 5,
      'saran': 'Semoga ke depannya bisa ditambahkan materi deployment cloud & CI/CD otomatis untuk mobile API.',
      'kesan': 'Belajar mengintegrasikan REST API dengan Flutter dan simulasi blockchain memberi wawasan baru.',
      'date': '2026-10-19',
    },
  ];

  @override
  void dispose() {
    _saranController.dispose();
    _kesanController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      final auth = Provider.of<AuthProvider>(context, listen: false);

      final newFeedback = {
        'name': auth.userName.isNotEmpty ? auth.userName : 'Mahasiswa PAM',
        'rating': _rating,
        'saran': _saranController.text.trim(),
        'kesan': _kesanController.text.trim(),
        'date': DateTime.now().toString().substring(0, 10),
      };

      try {
        // Coba kirim ke endpoint backend jika aktif (POST /feedback)
        await DioClient().dio.post('/feedback', data: newFeedback);
      } catch (_) {
        // Fallback simpan lokal di state jika backend offline
      }

      setState(() {
        _feedbackHistory.insert(0, newFeedback);
        _saranController.clear();
        _kesanController.clear();
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saran & Kesan mata kuliah PAM berhasil disimpan!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Saran & Kesan PAM'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Formulir Pengisian
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Form Evaluasi Kuliah PAM',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kesan dan masukan untuk mata kuliah Pemrograman Aplikasi Mobile.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const Divider(height: 20),

                      // Rating Bintang
                      const Text('Penilaian Kepuasan Kuliah:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(5, (index) {
                          return IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 32,
                            ),
                            onPressed: () => setState(() => _rating = index + 1),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),

                      // Input Saran
                      TextFormField(
                        controller: _saranController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Saran untuk Mata Kuliah PAM',
                          hintText: 'Tuliskan saran Anda untuk perbaikan ke depan...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Saran wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),

                      // Input Kesan
                      TextFormField(
                        controller: _kesanController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Kesan selama Perkuliahan PAM',
                          hintText: 'Tuliskan pengalaman & kesan Anda belajar PAM...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Kesan wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      // Tombol Kirim
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitFeedback,
                          icon: const Icon(Icons.send),
                          label: const Text('Kirim Saran & Kesan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Riwayat Saran & Kesan di Halaman yang Sama (FR-13)
            const Text(
              'Riwayat Saran & Kesan PAM',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _feedbackHistory.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _feedbackHistory[index];
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              item['date'] ?? '',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(
                            item['rating'] ?? 5,
                            (_) => const Icon(Icons.star, color: Colors.amber, size: 16),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Saran: "${item['saran']}"',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kesan: "${item['kesan']}"',
                          style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
