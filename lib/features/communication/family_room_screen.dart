// Letak file: mobile/lib/features/communication/family_room_screen.dart
// Fungsi: Fitur Ruang Kasih — Perantara komunikasi donatur ↔ anak asuh via admin
// Tampilan awal: Daftar ringkasan anak (seperti DM Instagram)
// Klik: Room chat + telepon, video call, pengiriman file karya sekolah

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    try {
      // Coba ambil dari Supabase
      try {
        final res = await DioClient().dio.get('/children');
        if (res.statusCode == 200) {
          if (res.data is List && (res.data as List).isNotEmpty) {
            _children = List<Map<String, dynamic>>.from(res.data);
          } else if (res.data is Map && res.data['data'] is List) {
            _children = List<Map<String, dynamic>>.from(res.data['data']);
          }
        }
      } catch (_) {}

      // Juga ambil dari local
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
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
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
                      const Text('Admin perlu menambahkan data anak terlebih dahulu.', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _children.length,
                  itemBuilder: (context, idx) {
                    final child = _children[idx];
                    final name = child['alias'] ?? child['name'] ?? 'Anak Asuh';
                    final avatar = child['avatar'] ?? child['photo'] ?? '';
                    final city = child['orphanage_city'] ?? child['city'] ?? '';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.surfaceLight,
                        backgroundImage: avatar.toString().startsWith('http') ? NetworkImage(avatar) : null,
                        child: avatar.toString().startsWith('http') ? null : const Icon(Icons.face, color: AppColors.primary, size: 28),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        city.isNotEmpty ? city : 'Ketuk untuk mulai chat',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent1.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _ChatRoomScreen(
                              childAlias: name,
                              childAvatar: avatar,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

// ====================================================================
// CHAT ROOM SCREEN — Per anak asuh
// ====================================================================
class _ChatRoomScreen extends StatefulWidget {
  final String childAlias;
  final String childAvatar;

  const _ChatRoomScreen({
    required this.childAlias,
    required this.childAvatar,
  });

  @override
  State<_ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<_ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    // Coba load dari Supabase
    try {
      final res = await DioClient().dio.get('/letters', queryParameters: {'child_alias': widget.childAlias});
      if (res.statusCode == 200 && res.data is List) {
        for (var m in res.data) {
          _messages.add({
            'sender': m['sender'] ?? 'donor',
            'text': m['text'] ?? m['content'] ?? '',
            'time': m['time'] ?? '',
            'type': m['type'] ?? 'text',
            'fileUrl': m['file_url'] ?? '',
          });
        }
      }
    } catch (_) {}

    // Pesan awal jika kosong
    if (_messages.isEmpty) {
      _messages.add({
        'sender': 'admin',
        'text': 'Selamat datang di Ruang Kasih! Pesan Anda akan diteruskan melalui admin panti ke ${widget.childAlias}. 💛',
        'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        'type': 'text',
      });
    }

    if (mounted) setState(() => _isLoading = false);
    _scrollToBottom();
  }

  void _sendMessage({String? text, String? fileUrl, String type = 'text'}) {
    final content = text ?? _messageController.text.trim();
    if (content.isEmpty && fileUrl == null) return;

    setState(() {
      _messages.add({
        'sender': 'donor',
        'text': content,
        'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        'type': type,
        'fileUrl': fileUrl ?? '',
      });
      _messageController.clear();
    });
    _scrollToBottom();

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

    // Simulasi respon admin
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'admin',
            'text': 'Pesan Anda telah diterima dan akan disampaikan ke ${widget.childAlias}. Terima kasih atas perhatiannya! 🙏',
            'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            'type': 'text',
          });
        });
        _scrollToBottom();
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
            Text(widget.childAlias, style: const TextStyle(fontSize: 16)),
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
                  child: ListView.builder(
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
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
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
                              Text(
                                msg['time'] ?? '',
                                style: TextStyle(color: isDonor ? Colors.white70 : AppColors.textHint, fontSize: 10),
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
