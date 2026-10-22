// Letak file: mobile/lib/features/sponsor/sponsor_screen.dart
// Fungsi: UI Pencarian & Filter Anak Asuh (Tab Sponsor), Integrasi Cache SQLite Offline, dan Shake-to-Refresh (PBI-018, PBI-019, PBI-020, PBI-052)

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/app_colors.dart';
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
  List<Map<String, dynamic>> _allChildren = [];
  bool _isLoading = true;
  bool _isOffline = false;
  bool _forceOfflineMode = false;

  // Sensor Stream untuk Shake-to-Refresh (PBI-052, FR-45)
  StreamSubscription? _accelerometerSubscription;
  DateTime _lastShakeTime = DateTime.now();

  // Kategori kebutuhan — SAMA dengan admin (unified)
  final List<String> _categories = AppColors.needCategories;

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
      if (acceleration > 22) {
        final now = DateTime.now();
        if (now.difference(_lastShakeTime).inSeconds > 2) {
          _lastShakeTime = now;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sensor Goyang (Shake) terdeteksi! Memperbarui data anak...'),
                backgroundColor: AppColors.primary,
                duration: Duration(seconds: 1),
              ),
            );
            _fetchChildren();
          }
        }
      }
    });
  }

  Future<void> _fetchChildren({bool? forceOffline}) async {
    setState(() => _isLoading = true);
    if (forceOffline != null) {
      _forceOfflineMode = forceOffline;
    }

    if (_forceOfflineMode) {
      // Mode offline manual (demonstrasi cache SQLite)
      _isOffline = true;
      final cached = await LocalDatabase().getCachedChildren(
        query: _searchController.text.trim(),
        category: _selectedCategory,
      );
      _allChildren = cached;
    } else {
      try {
        // 1. Coba ambil dari online API Supabase
        final res = await DioClient().dio.get('/children');
        List<Map<String, dynamic>> apiData = [];
        if (res.statusCode == 200) {
          if (res.data is List && (res.data as List).isNotEmpty) {
            apiData = List<Map<String, dynamic>>.from(res.data);
          } else if (res.data is Map && res.data['data'] is List) {
            apiData = List<Map<String, dynamic>>.from(res.data['data']);
          }
        }

        if (apiData.isNotEmpty) {
          // Simpan ke SQLite cache untuk offline mode (PBI-020, FR-19)
          await LocalDatabase().cacheChildren(apiData);
          _allChildren = apiData;
          _isOffline = false;
        } else {
          throw Exception('Data kosong atau gagal');
        }
      } catch (e) {
        // 2. Jika offline/gagal, baca dari SQLite cache lokal (FR-19, NFR-03)
        _isOffline = true;
        final cached = await LocalDatabase().getCachedChildren(
          query: _searchController.text.trim(),
          category: _selectedCategory,
        );
        _allChildren = cached;
      }
    }

    // Juga ambil anak yang di-input admin lokal
    try {
      final newKids = await LocalDatabase().getNewChildren();
      if (newKids.isNotEmpty) {
        final existingIds = _allChildren.map((c) => (c['name'] ?? c['alias'] ?? '').toString().toLowerCase()).toSet();
        for (var k in newKids) {
          final name = (k['name'] ?? k['alias'] ?? '').toString().toLowerCase();
          if (name.isNotEmpty && !existingIds.contains(name)) {
            _allChildren.add(k);
          }
        }
      }
    } catch (_) {}

    // Filter lokal berdasarkan query pencarian dan kategori
    _applyLocalFilter();

    setState(() => _isLoading = false);
  }

  void _applyLocalFilter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _children = _allChildren.where((child) {
        final alias = (child['alias'] ?? child['name'] ?? '').toString().toLowerCase();
        final city = (child['orphanage_city'] ?? child['city'] ?? '').toString().toLowerCase();
        final matchesQuery = query.isEmpty || alias.contains(query) || city.contains(query);
        final category = child['need_category'] ?? child['urgentNeeds'] ?? '';
        final matchesCategory = _selectedCategory == 'Semua' || category == _selectedCategory;
        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Anak Asuh (Sponsor)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isOffline ? Icons.cloud_off : Icons.cloud_done),
            tooltip: _isOffline ? 'Beralih ke Mode Online (Supabase)' : 'Beralih ke Mode Offline (SQLite)',
            onPressed: () {
              _fetchChildren(forceOffline: !_isOffline);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isOffline ? 'Beralih ke Mode Online (Supabase)...' : 'Beralih ke Mode Offline (Cache SQLite)...'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Perbarui Data (Bisa juga goyangkan HP)',
            onPressed: () => _fetchChildren(forceOffline: false),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Status Online (Supabase) / Offline (SQLite) (FR-19)
          if (_forceOfflineMode)
          Container(
            width: double.infinity,
            color: _isOffline ? AppColors.accent2.withValues(alpha: 0.4) : AppColors.accent1.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  _isOffline ? Icons.cloud_off : Icons.cloud_done,
                  size: 18,
                  color: _isOffline ? const Color(0xFF8B6914) : AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isOffline
                        ? 'Mode Offline: Menampilkan data tersimpan di cache SQLite.'
                        : 'Mode Online: Terhubung ke Cloud Database Supabase.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isOffline ? const Color(0xFF8B6914) : AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    _fetchChildren(forceOffline: !_isOffline);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isOffline ? AppColors.accent2 : AppColors.accent1,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _isOffline ? 'Coba Online' : 'Tes Offline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isOffline ? const Color(0xFF8B6914) : AppColors.primaryDark,
                      ),
                    ),
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
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
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
                    fillColor: AppColors.surfaceLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Kategori Filter Kebutuhan — SERAGAM dengan admin (PBI-018, FR-16)
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
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _children.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 60, color: AppColors.primary.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text('Belum ada anak asuh terdaftar.', style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            const Text('Data akan muncul setelah admin menambahkan.', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
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
                                    // Foto Profil Anak (FR-17, NFR-06)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: SizedBox(
                                        width: 72,
                                        height: 72,
                                        child: _buildAvatar(child),
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
                                              Expanded(
                                                child: Text(
                                                  '${child['alias'] ?? child['name'] ?? 'Anak'} (${child['age'] ?? '-'} th)',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceLight,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  child['need_category'] ?? child['urgentNeeds'] ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.primaryDark,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            child['story_summary'] ?? child['story'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  '${child['orphanage_name'] ?? 'Peduli Anak'} • ${child['orphanage_city'] ?? child['city'] ?? ''}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                ),
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

  Widget _buildAvatar(Map<String, dynamic> child) {
    final avatarUrl = (child['avatar'] ?? child['photo'] ?? '').toString();
    if (avatarUrl.startsWith('data:image')) {
      try {
        final bytes = base64Decode(avatarUrl.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (avatarUrl.startsWith('http')) {
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, childWidget, progress) {
          if (progress == null) return childWidget;
          return Container(
            color: AppColors.surfaceLight,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppColors.surfaceLight,
          child: const Icon(Icons.face, size: 40, color: AppColors.primary),
        ),
      );
    }
    return Container(
      color: AppColors.surfaceLight,
      child: const Icon(Icons.face, size: 40, color: AppColors.primary),
    );
  }
}
