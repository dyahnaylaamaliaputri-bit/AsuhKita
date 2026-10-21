// Letak file: mobile/lib/features/profile/profile_screen.dart
// Fungsi: Layar Profil dengan foto kamera/galeri, edit nama & nomor HP (AES-256), aktivasi biometrik, dan badge kebaikan (PBI-010, PBI-011, FR-11, FR-12, FR-48)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
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
  bool _isEditing = false;
  final int _kebaikanPoints = 350; // Poin dari langkah & mini game (FR-48)

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.userName;

    // Ambil data profil lokal yang terenkripsi AES-256
    final profile = await LocalDatabase().getUserProfile(auth.userId.isNotEmpty ? auth.userId : 'usr_me');
    if (profile != null) {
      if (profile['name']!.isNotEmpty) _nameController.text = profile['name']!;
      _phoneController.text = profile['phone'] ?? '';
      if (profile['photo_url'] != null && profile['photo_url']!.isNotEmpty) {
        final f = File(profile['photo_url']!);
        if (await f.exists()) {
          setState(() {
            _imageFile = f;
          });
        }
      }
    } else {
      _phoneController.text = '081234567890';
    }
    setState(() {});
  }

  // Pilih foto dari Kamera atau Galeri (PBI-011, FR-12)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, maxWidth: 600, imageQuality: 85);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });

        if (!mounted) return;
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await LocalDatabase().saveUserProfile(
          id: auth.userId.isNotEmpty ? auth.userId : 'usr_me',
          name: _nameController.text,
          plainPhone: _phoneController.text,
          email: auth.userEmail,
          photoUrl: pickedFile.path,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto profil berhasil diperbarui & disimpan di cache!'),
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
      body: SingleChildScrollView(
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
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : null,
                    child: _imageFile == null
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

            // Card Badge & Poin Kebaikan (FR-48)
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
                          const Text(
                            'Badge: Sahabat Mulia',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_kebaikanPoints Poin Kebaikan (dari Donasi Langkah & Mini Game)',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
    );
  }
}
