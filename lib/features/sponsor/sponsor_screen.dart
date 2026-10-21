// Letak file: mobile/lib/features/sponsor/sponsor_screen.dart
// Fungsi: UI Pencarian & Filter Anak Asuh (Tab Sponsor), Integrasi Cache SQLite Offline, dan Shake-to-Refresh (PBI-018, PBI-019, PBI-020, PBI-052)

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../data/local_db.dart';
import '../../core/dio_client.dart';
import 'child_detail_screen.dart';

class SponsorScreen extends StatefulWidget {
  const SponsorScreen({super.key});

  @override
  State<SponsorScreen> createState() => _SponsorScreenState();
}

class _SponsorScreenState extends State<SponsorScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'Semua';
  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;
  bool _isOffline = false;

  // Sensor Stream untuk Shake-to-Refresh (PBI-052, FR-45)
  StreamSubscription? _accelerometerSubscription;
  DateTime _lastShakeTime = DateTime.now();

  final List<String> _categories = [
    'Semua',
    'Pendidikan',
    'Kebutuhan Sehari-hari',
    'Perawatan Esensial',
  ];

  // Data anak asuh dari Yayasan Peduli Anak (pedulianak.org)
  final List<Map<String, dynamic>> _dummyChildren = [
    {
      'id': 'c1',
      'orphanage_id': 'o1',
      'alias': 'Arfa',
      'age': 8,
      'need_category': 'Pendidikan',
      'story_summary': 'Arfa adalah anak yang ceria dan penuh semangat belajar di Pusat Peduli Anak Lombok. Bercita-cita menjadi arsitek dan sangat menyukai matematika.',
      'avatar': 'https://www.pedulianak.org/wp-content/uploads/2025/08/6-200x300.jpg',
      'status': 'Tersedia',
      'orphanage_name': 'Peduli Anak Foundation',
      'orphanage_city': 'Lombok Barat',
    },
    {
      'id': 'c2',
      'orphanage_id': 'o1',
      'alias': 'Ayra',
      'age': 6,
      'need_category': 'Kebutuhan Sehari-hari',
      'story_summary': 'Ayra adalah anak periang yang suka menggambar pemandangan alam. Membutuhkan dukungan nutrisi, pakaian, dan perlengkapan harian.',
      'avatar': 'https://www.pedulianak.org/wp-content/uploads/2026/07/Ayra-200x300.jpg',
      'status': 'Tersedia',
      'orphanage_name': 'Peduli Anak Foundation',
      'orphanage_city': 'Lombok Barat',
    },
    {
      'id': 'c3',
      'orphanage_id': 'o1',
      'alias': 'Azkya',
      'age': 9,
      'need_category': 'Pendidikan',
      'story_summary': 'Azkya rajin membaca buku cerita dan bercita-cita menjadi guru SD. Membutuhkan seragam sekolah, tas, dan buku-buku pelajaran.',
      'avatar': 'https://www.pedulianak.org/wp-content/uploads/2026/07/DSCF6859-200x300.jpg',
      'status': 'Tersedia',
      'orphanage_name': 'Peduli Anak Foundation',
      'orphanage_city': 'Lombok Tengah',
    },
    {
      'id': 'c4',
      'orphanage_id': 'o1',
      'alias': 'Elsa Saputri',
      'age': 10,
      'need_category': 'Perawatan Esensial',
      'story_summary': 'Elsa anak yang mandiri dan peduli pada teman-temannya di asrama. Membutuhkan dukungan biaya kesehatan berkala dan suplemen vitamin.',
      'avatar': 'https://www.pedulianak.org/wp-content/uploads/2026/07/DSCF6838-200x300.jpg',
      'status': 'Tersedia',
      'orphanage_name': 'Peduli Anak Sumbawa',
      'orphanage_city': 'Sumbawa',
    },
    {
      'id': 'c5',
      'orphanage_id': 'o1',
      'alias': 'Rangga',
      'age': 11,
      'need_category': 'Pendidikan',
      'story_summary': 'Rangga gemar berolahraga sepak bola dan sains alam. Sangat antusias mengikuti kegiatan les ekstrakurikuler sains di panti asuhan.',
      'avatar': 'https://www.pedulianak.org/wp-content/uploads/2026/07/DSCF6843-200x300.jpg',
      'status': 'Tersedia',
      'orphanage_name': 'Peduli Anak Foundation',
      'orphanage_city': 'Lombok Utara',
    },
    {
      'id': 'c6',
      'orphanage_id': 'o1',
      'alias': 'Sasmita',
      'age': 7,
      'need_category': 'Kebutuhan Sehari-hari',
      'story_summary': 'Sasmita menyukai kesenian tari tradisional dan menyanyi. Memerlukan bantuan paket makanan bergizi seimbang dan susu pertumbuhan.',
      'avatar': 'https://www.pedulianak.org/wp-content/uploads/2026/08/DSCF8123-200x300.jpg',
      'status': 'Tersedia',
      'orphanage_name': 'Peduli Anak Mataram',
      'orphanage_city': 'Mataram',
    },
    {
      'id': 'c7',
      'orphanage_id': 'o1',
      'alias': 'Seregar',
      'age': 12,
      'need_category': 'Pendidikan',
      'story_summary': 'Seregar adalah siswa berprestasi di sekolah menengah dan memiliki cita-cita menjadi insinyur teknik elektro masa depan.',
      'avatar': 'https://www.pedulianak.org/wp-content/uploads/2026/08/DSCF7024-200x300.jpg',
      'status': 'Tersedia',
      'orphanage_name': 'Peduli Anak Foundation',
      'orphanage_city': 'Praya',
    },
    {
      'id': 'c8',
      'orphanage_id': 'o1',
      'alias': 'Shiddiq',
      'age': 9,
      'need_category': 'Kebutuhan Sehari-hari',
      'story_summary': 'Shiddiq anak yang santun dan suka membantu pengurus panti merawat taman. Membutuhkan perlengkapan sekolah dan pakaian asrama.',
      'avatar': 'https://www.pedulianak.org/wp-content/uploads/2026/08/DSCF8114-200x300.jpg',
      'status': 'Tersedia',
      'orphanage_name': 'Peduli Anak Foundation',
      'orphanage_city': 'Lombok Barat',
    },
    {
      'id': 'c9',
      'orphanage_id': 'o1',
      'alias': 'Hamdi',
      'age': 13,
      'need_category': 'Pendidikan',
      'story_summary': 'Hamdi gemar mempelajari teknologi komputer dan aktif memimpin kegiatan doa bersama adik-adik di panti asuhan.',
      'avatar': 'https://www.pedulianak.org/wp-content/uploads/2022/10/Hamdi.jpg',
      'status': 'Tersedia',
      'orphanage_name': 'Peduli Anak Foundation',
      'orphanage_city': 'Lombok Barat',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchChildren();
    _initShakeDetector();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  // Sensor Accelerometer: Goyangkan HP untuk refresh data (PBI-052, FR-45)
  void _initShakeDetector() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      // Deteksi ambang shake (> 22 m/s²) dengan debounce minimal 2 detik
      if (acceleration > 22) {
        final now = DateTime.now();
        if (now.difference(_lastShakeTime).inSeconds > 2) {
          _lastShakeTime = now;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sensor Goyang (Shake) terdeteksi! Memperbarui data anak...'),
                backgroundColor: Colors.teal,
                duration: Duration(seconds: 1),
              ),
            );
            _fetchChildren();
          }
        }
      }
    });
  }

  Future<void> _fetchChildren() async {
    setState(() => _isLoading = true);

    try {
      // 1. Coba ambil dari online API
      final res = await DioClient().dio.get('/children');
      if (res.statusCode == 200 && res.data is List) {
        final List<Map<String, dynamic>> apiData = List<Map<String, dynamic>>.from(res.data);
        // Simpan ke SQLite cache untuk offline mode (PBI-020, FR-19)
        await LocalDatabase().cacheChildren(apiData);
        _children = apiData;
        _isOffline = false;
      }
    } catch (e) {
      // 2. Jika offline/gagal, baca dari SQLite cache lokal (FR-19, NFR-03)
      _isOffline = true;
      final cached = await LocalDatabase().getCachedChildren(
        query: _searchController.text.trim(),
        category: _selectedCategory,
      );

      if (cached.isNotEmpty) {
        _children = cached;
      } else {
        // Jika DB pertama kali kosong, inisialisasi dummy ke SQLite cache
        await LocalDatabase().cacheChildren(_dummyChildren);
        _children = await LocalDatabase().getCachedChildren();
      }
    }

    // Filter lokal berdasarkan query pencarian dan kategori
    _applyLocalFilter();

    setState(() => _isLoading = false);
  }

  void _applyLocalFilter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _children = _dummyChildren.where((child) {
        final matchesQuery = query.isEmpty ||
            child['alias'].toString().toLowerCase().contains(query) ||
            child['orphanage_city'].toString().toLowerCase().contains(query);
        final matchesCategory = _selectedCategory == 'Semua' || child['need_category'] == _selectedCategory;
        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Anak Asuh (Sponsor)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Perbarui Data (Bisa juga goyangkan HP)',
            onPressed: _fetchChildren,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Status Offline jika koneksi internet terputus (FR-19)
          if (_isOffline)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 18, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mode Offline: Menampilkan data tersimpan di cache SQLite.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Header Search Bar (PBI-018, FR-15)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyLocalFilter(),
                  decoration: InputDecoration(
                    hintText: 'Cari nama samaran anak atau kota...',
                    prefixIcon: const Icon(Icons.search, color: Colors.teal),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _applyLocalFilter();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Kategori Filter Kebutuhan (PBI-018, FR-16)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: Colors.teal,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedCategory = cat);
                              _applyLocalFilter();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Daftar Kartu Anak Asuh (PBI-018, FR-17)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                : _children.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('Tidak ada anak asuh yang cocok.', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _children.length,
                        itemBuilder: (context, index) {
                          final child = _children[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChildDetailScreen(childData: child),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    // Foto Profil Anak dari Peduli Anak (FR-17, NFR-06)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: SizedBox(
                                        width: 72,
                                        height: 72,
                                        child: (child['avatar'] != null && child['avatar'].toString().startsWith('http'))
                                            ? Image.network(
                                                child['avatar'].toString(),
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, childWidget, progress) {
                                                  if (progress == null) return childWidget;
                                                  return Container(
                                                    color: Colors.teal.shade50,
                                                    child: const Center(
                                                      child: SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                                                      ),
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error, stackTrace) => Container(
                                                  color: Colors.teal.shade50,
                                                  child: const Icon(Icons.face, size: 40, color: Colors.teal),
                                                ),
                                              )
                                            : Container(
                                                color: Colors.teal.shade50,
                                                child: const Icon(Icons.face, size: 40, color: Colors.teal),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${child['alias']} (${child['age']} th)',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.teal.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  child['need_category'] ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.teal,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            child['story_summary'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${child['orphanage_name']} • ${child['orphanage_city']}',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                              ),
                                            ],
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
          ),
        ],
      ),
    );
  }
}
