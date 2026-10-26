


import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../data/local_db.dart';
import '../communication/family_room_screen.dart';
import '../donation/donation_form_screen.dart';
import '../schedule/schedule_screen.dart';

class ChildDetailScreen extends StatefulWidget {
  final Map<String, dynamic> childData;

  const ChildDetailScreen({super.key, required this.childData});

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  int _selectedPackageIndex = 0;
  bool _isSponsoredByMe = false;
  int _myTotalDonation = 0;
  List<Map<String, dynamic>> _myDonations = [];

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
  void initState() {
    super.initState();
    _checkSponsorshipStatus();
  }

  Future<void> _checkSponsorshipStatus() async {
    try {
      final childAlias = (widget.childData['alias'] ?? widget.childData['name'] ?? '').toString().trim().toLowerCase();
      final localDonations = await LocalDatabase().getCachedDonations();
      int total = 0;
      final matched = <Map<String, dynamic>>[];

      for (var d in localDonations) {
        final dAlias = (d['child_alias'] ?? '').toString().trim().toLowerCase();
        if (dAlias == childAlias) {
          matched.add(d);
          final amt = (d['amount_idr'] is num) ? (d['amount_idr'] as num).toInt() : 0;
          total += amt;
        }
      }

      if (mounted) {
        setState(() {
          _isSponsoredByMe = matched.isNotEmpty;
          _myTotalDonation = total;
          _myDonations = matched;
        });
      }
    } catch (_) {}
  }

  String _formatRupiah(num value) {
    return 'Rp ${value.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.")}';
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.childData;
    final alias = (child['alias'] ?? child['name'] ?? 'Anak Asuh').toString();
    final age = child['age'] ?? 8;
    final gender = child['gender'] ?? 'Laki-laki';
    final city = child['orphanage_city'] ?? child['city'] ?? 'Mataram, NTB';
    final orphanage = child['orphanage_name'] ?? 'Peduli Anak Foundation';
    final dream = (child['dream'] != null && child['dream'].toString().trim().isNotEmpty) ? child['dream'].toString().trim() : '-';
    final hobby = (child['hobby'] != null && child['hobby'].toString().trim().isNotEmpty) ? child['hobby'].toString().trim() : '-';
    final category = child['need_category'] ?? child['urgentNeeds'] ?? 'Pendidikan';
    final targetNum = (child['target'] is num) ? (child['target'] as num).toDouble() : 500000.0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Profil $alias'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Kirim Pesan (Ruang Kasih)',
            icon: const Icon(Icons.chat_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamilyRoomScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Jadwalkan Video Call',
            icon: const Icon(Icons.video_call_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduleScreen()),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
              label: const Text(
                'Lanjut ke Form Donasi & Sertifikat',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
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
                    alias,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Usia: $age Tahun • $gender',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.apartment, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '$orphanage ($city)',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),


            if (_isSponsoredByMe)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade50, Colors.orange.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade400, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.amber.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.workspace_premium, color: Colors.amber, size: 26),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '🌟 Anak Asuh Anda (Aktif Didampingi)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF8B6914)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Alhamdulillah! Anda tercatat sebagai Orang Tua Asuh resmi ananda $alias dengan akumulasi kontribusi ${_formatRupiah(_myTotalDonation)} (${_myDonations.length}x transaksi).',
                      style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const FamilyRoomScreen()),
                              );
                            },
                            icon: const Icon(Icons.chat, size: 16),
                            label: const Text('Ruang Kasih', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ScheduleScreen()),
                              );
                            },
                            icon: const Icon(Icons.videocam, size: 16),
                            label: const Text('Video Call', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text('Data Lengkap & Biodata Anak', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                          const Divider(height: 20),
                          _buildDataRow(Icons.school_outlined, 'Jenjang Pendidikan', 'Kelas ${(age is int && age > 6) ? (age - 6) : 3} Sekolah Dasar'),
                          _buildDataRow(Icons.lightbulb_outline, 'Cita-Cita / Impian', dream),
                          _buildDataRow(Icons.sports_soccer_outlined, 'Hobi & Minat', hobby),
                          _buildDataRow(Icons.location_on_outlined, 'Lokasi Panti', city),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),


                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.auto_stories_outlined, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text('Cerita Kehidupan & Harapan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                          const Divider(height: 20),
                          Text(
                            child['story_summary'] ?? child['story'] ?? 'Anak yang rajin belajar, penuh semangat dan gemar menghafal doa serta giat membantu teman-temannya di panti asuhan.',
                            style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),


                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pie_chart_outline, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Target Pemenuhan Kebutuhan',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    category.toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Target Dana Kebutuhan:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              Text(_formatRupiah(targetNum), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: targetNum > 0 ? (_myTotalDonation / targetNum).clamp(0.0, 1.0) : 0.0,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Terkumpul: ${_formatRupiah(_myTotalDonation)} (${targetNum > 0 ? ((_myTotalDonation / targetNum) * 100).toInt() : 0}%)',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),


                  const Text(
                    'Pilih Paket Sponsorship Orang Tua Asuh',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Dukungan Anda disalurkan secara transparan dan tercatat di blockchain ledger.',
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
                                        '${_formatRupiah(pkg['monthly_idr'])} / bulan',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          const Text(': ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
        ],
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
    if (url.startsWith('assets/')) {
      return Image.asset(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.white, child: const Icon(Icons.face, size: 64, color: AppColors.primary)));
    }
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
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
