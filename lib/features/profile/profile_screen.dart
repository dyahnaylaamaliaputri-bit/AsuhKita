// Letak file: mobile/lib/features/profile/profile_screen.dart
// Fungsi: Layar Profil dengan foto kamera/galeri permanen (Base64 + File Cache), edit nama & nomor HP (AES-256), aktivasi biometrik, dan badge kebaikan dinamis (PBI-010, PBI-011, FR-11, FR-12, FR-48)

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';
import '../../data/local_db.dart';

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
  int _kebaikanPoints = 0; // Poin akumulasi dari langkah harian & mini game

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
      final emailKey = auth.userEmail.isNotEmpty ? auth.userEmail.toLowerCase().trim() : 'donatur_default';

      // 1. Ambil foto profil dari Base64 string (tahan banting: tidak terhapus saat logout/restart)
      final photoBase64 = prefs.getString('profile_photo_base64_$emailKey') ??
          prefs.getString('profile_photo_base64_active');
      if (photoBase64 != null && photoBase64.isNotEmpty) {
        final decoded = base64Decode(photoBase64);
        if (mounted) {
          setState(() {
            _imageBytes = decoded;
          });
        }
      } else {
        // Cek file permanen
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

      // 2. Ambil akumulasi poin kebaikan dari SharedPreferences
      final claimedPoin = prefs.getInt('asuhkita_kebaikan_points') ?? 0;
      final gameScore = prefs.getInt('asuhkita_game_score') ?? 0;
      final totalPoin = claimedPoin > 0 ? claimedPoin : (gameScore > 0 ? gameScore : 0);

      if (mounted) {
        setState(() {
          _kebaikanPoints = totalPoin;
        });
      }
    } catch (_) {}

    // Ambil data profil lokal yang terenkripsi AES-256
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

  // Pilih foto dari Kamera atau Galeri (PBI-011, FR-12)
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
        final emailKey = auth.userEmail.isNotEmpty ? auth.userEmail.toLowerCase().trim() : 'donatur_default';

        // Simpan Base64 & Path permanen di SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profile_photo_base64_$emailKey', base64String);
          await prefs.setString('profile_photo_base64_active', base64String);
          await prefs.setString('profile_photo_$emailKey', permanentPath);
        } catch (_) {}

        // Simpan ke SQLite terenkripsi AES-256
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
              content: Text('Foto profil berhasil disimpan permanen! Tidak akan hilang saat logout.'),
              backgroundColor: Colors.teal,
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
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('Ambil dari Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
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
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Profil Pengguna'),
        backgroundColor: Colors.teal,
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
        color: Colors.teal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Bagian Foto Profil (PBI-011)
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.teal.shade100,
                      backgroundImage: _imageBytes != null
                          ? MemoryImage(_imageBytes!)
                          : (_imageFile != null ? FileImage(_imageFile!) : null),
                      child: (_imageBytes == null && _imageFile == null)
                          ? const Icon(Icons.person, size: 60, color: Colors.teal)
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
                            color: Colors.teal,
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
                style: TextStyle(fontSize: 14, color: Colors.teal.shade700, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),

              // Card Badge & Poin Kebaikan Dinamis (Hanya untuk Donatur, dihapus untuk Admin)
              if (auth.userRole != 'admin_panti')
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.teal.shade50,
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
                                _kebaikanPoints >= 500
                                    ? 'Badge: Sahabat Teladan 🌟'
                                    : _kebaikanPoints >= 100
                                        ? 'Badge: Sahabat Mulia ⭐'
                                        : 'Badge: Sahabat Peduli 🌱',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_kebaikanPoints Poin Kebaikan dikumpulkan (dari Langkah Pedometer & Mini Game)',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(0xFF1B5E20),
                          child: Icon(Icons.verified_user, color: Colors.white),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Identitas Pengurus Panti Asuhan',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
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

              // Form Detail Profil
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
                        leading: const Icon(Icons.email_outlined, color: Colors.teal),
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
                          prefixIcon: const Icon(Icons.person_outline, color: Colors.teal),
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
                          prefixIcon: const Icon(Icons.phone_outlined, color: Colors.teal),
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

              // Pengaturan Keamanan & Biometrik (FR-07, FR-08)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.fingerprint, color: Colors.teal, size: 28),
                        title: const Text(
                          'Login dengan Biometrik',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('Gunakan sidik jari/wajah untuk membuka sesi cepat'),
                        value: auth.isBiometricEnabled,
                        activeThumbColor: Colors.teal,
                        onChanged: (val) async {
                          if (val) {
                            final ok = await auth.registerBiometricPrompt();
                            if (ok && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sidik jari berhasil didaftarkan dan diaktifkan!'),
                                  backgroundColor: Colors.teal,
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
