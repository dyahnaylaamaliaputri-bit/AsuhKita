// Letak file: mobile/lib/features/communication/family_room_screen.dart
// Fungsi: Fitur Ruang Kasih — Perantara komunikasi donatur ↔ anak asuh via admin
// Tampilan awal: Daftar ringkasan anak (seperti DM Instagram) — terintegrasi Supabase + SQLite
// Klik: Room chat + telepon, video call, pengiriman file karya sekolah
// Riwayat chat tersimpan permanen di SQLite (tidak hilang saat keluar)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';

class FamilyRoomScreen extends StatefulWidget {
  const FamilyRoomScreen({super.key});

  @override
  State<FamilyRoomScreen> createState() => _FamilyRoomScreenState();
}

class _FamilyRoomScreenState extends State<FamilyRoomScreen> {
  List<Map<String, dynamic>> _children = [];
  Map<String, Map<String, dynamic>?> _lastMessages = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);

    // ============================================================
    // INTEGRASI: Ambil data anak SAMA PERSIS seperti dashboard/sponsor
    // Sumber: Supabase API → SQLite cached_children + new_children
    // ============================================================
    try {
      // 1. Coba ambil dari Supabase (sama seperti sponsor_screen)
      try {
        final res = await DioClient().dio.get('/children');
        if (res.statusCode == 200) {
          if (res.data is List && (res.data as List).isNotEmpty) {
            _children = List<Map<String, dynamic>>.from(res.data);
          } else if (res.data is Map && res.data['data'] is List) {
            _children = List<Map<String, dynamic>>.from(res.data['data']);
          }
          // Cache ke SQLite supaya sync
          if (_children.isNotEmpty) {
            await LocalDatabase().cacheChildren(_children);
          }
        }
      } catch (_) {}

      // 2. Fallback: ambil dari SQLite local (cached + admin-inputted)
      if (_children.isEmpty) {
        final cached = await LocalDatabase().getCachedChildren();
        final newKids = await LocalDatabase().getNewChildren();
        final all = [...cached, ...newKids];
        final seen = <String>{};
        _children = all.where((c) {
          final name = (c['alias'] ?? c['name'] ?? '').toString().toLowerCase();
          if (seen.contains(name)) return false;
          seen.add(name);
          return name.isNotEmpty;
        }).toList();
      }

      // 3. Load last message untuk setiap anak (preview di DM list)
      for (var child in _children) {
        final alias = (child['alias'] ?? child['name'] ?? '').toString();
        if (alias.isNotEmpty) {
          final lastMsg = await LocalDatabase().getLastChatMessage(alias);
          _lastMessages[alias] = lastMsg;
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  String _getTimeAgo(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
      if (diff.inHours < 24) return '${diff.inHours}j lalu';
      if (diff.inDays < 7) return '${diff.inDays}h lalu';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ruang Kasih'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadChildren,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _children.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      const Text('Belum ada anak asuh.', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text(
                        'Admin perlu menambahkan data anak terlebih dahulu\ndi panel Admin.',
                        style: TextStyle(color: AppColors.textHint, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: AppColors.accent2.withValues(alpha: 0.3),
                      child: Text(
                        '💬 ${_children.length} anak asuh terdaftar • Ketuk untuk mulai chat',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // DM List (Instagram-style)
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _children.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200, indent: 78),
                        itemBuilder: (context, idx) {
                          final child = _children[idx];
                          final name = (child['alias'] ?? child['name'] ?? 'Anak Asuh').toString();
                          final avatar = (child['avatar'] ?? child['photo'] ?? '').toString();
                          final city = (child['orphanage_city'] ?? child['city'] ?? '').toString();
                          final category = (child['need_category'] ?? child['urgentNeeds'] ?? '').toString();
                          final lastMsg = _lastMessages[name];
                          final lastText = lastMsg != null ? (lastMsg['text'] ?? '').toString() : '';
                          final lastTime = lastMsg != null ? _getTimeAgo(lastMsg['created_at']?.toString()) : '';
                          final hasMessages = lastMsg != null;

                          return InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _ChatRoomScreen(
                                    childAlias: name,
                                    childAvatar: avatar,
                                    childCity: city,
                                    childCategory: category,
                                  ),
                                ),
                              );
                              // Refresh last messages setelah kembali dari chat
                              final updated = await LocalDatabase().getLastChatMessage(name);
                              if (mounted) {
                                setState(() => _lastMessages[name] = updated);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // Avatar
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: AppColors.surfaceLight,
                                        backgroundImage: avatar.startsWith('http') ? NetworkImage(avatar) : null,
                                        child: avatar.startsWith('http') ? null : const Icon(Icons.face, color: AppColors.primary, size: 28),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: AppColors.accent1,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  // Name + last message
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: AppColors.textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (lastTime.isNotEmpty)
                                              Text(
                                                lastTime,
                                                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          hasMessages
                                              ? (lastText.length > 45 ? '${lastText.substring(0, 45)}...' : lastText)
                                              : city.isNotEmpty
                                                  ? '📍 $city${category.isNotEmpty ? " • $category" : ""}'
                                                  : 'Ketuk untuk mulai chat',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: hasMessages ? AppColors.textSecondary : AppColors.textHint,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Chat icon
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.primary),
                                  ),
                                ],
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

// ====================================================================
// CHAT ROOM SCREEN — Per anak asuh (dengan riwayat chat tersimpan)
// ====================================================================
class _ChatRoomScreen extends StatefulWidget {
  final String childAlias;
  final String childAvatar;
  final String childCity;
  final String childCategory;

  const _ChatRoomScreen({
    required this.childAlias,
    required this.childAvatar,
    this.childCity = '',
    this.childCategory = '',
  });

  @override
  State<_ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<_ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final _localDb = LocalDatabase();

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD RIWAYAT CHAT dari SQLite (persisten, tidak hilang)
  // Beberapa anak memiliki riwayat obrolan sebelumnya (pre-existing)
  // ============================================================
  Future<void> _loadChatHistory() async {
    setState(() => _isLoading = true);

    try {
      // Load pesan tersimpan dari SQLite
      final savedMessages = await _localDb.getChatMessages(widget.childAlias);

      if (savedMessages.isNotEmpty) {
        // Ada riwayat chat sebelumnya — load dari SQLite
        for (var msg in savedMessages) {
          _messages.add({
            'sender': msg['sender'] ?? 'admin',
            'text': msg['text'] ?? '',
            'time': msg['time'] ?? '',
            'type': msg['type'] ?? 'text',
            'fileUrl': msg['file_url'] ?? '',
          });
        }
      } else {
        // Belum ada riwayat — cek apakah anak ini perlu di-seed percakapan
        final alias = widget.childAlias;
        final seededChats = _getPreExistingChats(alias);

        if (seededChats.isNotEmpty) {
          // Seed riwayat percakapan sebelumnya
          for (var chat in seededChats) {
            _messages.add(chat);
            await _localDb.insertChatMessage(
              childAlias: alias,
              sender: chat['sender'],
              text: chat['text'],
              type: chat['type'] ?? 'text',
              fileUrl: chat['fileUrl'] ?? '',
              time: chat['time'],
            );
          }
        } else {
          // Anak lainnya: mulai dari kosong, pesan selamat datang saja
          final now = DateTime.now();
          final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
          final welcomeText =
              'Assalamualaikum! Selamat datang di Ruang Kasih 💛\n\n'
              'Saya admin panti yang akan membantu menyampaikan pesan Anda ke $alias.\n\n'
              '📞 Panggilan suara & video call tersedia di pojok kanan atas.\n'
              '📎 Anda juga bisa mengirim file/karya sekolah.';

          _messages.add({
            'sender': 'admin',
            'text': welcomeText,
            'time': timeStr,
            'type': 'text',
          });

          await _localDb.insertChatMessage(
            childAlias: alias,
            sender: 'admin',
            text: welcomeText,
            time: timeStr,
          );
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
    _scrollToBottom();
  }

  // ============================================================
  // RIWAYAT OBROLAN SEBELUMNYA (pre-existing) untuk anak tertentu
  // Hanya anak pertama dan kedua di daftar yang punya riwayat
  // ============================================================
  List<Map<String, dynamic>> _getPreExistingChats(String alias) {
    // Data percakapan pre-existing berdasarkan nama anak
    final Map<String, List<Map<String, dynamic>>> preChats = {
      'Bintang': [
        {'sender': 'admin', 'text': 'Assalamualaikum! Selamat datang di Ruang Kasih 💛\nSaya admin panti yang akan membantu menyampaikan pesan Anda ke Bintang.', 'time': '08:30', 'type': 'text'},
        {'sender': 'donor', 'text': 'Waalaikumsalam, admin! Saya ingin menanyakan kabar Bintang. Bagaimana perkembangan sekolahnya?', 'time': '08:32', 'type': 'text'},
        {'sender': 'admin', 'text': 'Alhamdulillah, Bintang sedang semangat belajar! Minggu lalu ia mendapat peringkat 3 di kelas. Ia juga rajin mengikuti les tambahan matematika. 📚✨', 'time': '08:35', 'type': 'text'},
        {'sender': 'donor', 'text': 'MasyaAllah, senang sekali mendengarnya! Sampaikan ke Bintang bahwa saya bangga dan terus semangat ya belajarnya 💪', 'time': '08:37', 'type': 'text'},
        {'sender': 'admin', 'text': 'Insya Allah akan kami sampaikan! Bintang pasti sangat senang menerima pesan semangat dari Anda. Jazakallahu khairan atas dukungannya! 🙏💛', 'time': '08:40', 'type': 'text'},
        {'sender': 'donor', 'text': 'Apakah Bintang sudah mendapatkan seragam baru untuk semester ini?', 'time': '09:15', 'type': 'text'},
        {'sender': 'admin', 'text': 'Sudah, Bunda/Ayah! Seragam barunya sudah diterima minggu lalu dari donasi yang masuk. Bintang sangat senang sekali. Terima kasih banyak! 🎒', 'time': '09:20', 'type': 'text'},
      ],
      'Bulan': [
        {'sender': 'admin', 'text': 'Assalamualaikum! Selamat datang di Ruang Kasih 💛\nSaya admin panti yang membantu komunikasi antara donatur dan Bulan.', 'time': '10:00', 'type': 'text'},
        {'sender': 'donor', 'text': 'Waalaikumsalam! Saya mau kirim pesan semangat untuk Bulan. Dia suka menggambar ya?', 'time': '10:05', 'type': 'text'},
        {'sender': 'admin', 'text': 'Iya benar! Bulan sangat suka menggambar dan mewarnai 🎨 Kemarin ia menggambar pemandangan gunung yang sangat indah. Kami akan kirimkan fotonya nanti ya!', 'time': '10:08', 'type': 'text'},
        {'sender': 'donor', 'text': 'Wah hebat sekali! Tolong sampaikan ke Bulan: "Bulan, gambaranmu pasti cantik sekali! Terus berkarya ya sayang!" 😊', 'time': '10:12', 'type': 'text'},
        {'sender': 'admin', 'text': 'Pesan sudah disampaikan! Bulan tersenyum lebar dan bilang "Terima kasih Ayah/Bunda!" 😄💕 Ia sangat senang mendapat perhatian dari donatur.', 'time': '10:30', 'type': 'text'},
      ],
      'Awan': [
        {'sender': 'admin', 'text': 'Assalamualaikum! Selamat datang di Ruang Kasih 💛\nSaya admin panti yang akan membantu komunikasi Anda dengan Awan.', 'time': '14:00', 'type': 'text'},
        {'sender': 'donor', 'text': 'Halo admin, bagaimana kondisi kesehatan Awan? Saya dengar ia sering sakit.', 'time': '14:05', 'type': 'text'},
        {'sender': 'admin', 'text': 'Alhamdulillah, kondisi Awan sudah jauh lebih baik sekarang! Berkat donasi untuk pemeriksaan kesehatan berkala, ia rutin minum vitamin dan sudah tidak sering sakit lagi. 🏥💪', 'time': '14:10', 'type': 'text'},
        {'sender': 'donor', 'text': 'Alhamdulillah, syukurlah! Semoga Awan terus sehat dan semangat belajar. Saya doakan selalu dari sini 🤲', 'time': '14:15', 'type': 'text'},
        {'sender': 'admin', 'text': 'Aamiin! Terima kasih banyak atas doa dan dukungannya. Awan bilang ingin jadi dokter supaya bisa membantu teman-temannya yang sakit. Semangat terus Awan! 🩺⭐', 'time': '14:20', 'type': 'text'},
      ],
    };

    return preChats[alias] ?? [];
  }

  // ============================================================
  // KIRIM PESAN — Simpan ke SQLite + sync ke Supabase
  // ============================================================
  void _sendMessage({String? text, String? fileUrl, String type = 'text'}) {
    final content = text ?? _messageController.text.trim();
    if (content.isEmpty && fileUrl == null) return;

    final now = DateTime.now();
    final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add({
        'sender': 'donor',
        'text': content,
        'time': timeStr,
        'type': type,
        'fileUrl': fileUrl ?? '',
      });
      _messageController.clear();
    });
    _scrollToBottom();

    // Simpan ke SQLite (permanen)
    _localDb.insertChatMessage(
      childAlias: widget.childAlias,
      sender: 'donor',
      text: content,
      type: type,
      fileUrl: fileUrl ?? '',
      time: timeStr,
    );

    // Sync to Supabase
    try {
      DioClient().dio.post('/letters', data: {
        'child_alias': widget.childAlias,
        'sender': 'donor',
        'text': content,
        'type': type,
        'file_url': fileUrl ?? '',
      });
    } catch (_) {}

    // Simulasi respon admin (delay 2 detik)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final replyTime = DateTime.now();
        final replyTimeStr = '${replyTime.hour}:${replyTime.minute.toString().padLeft(2, '0')}';

        String replyText;
        if (type == 'file') {
          replyText = 'File/karya telah diterima! Akan kami tunjukkan ke ${widget.childAlias}. Terima kasih atas kiriman berharganya! 🎨📚';
        } else {
          final replies = [
            'Pesan Anda telah diterima dan akan disampaikan ke ${widget.childAlias}. Terima kasih atas perhatiannya! 🙏',
            '${widget.childAlias} pasti senang menerima pesan dari Anda! Kami akan segera menyampaikannya. 😊',
            'Insya Allah pesan ini akan kami sampaikan ke ${widget.childAlias} hari ini. Jazakallahu khairan! 💛',
            'Pesan telah dicatat. ${widget.childAlias} sedang belajar sekarang, nanti kami bacakan pesannya ya! 📖',
          ];
          replyText = replies[DateTime.now().second % replies.length];
        }

        setState(() {
          _messages.add({
            'sender': 'admin',
            'text': replyText,
            'time': replyTimeStr,
            'type': 'text',
          });
        });
        _scrollToBottom();

        // Simpan respon admin ke SQLite juga
        _localDb.insertChatMessage(
          childAlias: widget.childAlias,
          sender: 'admin',
          text: replyText,
          time: replyTimeStr,
        );
      }
    });
  }

  Future<void> _pickAndSendFile() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (file != null) {
      final bytes = await file.readAsBytes();
      final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      _sendMessage(text: '📎 Karya/File dikirim', fileUrl: b64, type: 'file');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startCall({bool isVideo = false}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Container(
          color: const Color(0xFF1A1A2E),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 70,
                      backgroundColor: AppColors.surfaceLight,
                      backgroundImage: widget.childAvatar.startsWith('http') ? NetworkImage(widget.childAvatar) : null,
                      child: widget.childAvatar.startsWith('http') ? null : const Icon(Icons.face, size: 60, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.childAlias,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isVideo ? '📹 Video Call Sedang Berlangsung...' : '📞 Panggilan Suara Berlangsung...',
                      style: const TextStyle(color: AppColors.accent1, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '(Dibantu oleh admin panti)',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      radius: 28,
                      child: IconButton(icon: const Icon(Icons.mic, color: Colors.white), onPressed: () {}),
                    ),
                    CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      radius: 34,
                      child: IconButton(
                        icon: const Icon(Icons.call_end, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    if (isVideo)
                      CircleAvatar(
                        backgroundColor: Colors.white24,
                        radius: 28,
                        child: IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () {}),
                      ),
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      radius: 28,
                      child: IconButton(icon: const Icon(Icons.volume_up, color: Colors.white), onPressed: () {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceLight,
              backgroundImage: widget.childAvatar.startsWith('http') ? NetworkImage(widget.childAvatar) : null,
              child: widget.childAvatar.startsWith('http') ? null : const Icon(Icons.face, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.childAlias, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  if (widget.childCity.isNotEmpty)
                    Text(
                      '${widget.childCity}${widget.childCategory.isNotEmpty ? " • ${widget.childCategory}" : ""}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            tooltip: 'Panggilan Suara',
            onPressed: () => _startCall(isVideo: false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Video Call',
            onPressed: () => _startCall(isVideo: true),
          ),
          IconButton(
            icon: const Icon(Icons.attach_file),
            tooltip: 'Kirim File/Karya',
            onPressed: _pickAndSendFile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.accent2.withValues(alpha: 0.3),
                  child: const Text(
                    '💡 Komunikasi dibantu admin panti. Pesan diteruskan ke anak asuh.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Chat messages
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text('Belum ada pesan. Mulai kirim pesan pertamamu!',
                              style: TextStyle(color: AppColors.textHint)),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, idx) {
                            final msg = _messages[idx];
                            final isDonor = msg['sender'] == 'donor';
                            final isFile = msg['type'] == 'file';

                            return Align(
                              alignment: isDonor ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                                decoration: BoxDecoration(
                                  color: isDonor ? AppColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(16).copyWith(
                                    bottomRight: isDonor ? const Radius.circular(0) : const Radius.circular(16),
                                    bottomLeft: isDonor ? const Radius.circular(16) : const Radius.circular(0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: isDonor ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!isDonor)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          msg['sender'] == 'admin' ? '👨‍💼 Admin Panti' : '🧒 ${widget.childAlias}',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                        ),
                                      ),
                                    if (isFile && msg['fileUrl'] != null && (msg['fileUrl'] as String).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: _buildImage(msg['fileUrl'], 200),
                                        ),
                                      ),
                                    Text(
                                      msg['text'] ?? '',
                                      style: TextStyle(color: isDonor ? Colors.white : AppColors.textPrimary, fontSize: 13, height: 1.4),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          msg['time'] ?? '',
                                          style: TextStyle(color: isDonor ? Colors.white70 : AppColors.textHint, fontSize: 10),
                                        ),
                                        if (isDonor) ...[
                                          const SizedBox(width: 4),
                                          Icon(Icons.done_all, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Message input
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2)),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: AppColors.primary),
                          onPressed: _pickAndSendFile,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Tulis pesan kasih...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)),
                              filled: true,
                              fillColor: AppColors.surfaceLight,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: () => _sendMessage(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildImage(String url, double height) {
    if (url.startsWith('data:image')) {
      try {
        return Image.memory(base64Decode(url.split(',').last), height: height, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (url.startsWith('http')) {
      return Image.network(url, height: height, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: height, color: AppColors.surfaceLight, child: const Icon(Icons.image)));
    }
    return Container(height: height, color: AppColors.surfaceLight, child: const Icon(Icons.image));
  }
}
