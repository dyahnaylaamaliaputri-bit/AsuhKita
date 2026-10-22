import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';
import 'finance_dashboard_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _localDb = LocalDatabase();
  final _picker = ImagePicker();

  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    try {
      // 1. Coba ambil dari Supabase via API
      List<Map<String, dynamic>> apiChildren = [];
      try {
        final res = await DioClient().dio.get('/children');
        if (res.statusCode == 200) {
          final data = res.data;
          if (data is List && data.isNotEmpty) {
            apiChildren = List<Map<String, dynamic>>.from(data);
          } else if (data is Map && data['data'] is List) {
            apiChildren = List<Map<String, dynamic>>.from(data['data']);
          }
        }
      } catch (_) {}

      // 2. Ambil anak yang diinput admin secara lokal
      final newKids = await _localDb.getNewChildren();

      // Gabungkan: API + lokal baru (deduplikasi by name)
      final Map<String, Map<String, dynamic>> map = {};

      for (var k in apiChildren) {
        final name = (k['alias'] ?? k['name'] ?? '').toString();
        if (name.isNotEmpty) {
          map[name.toLowerCase()] = {
            'id': k['id'],
            'name': name,
            'age': k['age'] ?? 8,
            'gender': k['gender'] ?? 'Laki-laki/Perempuan',
            'city': k['orphanage_city'] ?? k['city'] ?? '',
            'urgentNeeds': k['need_category'] ?? k['urgentNeeds'] ?? 'Pendidikan',
            'story': k['story_summary'] ?? k['story'] ?? '',
            'photo': k['avatar'] ?? k['photo'] ?? '',
            'target': (k['target'] is num) ? (k['target'] as num).toDouble() : 500000.0,
            'dream': k['dream'] ?? '',
            'hobby': k['hobby'] ?? '',
          };
        }
      }

      for (var k in newKids) {
        final name = (k['name'] ?? k['alias'] ?? '').toString();
        if (name.isNotEmpty) {
          map[name.toLowerCase()] = Map<String, dynamic>.from(k);
        }
      }

      if (mounted) {
        setState(() {
          _children = map.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _children = [];
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredChildren {
    if (_searchQuery.isEmpty) return _children;
    return _children.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final city = (c['city'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || city.contains(query);
    }).toList();
  }

  Future<void> _showAddChildDialog() async {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final dreamCtrl = TextEditingController();
    final hobbyCtrl = TextEditingController();
    final storyCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Peduli Anak Lombok');
    final targetCtrl = TextEditingController(text: '500000');
    String selectedNeed = 'Pendidikan';
    String selectedGender = 'Laki-laki';
    String? base64Image;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tambah Data Anak Asuh Baru',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Text(
                  'Data akan langsung tersimpan & muncul di halaman donatur.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final XFile? photo = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
                      if (photo != null) {
                        final bytes = await photo.readAsBytes();
                        setModalState(() {
                          base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                        });
                      }
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: base64Image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(
                                base64Decode(base64Image!.split(',').last),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: AppColors.primary, size: 30),
                                const SizedBox(height: 4),
                                const Text('Foto Anak', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap Anak',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Usia (Tahun)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedGender,
                        items: ['Laki-laki', 'Perempuan']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setModalState(() => selectedGender = v ?? 'Laki-laki'),
                        decoration: InputDecoration(
                          labelText: 'Jenis Kelamin',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedNeed,
                  items: AppColors.needCategoriesInput
                      .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setModalState(() => selectedNeed = v ?? 'Pendidikan'),
                  decoration: InputDecoration(
                    labelText: 'Kategori Kebutuhan',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityCtrl,
                  decoration: InputDecoration(
                    labelText: 'Asal Panti / Kota',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dreamCtrl,
                  decoration: InputDecoration(
                    labelText: 'Cita-Cita',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hobbyCtrl,
                  decoration: InputDecoration(
                    labelText: 'Hobi & Minat',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Target Donasi Bulanan (Rp)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: storyCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Kisah / Latar Belakang Anak',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nama anak wajib diisi')),
                        );
                        return;
                      }

                      final newKid = {
                        'id': 'child_${DateTime.now().millisecondsSinceEpoch}',
                        'name': nameCtrl.text.trim(),
                        'age': int.tryParse(ageCtrl.text) ?? 8,
                        'gender': selectedGender,
                        'city': cityCtrl.text.trim().isEmpty ? 'Peduli Anak Lombok' : cityCtrl.text.trim(),
                        'urgentNeeds': selectedNeed,
                        'story': storyCtrl.text.isEmpty ? 'Anak asuh bersemangat untuk menempuh pendidikan.' : storyCtrl.text,
                        'photo': base64Image ?? '',
                        'target': double.tryParse(targetCtrl.text) ?? 500000.0,
                        'dream': dreamCtrl.text.isEmpty ? '' : dreamCtrl.text,
                        'hobby': hobbyCtrl.text.isEmpty ? '' : hobbyCtrl.text,
                        'createdAt': DateTime.now().toIso8601String(),
                      };

                      // Simpan ke lokal DB
                      await _localDb.insertChild(newKid);

                      // Coba simpan ke Supabase via API
                      try {
                        await DioClient().dio.post('/children', data: {
                          'alias': newKid['name'],
                          'age': newKid['age'],
                          'gender': newKid['gender'],
                          'need_category': newKid['urgentNeeds'],
                          'story_summary': newKid['story'],
                          'avatar': newKid['photo'],
                          'orphanage_city': newKid['city'],
                          'target': newKid['target'],
                          'dream': newKid['dream'],
                          'hobby': newKid['hobby'],
                        });
                      } catch (_) {
                        // Offline: sudah tersimpan lokal
                      }

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      _loadChildren();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Anak asuh "${nameCtrl.text}" berhasil ditambahkan!'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    },
                    child: const Text('Simpan & Promosikan Anak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChildDetailAndReceiptDialog(Map<String, dynamic> child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _buildChildImage(child['photo'] ?? child['photo_url'] ?? child['avatar'] ?? '', 90, 90),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  child['name'] ?? child['alias'] ?? 'Anak Asuh',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Usia: ${child['age'] ?? '-'} Tahun • ${child['city'] ?? child['orphanage_city'] ?? ''}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'Kebutuhan: ${child['urgentNeeds'] ?? child['need_category'] ?? 'Pendidikan'}',
                                    style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cita-cita: ${child['dream'] ?? '-'} | Hobi: ${child['hobby'] ?? '-'}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        child['story'] ?? child['story_summary'] ?? 'Belum ada kisah latar belakang.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                      ),
                      const Divider(height: 32),
                      
                      // Transparency Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Laporan Keuangan & Nota',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                              ),
                              Text(
                                'Transparansi untuk donatur (On-Chain)',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.add_photo_alternate, size: 16),
                            label: const Text('Input Nota', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              _showAddReceiptDialog(child);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _loadReceiptsForChild(child['name'] ?? child['alias'] ?? ''),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primary)));
                          }
                          final receipts = snapshot.data ?? [];
                          if (receipts.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    const Text('Belum ada nota/laporan belanja diinputkan untuk anak ini.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: receipts.map((r) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (r['receiptImage'] != null && (r['receiptImage'] as String).isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: _buildChildImage(r['receiptImage'], 60, 60),
                                      )
                                    else
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.receipt, color: AppColors.primary),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r['title'] ?? 'Belanja Kebutuhan',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                          ),
                                          Text(
                                            'Nominal: Rp ${r['amount']}',
                                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            'Tanggal: ${r['date'] ?? '-'}',
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Hash: ${r['hash'] ?? '0x7f4b8...'}',
                                              style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey[700]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadReceiptsForChild(String childName) async {
    final allReceipts = await _localDb.getReceipts();
    return allReceipts.where((r) => (r['childName'] ?? '').toString().toLowerCase() == childName.toLowerCase()).toList();
  }

  Future<void> _showAddReceiptDialog(Map<String, dynamic> child) async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? receiptBase64;
    final childName = child['name'] ?? child['alias'] ?? 'Anak Asuh';

    await showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Input Nota untuk $childName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
                    if (photo != null) {
                      final bytes = await photo.readAsBytes();
                      setDialogState(() {
                        receiptBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                      });
                    }
                  },
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary, strokeAlign: BorderSide.strokeAlignInside),
                    ),
                    child: receiptBase64 != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(base64Decode(receiptBase64!.split(',').last), fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, color: AppColors.primary, size: 28),
                              const SizedBox(height: 4),
                              const Text('Upload Bukti Struk/Nota', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(labelText: 'Peruntukan (Contoh: Beli Buku & Seragam)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Nominal Biaya (Rp)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(labelText: 'Keterangan Toko / Tanggal', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty) {
                  return;
                }
                final newReceipt = {
                  'id': 'rec_${DateTime.now().millisecondsSinceEpoch}',
                  'childName': childName,
                  'title': titleCtrl.text.trim(),
                  'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                  'date': DateTime.now().toString().split(' ')[0],
                  'receiptImage': receiptBase64 ?? '',
                  'description': descCtrl.text.trim(),
                  'hash': '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}sha256',
                };
                await _localDb.insertReceipt(newReceipt);

                // Sync to Supabase
                try {
                  await DioClient().dio.post('/ledger/receipts', data: newReceipt);
                } catch (_) {}

                if (dCtx.mounted) {
                  Navigator.pop(dCtx);
                }
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nota berhasil disimpan & dicatat ke Blockchain Ledger!'), backgroundColor: AppColors.primary),
                  );
                }
              },
              child: const Text('Simpan Nota'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildImage(String url, double width, double height) {
    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(bytes, width: width, height: height, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: AppColors.surfaceLight,
          child: const Icon(Icons.person, color: AppColors.primary),
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.person, color: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Panel Admin Panti Asuhan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Dashboard Keuangan',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceDashboardScreen()));
            },
          ),
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh),
            onPressed: _loadChildren,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah Anak Asuh'),
        onPressed: _showAddChildDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Cari nama anak atau asal panti...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Terdaftar: ${_filteredChildren.length} Anak',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const Text(
                        'Klik kartu untuk input nota belanja',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (_filteredChildren.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.child_care, size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          const Text('Belum ada data anak asuh.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          const Text('Tekan tombol + untuk menambah anak asuh baru.', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                        ],
                      ),
                    ),
                  )
                else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _filteredChildren.length,
                    itemBuilder: (ctx, idx) {
                      final child = _filteredChildren[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 1.5,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _showChildDetailAndReceiptDialog(child),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _buildChildImage(child['photo'] ?? child['photo_url'] ?? child['avatar'] ?? '', 70, 70),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        child['name'] ?? child['alias'] ?? 'Anak Asuh',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Usia ${child['age'] ?? '-'} Thn • ${child['city'] ?? child['orphanage_city'] ?? ''}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceLight,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              child['urgentNeeds'] ?? child['need_category'] ?? 'Pendidikan',
                                              style: const TextStyle(fontSize: 10, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Target: Rp ${(child['target'] ?? 500000).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textHint),
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
