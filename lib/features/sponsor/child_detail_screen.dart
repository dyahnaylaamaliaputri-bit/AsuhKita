// Letak file: mobile/lib/features/sponsor/child_detail_screen.dart
// Fungsi: Layar Detail Profil Anak Asuh & Pemilihan Paket Sponsorship (PBI-019, FR-17, FR-18)

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../donation/donation_form_screen.dart';

class ChildDetailScreen extends StatefulWidget {
  final Map<String, dynamic> childData;

  const ChildDetailScreen({super.key, required this.childData});

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  // Pilihan Paket Sponsorship yang tersedia
  int _selectedPackageIndex = 0;

  final List<Map<String, dynamic>> _packages = [
    {
      'id': 'pkg_pendidikan',
      'name': 'Paket Pendidikan Cemerlang',
      'desc': 'Buku pelajaran, seragam sekolah, tas, sepatu, dan uang SPP.',
      'monthly_idr': 250000,
    },
    {
      'id': 'pkg_harian',
      'name': 'Paket Nutrisi & Harian',
      'desc': 'Kebutuhan makan bergizi 3x sehari, susu berkalsium, dan vitamin.',
      'monthly_idr': 150000,
    },
    {
      'id': 'pkg_lengkap',
      'name': 'Paket Asuh Komprehensif',
      'desc': 'Mencakup seluruh biaya pendidikan, nutrisi, bimbingan belajar, & kesehatan.',
      'monthly_idr': 400000,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final child = widget.childData;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Profil ${child['alias'] ?? child['name'] ?? 'Anak'}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Ilustrasi & Nama Anak (NFR-06: nama samaran & avatar ilustrasi)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              color: AppColors.surfaceLight,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child: _buildAvatar(child),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${child['alias'] ?? child['name'] ?? 'Anak Asuh'}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Usia: ${child['age'] ?? '-'} Tahun • Fokus: ${child['need_category'] ?? child['urgentNeeds'] ?? ''}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.apartment, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${child['orphanage_name'] ?? 'Peduli Anak'} (${child['orphanage_city'] ?? child['city'] ?? ''})',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cerita Singkat Anak
                  const Text(
                    'Cerita & Aspirasi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      child['story_summary'] ?? child['story'] ?? 'Anak yang penuh semangat dan rajin beribadah serta belajar di panti asuhan.',
                      style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pilihan Paket Sponsorship (FR-18)
                  const Text(
                    'Pilih Paket Sponsorship Orang Tua Asuh',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Dukungan Anda disalurkan secara transparan dan tercatat di blockchain.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _packages.length,
                    itemBuilder: (context, idx) {
                      final pkg = _packages[idx];
                      final isSelected = _selectedPackageIndex == idx;

                      return Card(
                        elevation: isSelected ? 3 : 1,
                        color: isSelected ? AppColors.surfaceLight : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _selectedPackageIndex = idx),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pkg['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        pkg['desc'],
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Rp ${pkg['monthly_idr'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} / bulan',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Tombol Lanjut ke Donasi
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DonationFormScreen(
                                  childData: child,
                                  packageData: _packages[_selectedPackageIndex],
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.favorite),
                          label: const Text('Lanjut ke Form Donasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> child) {
    final url = (child['avatar'] ?? child['photo'] ?? '').toString();
    if (url.startsWith('data:image')) {
      try {
        final bytes = Uri.parse(url).data?.contentAsBytes();
        if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, childWidget, progress) {
          if (progress == null) return childWidget;
          return Container(
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.white,
          child: const Icon(Icons.face, size: 64, color: AppColors.primary),
        ),
      );
    }
    return Container(
      color: Colors.white,
      child: const Icon(Icons.face, size: 64, color: AppColors.primary),
    );
  }
}
