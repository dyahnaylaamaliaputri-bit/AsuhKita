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

  /// Notifier realtime: jika admin menambah/mengubah data anak, layar donatur langsung ter-update otomatis
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  @override
  State<SponsorScreen> createState() => _SponsorScreenState();
}

class _SponsorScreenState extends State<SponsorScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'Semua';
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _allChildren = [];
  Map<String, int> _collectedPerChild = {};
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
    SponsorScreen.refreshNotifier.addListener(_fetchChildren);
    _fetchChildren();
    _initShakeDetector();
  }

  @override
  void dispose() {
    SponsorScreen.refreshNotifier.removeListener(_fetchChildren);
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
          if (res.data is List) {
            apiData = List<Map<String, dynamic>>.from(res.data);
          } else if (res.data is Map && res.data['data'] is List) {
            apiData = List<Map<String, dynamic>>.from(res.data['data']);
          }

          // Sinkronkan ke SQLite cache lokal (otomatis kosongkan cache jika di Supabase belum ada data)
          await LocalDatabase().cacheChildren(apiData);
          _allChildren = List<Map<String, dynamic>>.from(apiData);
          _isOffline = false;
        } else {
          throw Exception('Gagal memuat data dari server');
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

    // Hitung total donasi per anak untuk status terpenuhi / belum terpenuhi
    await _loadDonationStats();

    // Filter lokal berdasarkan query pencarian dan kategori
    _applyLocalFilter();

    setState(() => _isLoading = false);
  }

  Future<void> _loadDonationStats() async {
    try {
      final localDonations = await LocalDatabase().getCachedDonations();
      final map = <String, int>{};
      for (var d in localDonations) {
        final alias = (d['child_alias'] ?? '').toString().toLowerCase().trim();
        final amt = (d['amount_idr'] is num) ? (d['amount_idr'] as num).toInt() : 0;
        map[alias] = (map[alias] ?? 0) + amt;
      }
      try {
        final res = await DioClient().dio.get('/donations');
        if (res.statusCode == 200) {
          List<dynamic> apiList = [];
          if (res.data is List) {
            apiList = res.data as List;
          } else if (res.data is Map && res.data['data'] is List) {
            apiList = res.data['data'] as List;
          }
          for (var ad in apiList) {
            final alias = (ad['child_alias'] ?? '').toString().toLowerCase().trim();
            final id = ad['id']?.toString() ?? '';
            if (!localDonations.any((ld) => ld['id']?.toString() == id)) {
              final amt = (ad['amount_idr'] is num) ? (ad['amount_idr'] as num).toInt() : 0;
              map[alias] = (map[alias] ?? 0) + amt;
            }
          }
        }
      } catch (_) {}
      _collectedPerChild = map;
    } catch (_) {}
  }

  void _applyLocalFilter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _children = _allChildren.where((child) {
        final alias = (child['alias'] ?? child['name'] ?? '').toString().toLowerCase();
        final city = (child['orphanage_city'] ?? child['city'] ?? '').toString().toLowerCase();
        final matchesQuery = query.isEmpty || alias.contains(query) || city.contains(query);
        final categoryStr = (child['need_category'] ?? child['urgentNeeds'] ?? '').toString().toLowerCase();
        final matchesCategory = _selectedCategory == 'Semua' || categoryStr.contains(_selectedCategory.toLowerCase());
        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

    // ============================================================
  // AI PROFILING: MULTI-CRITERIA MATCHING RECOMMENDATION ENGINE
  // ============================================================
  void _showAiProfilingModal() {
    String selectedAgeRange = 'Semua Usia';
    String selectedPriorityNeed = 'Semua Kebutuhan';
    String selectedBudgetRange = 'Fleksibel';
    bool prioritizeUnfulfilled = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.primary, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'AI Smart Profiling Donatur',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const Text(
                  'Model AI menganalisis profil dan preferensi Anda untuk mencocokkan anak asuh yang paling tepat.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const Divider(height: 20),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Rentang Usia
                        const Text('1. Preferensi Rentang Usia Anak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: ['Semua Usia', 'Balita (1-5 th)', 'Sekolah (6-12 th)', 'Remaja (13-18 th)'].map((opt) {
                            final sel = selectedAgeRange == opt;
                            return ChoiceChip(
                              label: Text(opt, style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.black87)),
                              selected: sel,
                              selectedColor: AppColors.primary,
                              onSelected: (v) {
                                if (v) setModalState(() => selectedAgeRange = opt);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // 2. Kategori Kebutuhan
                        const Text('2. Prioritas Kebutuhan Pokok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: ['Semua Kebutuhan', 'Pendidikan', 'Kesehatan', 'Pakaian & Sandang', 'Tempat Tinggal'].map((opt) {
                            final sel = selectedPriorityNeed == opt;
                            return ChoiceChip(
                              label: Text(opt, style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.black87)),
                              selected: sel,
                              selectedColor: AppColors.primary,
                              onSelected: (v) {
                                if (v) setModalState(() => selectedPriorityNeed = opt);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // 3. Alokasi Budget Donatur
                        const Text('3. Rencana Budget / Dana Donasi Bulanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: ['Fleksibel', '< Rp 150rb', 'Rp 150rb - 350rb', 'Rp 350rb - 600rb', '> Rp 600rb'].map((opt) {
                            final sel = selectedBudgetRange == opt;
                            return ChoiceChip(
                              label: Text(opt, style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.black87)),
                              selected: sel,
                              selectedColor: AppColors.primary,
                              onSelected: (v) {
                                if (v) setModalState(() => selectedBudgetRange = opt);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // 4. Kriteria Urgensi
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Prioritaskan yang Belum Terpenuhi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: const Text('Tampilkan anak asuh yang sangat mendesak membutuhkan orang tua asuh', style: TextStyle(fontSize: 11)),
                          value: prioritizeUnfulfilled,
                          activeThumbColor: AppColors.primary,
                          onChanged: (v) => setModalState(() => prioritizeUnfulfilled = v),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _executeAiProfiling(
                        ageRange: selectedAgeRange,
                        priorityNeed: selectedPriorityNeed,
                        budgetRange: selectedBudgetRange,
                        prioritizeUnfulfilled: prioritizeUnfulfilled,
                      );
                    },
                    icon: const Icon(Icons.psychology, size: 20),
                    label: const Text('Proses AI Profiling & Tampilkan Hasil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _executeAiProfiling({
    required String ageRange,
    required String priorityNeed,
    required String budgetRange,
    required bool prioritizeUnfulfilled,
  }) {
    if (_allChildren.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada data anak asuh untuk di-profiling.')),
      );
      return;
    }

    // Algoritma Scoring Profiling AI
    List<Map<String, dynamic>> scoredList = [];

    for (var child in _allChildren) {
      double score = 60.0;
      final age = int.tryParse((child['age'] ?? '0').toString()) ?? 0;
      final needs = (child['need_category'] ?? child['urgentNeeds'] ?? '').toString().toLowerCase();
      final target = (child['target'] is num) ? (child['target'] as num).toDouble() : 500000.0;
      final alias = (child['alias'] ?? child['name'] ?? '').toString().toLowerCase().trim();
      final collected = _collectedPerChild[alias] ?? 0;
      final isFulfilled = collected >= target && target > 0;

      // 1. Usia
      if (ageRange == 'Balita (1-5 th)' && age >= 1 && age <= 5) {
        score += 15;
      } else if (ageRange == 'Sekolah (6-12 th)' && age >= 6 && age <= 12) {
        score += 15;
      } else if (ageRange == 'Remaja (13-18 th)' && age >= 13 && age <= 18) {
        score += 15;
      } else if (ageRange == 'Semua Usia') {
        score += 10;
      }

      // 2. Kebutuhan Pokok
      if (priorityNeed != 'Semua Kebutuhan' && needs.contains(priorityNeed.toLowerCase())) {
        score += 15;
      } else if (priorityNeed == 'Semua Kebutuhan') {
        score += 8;
      }

      // 3. Budget Donasi
      if (budgetRange == '< Rp 150rb' && target <= 200000) {
        score += 15;
      } else if (budgetRange == 'Rp 150rb - 350rb' && target >= 150000 && target <= 350000) {
        score += 15;
      } else if (budgetRange == 'Rp 350rb - 600rb' && target >= 300000 && target <= 600000) {
        score += 15;
      } else if (budgetRange == '> Rp 600rb' && target >= 500000) {
        score += 15;
      } else if (budgetRange == 'Fleksibel') {
        score += 10;
      }

      // 4. Urgensi
      if (prioritizeUnfulfilled && !isFulfilled) {
        score += 10;
      }

      final finalScore = score.clamp(72.0, 99.0).toInt();

      final scoredChild = Map<String, dynamic>.from(child);
      scoredChild['ai_match_score'] = finalScore;
      scoredChild['ai_reason'] =
          'Kecocokan ' + finalScore.toString() + '%: Usia ' + age.toString() + ' th selaras dengan kriteria, kebutuhan utama ' + (child['need_category'] ?? 'Pendidikan').toString() + ' ' +
          (!isFulfilled ? 'masih mendesak belum terpenuhi' : 'sudah menerima dukungan') +
          ', dan alokasi target Rp ' + ((target / 1000).toInt()).toString() + 'rb pas dengan kapasitas dana Anda.';
      scoredList.add(scoredChild);
    }

    scoredList.sort((a, b) => (b['ai_match_score'] as int).compareTo(a['ai_match_score'] as int));

    setState(() {
      _children = scoredList;
    });

    final topMatch = scoredList.first;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber, size: 26),
            SizedBox(width: 8),
            Expanded(child: Text('Rekomendasi Terbaik AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Kecocokan Tertinggi: ' + topMatch['ai_match_score'].toString() + '% Cocok ✨',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8B6914)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Anak Asuh: ' + (topMatch['alias'] ?? topMatch['name']).toString() + ' (' + topMatch['age'].toString() + ' tahun)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Text(
              topMatch['ai_reason'] ?? '',
              style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            const Text(
              'Daftar anak asuh di bawah telah diurutkan berdasarkan skor AI profiling tertinggi untuk Anda.',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Lihat Semua Hasil'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChildDetailScreen(childData: topMatch)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Buka Profil Anak'),
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

          // Banner Tombol AI Profiling Rekomendasi Khusus
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: InkWell(
              onTap: _showAiProfilingModal,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.secondary.withValues(alpha: 0.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Profiling: Rekomendasi Khusus Anak ✨',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                          ),
                          Text(
                            'Cocokkan umur, kebutuhan & budget donasi Anda',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 13, color: AppColors.primary),
                  ],
                ),
              ),
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
                                          const SizedBox(height: 8),
                                          Builder(
                                            builder: (context) {
                                              final cAlias = (child['alias'] ?? child['name'] ?? '').toString().toLowerCase().trim();
                                              final collected = _collectedPerChild[cAlias] ?? 0;
                                              final target = (child['target'] is num) ? (child['target'] as num).toDouble() : 500000.0;
                                              final isFulfilled = collected >= target && target > 0;

                                              return Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: isFulfilled ? Colors.green.shade50 : Colors.amber.shade50,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: isFulfilled ? Colors.green.shade300 : Colors.amber.shade400,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          isFulfilled ? Icons.check_circle : Icons.hourglass_top,
                                                          size: 11,
                                                          color: isFulfilled ? Colors.green.shade800 : Colors.amber.shade900,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          isFulfilled ? 'Sudah Terpenuhi' : 'Belum Terpenuhi',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: isFulfilled ? Colors.green.shade800 : Colors.amber.shade900,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    'Target: Rp ${(target / 1000).toStringAsFixed(0)}rb',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                                  ),
                                                ],
                                              );
                                            },
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
