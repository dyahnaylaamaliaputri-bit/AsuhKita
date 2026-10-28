


import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';
import '../admin/admin_panel_screen.dart';
import '../sponsor/sponsor_screen.dart';
import '../steps_game/steps_and_game_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  Uint8List? _imageBytes;
  bool _isEditing = false;
  int _kebaikanPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.userName.isNotEmpty ? auth.userName : 'Donatur Peduli';

    try {
      final prefs = await SharedPreferences.getInstance();
      final emailKey = auth.userEmail.isNotEmpty
          ? auth.userEmail.toLowerCase().trim()
          : (auth.userId.isNotEmpty ? auth.userId : 'donatur_default');


      final photoBase64 = prefs.getString('profile_photo_base64_$emailKey');
      if (photoBase64 != null && photoBase64.isNotEmpty) {
        final decoded = base64Decode(photoBase64);
        if (mounted) {
          setState(() {
            _imageBytes = decoded;
          });
        }
      } else {

        final savedPath = prefs.getString('profile_photo_$emailKey');
        if (savedPath != null && savedPath.isNotEmpty) {
          final f = File(savedPath);
          if (await f.exists() && mounted) {
            setState(() {
              _imageFile = f;
            });
          }
        }
      }


      final claimedPoin = prefs.getInt('asuhkita_kebaikan_points_$emailKey') ?? 0;
      final gameScore = prefs.getInt('asuhkita_game_score_$emailKey') ?? 0;
      final totalPoin = claimedPoin > 0 ? claimedPoin : (gameScore > 0 ? gameScore : 0);

      if (mounted) {
        setState(() {
          _kebaikanPoints = totalPoin;
        });
      }
    } catch (_) {}


    try {
      final profile = await LocalDatabase().getUserProfile(auth.userId.isNotEmpty ? auth.userId : 'usr_me');
      if (profile != null) {
        if (profile['name']!.isNotEmpty && mounted) _nameController.text = profile['name']!;
        if (mounted) _phoneController.text = profile['phone'] ?? '';
      } else {
        if (mounted) _phoneController.text = '081234567890';
      }
    } catch (_) {}

    if (mounted) setState(() {});
  }


  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, maxWidth: 600, imageQuality: 85);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);

        final permanentPath = pickedFile.path;
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
            _imageFile = File(permanentPath);
          });
        }

        if (!mounted) return;
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final emailKey = auth.userEmail.isNotEmpty
            ? auth.userEmail.toLowerCase().trim()
            : (auth.userId.isNotEmpty ? auth.userId : 'donatur_default');


        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profile_photo_base64_$emailKey', base64String);
          await prefs.setString('profile_photo_$emailKey', permanentPath);
        } catch (_) {}


        await LocalDatabase().saveUserProfile(
          id: auth.userId.isNotEmpty ? auth.userId : 'usr_me',
          name: _nameController.text,
          plainPhone: _phoneController.text,
          email: auth.userEmail,
          photoUrl: permanentPath,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto profil berhasil diperbarui! 🎉'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih foto: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Ambil dari Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.updateProfile(
      newName: _nameController.text.trim(),
      newPhone: _phoneController.text.trim(),
    );

    setState(() {
      _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil disimpan (Nomor HP terenkripsi AES-256)!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }


  void _showAdminAddChildModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController(text: '8');
    final cityCtrl = TextEditingController(text: 'Peduli Anak Lombok');
    final dreamCtrl = TextEditingController();
    final hobbyCtrl = TextEditingController();
    final storyCtrl = TextEditingController();
    String selectedGender = 'Laki-laki';
    String? base64Image;

    final availableCategories = AppColors.needCategories.where((c) => c != 'Semua').toList();
    final List<String> selectedNeeds = ['Pendidikan'];
    final Map<String, TextEditingController> budgetControllers = {
      'Pendidikan': TextEditingController(text: '1000000'),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          double totalBudgetCalculated = 0;
          for (var cat in selectedNeeds) {
            final ctrl = budgetControllers[cat];
            final val = double.tryParse(ctrl?.text.replaceAll('.', '').replaceAll(',', '') ?? '0') ?? 0.0;
            totalBudgetCalculated += val;
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.90,
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
                  const Row(
                    children: [
                      Icon(Icons.person_add, color: AppColors.primary, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Tambah Anak Asuh Baru (Admin)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const Text(
                    'Data tersimpan ke SQLite & Supabase Cloud secara realtime untuk donatur.',
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
                        width: 90,
                        height: 90,
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
                                children: const [
                                  Icon(Icons.add_a_photo, color: AppColors.primary, size: 28),
                                  SizedBox(height: 4),
                                  Text('Foto Anak', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedGender,
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
                  const SizedBox(height: 14),


                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kategori Kebutuhan (Bisa Pilih > 1):',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${selectedNeeds.length} Dipilih',
                          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableCategories.map((cat) {
                      final isSelected = selectedNeeds.contains(cat);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        backgroundColor: AppColors.surfaceLight,
                        onSelected: (bool selected) {
                          setModalState(() {
                            if (selected) {
                              selectedNeeds.add(cat);
                              budgetControllers.putIfAbsent(cat, () => TextEditingController(text: '1000000'));
                            } else {
                              if (selectedNeeds.length > 1) {
                                selectedNeeds.remove(cat);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Paling sedikit 1 kategori kebutuhan harus dipilih')),
                                );
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),


                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.payments_outlined, color: AppColors.primary, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Target Budget Per Kategori:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...selectedNeeds.map((cat) {
                          final ctrl = budgetControllers.putIfAbsent(cat, () => TextEditingController(text: '1000000'));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                prefixText: 'Rp ',
                                labelText: 'Budget: $cat',
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          );
                        }),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Target Seluruh Kebutuhan:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Rp ${totalBudgetCalculated.toInt()}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: cityCtrl,
                    decoration: InputDecoration(
                      labelText: 'Asal Panti / Kota',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dreamCtrl,
                    decoration: InputDecoration(
                      labelText: 'Cita-Cita',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hobbyCtrl,
                    decoration: InputDecoration(
                      labelText: 'Hobi & Minat',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: storyCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Kisah / Latar Belakang Anak',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        final name = nameCtrl.text.trim();
                        final ageStr = ageCtrl.text.trim();
                        final age = int.tryParse(ageStr);
                        final story = storyCtrl.text.trim();

                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nama samaran anak wajib diisi!'), backgroundColor: Colors.redAccent),
                          );
                          return;
                        }

                        if (age == null || age <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Usia anak wajib diisi dengan angka valid (> 0)!'), backgroundColor: Colors.redAccent),
                          );
                          return;
                        }

                        if (selectedNeeds.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Paling sedikit 1 kategori kebutuhan wajib dipilih!'), backgroundColor: Colors.redAccent),
                          );
                          return;
                        }

                        if (story.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cerita singkat anak wajib diisi!'), backgroundColor: Colors.redAccent),
                          );
                          return;
                        }

                        final Map<String, double> catBudgetsMap = {};
                        for (var cat in selectedNeeds) {
                          final ctrl = budgetControllers[cat];
                          final val = double.tryParse(ctrl?.text.replaceAll('.', '').replaceAll(',', '') ?? '0') ?? 500000.0;
                          catBudgetsMap[cat] = val;
                        }
                        final totalTarget = catBudgetsMap.values.fold<double>(0.0, (sum, val) => sum + val);

                        try {
                          final res = await DioClient().dio.post('/children', data: {
                            'alias': name,
                            'age': age,
                            'gender': selectedGender == 'Perempuan' ? 'P' : 'L',
                            'need_category': selectedNeeds.join(', '),
                            'story_summary': story,
                            'avatar': base64Image ?? '',
                            'orphanage_city': cityCtrl.text.trim().isEmpty ? 'Peduli Anak Lombok' : cityCtrl.text.trim(),
                            'orphanage_name': 'Peduli Anak Foundation',
                            'target': totalTarget > 0 ? totalTarget : 500000.0,
                            'dream': dreamCtrl.text.trim(),
                            'hobby': hobbyCtrl.text.trim(),
                            'category_budgets': jsonEncode(catBudgetsMap),
                          });

                          String serverChildId = 'child_${DateTime.now().millisecondsSinceEpoch}';
                          if (res.data is Map && res.data['data'] != null && res.data['data']['id'] != null) {
                            serverChildId = res.data['data']['id'].toString();
                          }

                          final newKid = {
                            'id': serverChildId,
                            'name': name,
                            'alias': name,
                            'age': age,
                            'gender': selectedGender,
                            'city': cityCtrl.text.trim().isEmpty ? 'Peduli Anak Lombok' : cityCtrl.text.trim(),
                            'orphanage_city': cityCtrl.text.trim().isEmpty ? 'Peduli Anak Lombok' : cityCtrl.text.trim(),
                            'urgentNeeds': selectedNeeds.join(', '),
                            'need_category': selectedNeeds.join(', '),
                            'category_budgets': jsonEncode(catBudgetsMap),
                            'story': story,
                            'story_summary': story,
                            'photo': base64Image ?? '',
                            'avatar': base64Image ?? '',
                            'target': totalTarget > 0 ? totalTarget : 500000.0,
                            'dream': dreamCtrl.text.trim(),
                            'hobby': hobbyCtrl.text.trim(),
                            'createdAt': DateTime.now().toIso8601String(),
                            'status': 'Tersedia',
                          };

                          await LocalDatabase().insertChild(newKid);
                          SponsorScreen.refreshNotifier.value++;

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!mounted || !context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Anak asuh "$name" berhasil disimpan ke Supabase & langsung tersedia untuk donatur!'),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        } catch (err) {
                          final offlineKid = {
                            'id': 'child_${DateTime.now().millisecondsSinceEpoch}',
                            'name': name,
                            'alias': name,
                            'age': age,
                            'gender': selectedGender,
                            'city': cityCtrl.text.trim().isEmpty ? 'Peduli Anak Lombok' : cityCtrl.text.trim(),
                            'urgentNeeds': selectedNeeds.join(', '),
                            'need_category': selectedNeeds.join(', '),
                            'category_budgets': jsonEncode(catBudgetsMap),
                            'story': story,
                            'story_summary': story,
                            'photo': base64Image ?? '',
                            'avatar': base64Image ?? '',
                            'target': totalTarget > 0 ? totalTarget : 500000.0,
                            'dream': dreamCtrl.text.trim(),
                            'hobby': hobbyCtrl.text.trim(),
                            'createdAt': DateTime.now().toIso8601String(),
                            'status': 'Tersedia',
                          };
                          await LocalDatabase().insertChild(offlineKid);
                          SponsorScreen.refreshNotifier.value++;

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!mounted || !context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal koneksi ke server, data anak "$name" disimpan secara offline di SQLite.'),
                              backgroundColor: Colors.orange.shade800,
                            ),
                          );
                        }
                      },
                      child: const Text('Submit Data Anak Asuh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Profil Pengguna'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            tooltip: _isEditing ? 'Simpan' : 'Edit Profil',
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfileData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [

              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      backgroundImage: _imageBytes != null
                          ? MemoryImage(_imageBytes!)
                          : (_imageFile != null ? FileImage(_imageFile!) : null),
                      child: (_imageBytes == null && _imageFile == null)
                          ? const Icon(Icons.person, size: 60, color: AppColors.primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                auth.userName.isNotEmpty ? auth.userName : 'Donatur Asuh',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Peran: ${auth.userRole == 'admin_panti' ? 'Pengurus Panti' : 'Orang Tua Asuh'}',
                style: TextStyle(fontSize: 14, color: AppColors.primaryDark, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),


              if (auth.userRole != 'admin_panti')
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: AppColors.surfaceLight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stars, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _kebaikanPoints >= 10000
                                    ? 'Ranking: Pahlawan Kebaikan Utama 🏆'
                                    : _kebaikanPoints >= 5000
                                        ? 'Ranking: Duta Asuh Mulia 💎'
                                        : _kebaikanPoints >= 3000
                                            ? 'Ranking: Pejuang Kebaikan 🌟'
                                            : _kebaikanPoints >= 1000
                                                ? 'Ranking: Sahabat Peduli ⭐'
                                                : 'Ranking: Pemula Berbagi 🌱',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_kebaikanPoints Poin Kebaikan • Level ${_kebaikanPoints >= 10000 ? 5 : _kebaikanPoints >= 5000 ? 4 : _kebaikanPoints >= 3000 ? 3 : _kebaikanPoints >= 1000 ? 2 : 1}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StepsAndGameScreen()));
                                },
                                child: const Row(
                                  children: [
                                    Text('Lihat Peringkat & Hadiah', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primaryDark,
                          child: Icon(Icons.verified_user, color: Colors.white),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Identitas Pengurus Panti Asuhan',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Otoritas verifikasi data anak, penginputan nota belanja, dan transparansi on-chain.',
                                style: TextStyle(fontSize: 11, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),


              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Akun',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.email_outlined, color: AppColors.primary),
                        title: const Text('Email', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        subtitle: Text(
                          auth.userEmail.isNotEmpty ? auth.userEmail : 'donatur@asuhkita.id',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        enabled: _isEditing,
                        decoration: InputDecoration(
                          labelText: 'Nama Lengkap',
                          prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: !_isEditing,
                          fillColor: _isEditing ? Colors.white : Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        enabled: _isEditing,
                        decoration: InputDecoration(
                          labelText: 'Nomor WhatsApp / HP (Enkripsi AES-256)',
                          prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: !_isEditing,
                          fillColor: _isEditing ? Colors.white : Colors.grey.shade100,
                          helperText: 'Tersimpan aman dengan enkripsi AES-256 di database lokal',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),


              if (auth.userRole == 'admin_panti') ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.admin_panel_settings, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'Kelola Data Anak Panti',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tambahkan data anak asuh baru langsung dari sini atau kelola lengkap di Panel Admin.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.person_add),
                            label: const Text('Tambah Data Anak Baru', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => _showAdminAddChildModal(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.dashboard_customize_outlined),
                            label: const Text('Buka Panel Admin & Kelola Anak'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],


              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.fingerprint, color: AppColors.primary, size: 28),
                        title: const Text(
                          'Login dengan Biometrik',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('Gunakan sidik jari/wajah untuk membuka sesi cepat'),
                        value: auth.isBiometricEnabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) async {
                          if (val) {
                            final ok = await auth.registerBiometricPrompt();
                            if (ok && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sidik jari berhasil didaftarkan dan diaktifkan!'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          } else {
                            auth.toggleBiometric(false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Login biometrik dinonaktifkan.'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
