







import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';
import '../auth/auth_provider.dart';
import '../sponsor/sponsor_screen.dart';
Widget buildChildAvatar(
  String? avatarUrl, {
  double radius = 24,
  Color? backgroundColor,
  double? iconSize,
}) {
  final url = (avatarUrl ?? '').trim();
  final bg = backgroundColor ?? AppColors.surfaceLight;
  final iSize = iconSize ?? (radius * 1.1);

  if (url.startsWith('data:image')) {
    try {
      final bytes = base64Decode(url.split(',').last);
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        backgroundImage: MemoryImage(bytes),
      );
    } catch (_) {}
  }
  if (url.startsWith('assets/')) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      backgroundImage: AssetImage(url),
    );
  }
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      backgroundImage: NetworkImage(url),
    );
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: bg,
    child: Icon(Icons.face, size: iSize, color: AppColors.primary),
  );
}

class FamilyRoomScreen extends StatefulWidget {
  const FamilyRoomScreen({super.key});

  @override
  State<FamilyRoomScreen> createState() => _FamilyRoomScreenState();
}

class _FamilyRoomScreenState extends State<FamilyRoomScreen> {
  List<Map<String, dynamic>> _children = [];
  Map<String, Map<String, dynamic>?> _lastMessages = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();


  final Map<String, String> _childNotes = {
    'Bintang': 'Lagi les matematika 📚',
    'Bulan': 'Selesai gambar gunung 🎨',
    'Awan': 'Bermain bola di panti ⚽',
    'Rian': 'Sedang membaca buku 📖',
    'Siti': 'Belajar hafalan doa ✨',
    'Dewi': 'Membantu masak di panti 🍳',
  };

  @override
  void initState() {
    super.initState();
    _loadChildrenAndMessages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }




  Future<void> _loadChildrenAndMessages() async {
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userEmail = auth.userEmail.toLowerCase().trim();
      final userName = auth.userName.toLowerCase().trim();

      final localDonations = await LocalDatabase().getCachedDonations();
      final sponsoredAliases = <String>{};
      if (userEmail.isNotEmpty || userName.isNotEmpty) {
        for (var d in localDonations) {
          final dEmail = (d['donor_email'] ?? '').toString().toLowerCase().trim();
          final dName = (d['donor_name'] ?? '').toString().toLowerCase().trim();
          final isMatch = (userEmail.isNotEmpty && dEmail == userEmail) ||
              (userName.isNotEmpty && (dName == userName || dName == userEmail));
          if (isMatch) {
            final alias = (d['child_alias'] ?? '').toString().trim();
            if (alias.isNotEmpty) {
              sponsoredAliases.add(alias.toLowerCase());
            }
          }
        }
      }

      List<Map<String, dynamic>> allCatalog = [];
      try {
        final res = await DioClient().dio.get('/children');
        if (res.statusCode == 200) {
          if (res.data is List && (res.data as List).isNotEmpty) {
            allCatalog = List<Map<String, dynamic>>.from(res.data);
          } else if (res.data is Map && res.data['data'] is List) {
            allCatalog = List<Map<String, dynamic>>.from(res.data['data']);
          }
          if (allCatalog.isNotEmpty) {
            await LocalDatabase().cacheChildren(allCatalog);
          }
        }
      } catch (_) {}

      final cached = await LocalDatabase().getCachedChildren();
      final newKids = await LocalDatabase().getNewChildren();
      final combinedCatalog = <Map<String, dynamic>>[...allCatalog, ...cached, ...newKids];

      List<Map<String, dynamic>> mySponsoredChildren = [];
      if (sponsoredAliases.isNotEmpty) {
        final seen = <String>{};
        for (var child in combinedCatalog) {
          final name = (child['alias'] ?? child['name'] ?? '').toString().trim();
          if (name.isNotEmpty && sponsoredAliases.contains(name.toLowerCase())) {
            if (!seen.contains(name.toLowerCase())) {
              seen.add(name.toLowerCase());
              mySponsoredChildren.add(child);
            }
          }
        }

        for (var alias in sponsoredAliases) {
          if (!seen.contains(alias)) {
            seen.add(alias);
            final matched = combinedCatalog.firstWhere(
              (c) => (c['alias'] ?? c['name'] ?? '').toString().trim().toLowerCase() == alias,
              orElse: () => <String, dynamic>{},
            );
            final titleCase = alias.length > 1 ? '${alias[0].toUpperCase()}${alias.substring(1)}' : alias;
            mySponsoredChildren.add({
              'alias': matched['alias'] ?? matched['name'] ?? titleCase,
              'orphanage_city': matched['orphanage_city'] ?? matched['city'] ?? 'PeduliAnak',
              'need_category': matched['need_category'] ?? matched['urgent_needs'] ?? 'Pendidikan',
              'avatar': matched['avatar'] ?? matched['photo'] ?? '',
            });
          }
        }
      }

      // Donor only sees children they donated to; Admin sees all children.
      final rawList = auth.isAdmin ? combinedCatalog : mySponsoredChildren;

      final Map<String, Map<String, dynamic>> uniqueMap = {};
      for (var c in rawList) {
        final name = (c['alias'] ?? c['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          final key = name.toLowerCase();
          if (!uniqueMap.containsKey(key)) {
            uniqueMap[key] = c;
          }
        }
      }
      _children = uniqueMap.values.toList();

      _lastMessages = {};
      for (var child in _children) {
        final alias = (child['alias'] ?? child['name'] ?? '').toString().trim();
        if (alias.isNotEmpty) {
          final lastMsg = await LocalDatabase().getLastChatMessage(alias);
          _lastMessages[alias.toLowerCase()] = lastMsg;
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
      if (diff.inDays == 1) return 'Kemarin';
      if (diff.inDays < 7) return '${diff.inDays}h lalu';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {

    final filtered = _children.where((c) {
      final name = (c['alias'] ?? c['name'] ?? '').toString().toLowerCase();
      final city = (c['orphanage_city'] ?? c['city'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || city.contains(_searchQuery.toLowerCase());
    }).toList();


    filtered.sort((a, b) {
      final nameA = (a['alias'] ?? a['name'] ?? '').toString().trim().toLowerCase();
      final nameB = (b['alias'] ?? b['name'] ?? '').toString().trim().toLowerCase();
      final msgA = _lastMessages[nameA];
      final msgB = _lastMessages[nameB];
      if (msgA != null && msgB != null) {
        final dateA = msgA['created_at']?.toString() ?? '';
        final dateB = msgB['created_at']?.toString() ?? '';
        return dateB.compareTo(dateA);
      }
      if (msgA != null) return -1;
      if (msgB != null) return 1;
      return nameA.compareTo(nameB);
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Ruang Kasih',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Perbarui Pesan',
            onPressed: _loadChildrenAndMessages,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _children.isEmpty
              ? _buildEmptyState()
              : CustomScrollView(
              slivers: [

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Cari percakapan atau anak asuh...',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ),


                SliverToBoxAdapter(
                  child: Container(
                    height: 110,
                    margin: const EdgeInsets.only(top: 4, bottom: 4),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _children.length,
                      itemBuilder: (context, idx) {
                        final child = _children[idx];
                        final name = (child['alias'] ?? child['name'] ?? 'Anak').toString();
                        final avatar = (child['avatar'] ?? child['photo'] ?? '').toString();
                        final note = _childNotes[name] ?? 'Semangat belajar 🎒';
                        final hasChat = _lastMessages[name.trim().toLowerCase()] != null;

                        return InkWell(
                          onTap: () => _openChatRoom(child),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 82,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [

                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 1)),
                                    ],
                                  ),
                                  child: Text(
                                    note,
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: hasChat
                                          ? [AppColors.primary, AppColors.accent1]
                                          : [Colors.grey.shade300, Colors.grey.shade400],
                                    ),
                                  ),
                                  child: buildChildAvatar(avatar, radius: 24, backgroundColor: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  name,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: Divider(height: 1, thickness: 0.8, color: Color(0xFFEEEEEE)),
                ),


                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Row(
                      children: [
                        const Icon(Icons.forum_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Percakapan Ruang Kasih',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const Spacer(),
                        Text(
                          '${filtered.length} ruang obrolan',
                          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, idx) {
                      final child = filtered[idx];
                      final name = (child['alias'] ?? child['name'] ?? '').toString().trim().toLowerCase();
                      final hasHistory = _lastMessages[name] != null;
                      return _buildChatListItem(child, hasExistingHistory: hasHistory);
                    },
                    childCount: filtered.length,
                  ),
                ),

                if (filtered.isEmpty && _searchQuery.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      child: Center(
                        child: Text(
                          'Tidak ada obrolan dengan nama "$_searchQuery"',
                          style: const TextStyle(fontSize: 13, color: AppColors.textHint),
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
    );
  }




  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.volunteer_activism_outlined,
                size: 46,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ruang Kasih Masih Kosong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Anda belum memiliki anak asuh yang didampingi saat ini. Ruang Kasih akan otomatis menampilkan room chat dengan anak asuh dan pengurus panti setelah Anda melakukan sponsorship/donasi.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildBenefitRow(
                    icon: Icons.chat_bubble_outline,
                    color: AppColors.primary,
                    title: 'Pesan Langsung Ramah',
                    subtitle: 'Kirim salam hangat dan motivasi belajar untuk anak asuh.',
                  ),
                  const Divider(height: 20, color: Color(0xFFEEEEEE)),
                  _buildBenefitRow(
                    icon: Icons.auto_stories_outlined,
                    color: AppColors.accent1,
                    title: 'Pantau Nilai Rapor & Bakat',
                    subtitle: 'Dapatkan kabar harian, prestasi, dan hasil karya anak asuh.',
                  ),
                  const Divider(height: 20, color: Color(0xFFEEEEEE)),
                  _buildBenefitRow(
                    icon: Icons.verified_user_outlined,
                    color: AppColors.accent2,
                    title: 'Didampingi Pengurus Panti',
                    subtitle: 'Komunikasi aman, terverifikasi, dan transparan 100%.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SponsorScreen()),
                  ).then((_) => _loadChildrenAndMessages());
                },
                icon: const Icon(Icons.favorite, size: 20),
                label: const Text(
                  'Pilih Anak Asuh di Menu Sponsor',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }




  Widget _buildChatListItem(Map<String, dynamic> child, {required bool hasExistingHistory}) {
    final name = (child['alias'] ?? child['name'] ?? 'Anak Asuh').toString();
    final avatar = (child['avatar'] ?? child['photo'] ?? '').toString();
    final city = (child['orphanage_city'] ?? child['city'] ?? 'PeduliAnak').toString();
    final category = (child['need_category'] ?? child['urgentNeeds'] ?? 'Pendidikan').toString();
    final lastMsg = _lastMessages[name.trim().toLowerCase()];

    String subtitleText = '';
    String timeText = '';
    bool isFromDonor = false;

    if (hasExistingHistory && lastMsg != null) {
      isFromDonor = lastMsg['sender'] == 'donor';
      final text = (lastMsg['text'] ?? '').toString();
      final preview = text.length > 40 ? '${text.substring(0, 40)}...' : text;
      subtitleText = isFromDonor ? 'Anda: $preview' : preview;
      timeText = _getTimeAgo(lastMsg['created_at']?.toString());
    } else {
      subtitleText = 'Ketuk untuk memulai pesan pertama 👋';
      timeText = 'Baru';
    }

    return InkWell(
      onTap: () => _openChatRoom(child),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [

            Stack(
              children: [
                buildChildAvatar(avatar, radius: 27),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: hasExistingHistory ? const Color(0xFF10B981) : AppColors.accent1,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasExistingHistory ? FontWeight.bold : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 11,
                          color: hasExistingHistory ? AppColors.textSecondary : AppColors.accent1,
                          fontWeight: hasExistingHistory ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitleText,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasExistingHistory ? AppColors.textSecondary : AppColors.primary,
                            fontWeight: hasExistingHistory ? FontWeight.normal : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasExistingHistory && isFromDonor) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.done_all, size: 14, color: AppColors.primary),
                      ],
                    ],
                  ),
                  if (!hasExistingHistory) ...[
                    const SizedBox(height: 2),
                    Text(
                      '📍 $city • Kebutuhan: $category',
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            Icon(
              hasExistingHistory ? Icons.chevron_right : Icons.send_outlined,
              size: 20,
              color: hasExistingHistory ? AppColors.textHint : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChatRoom(Map<String, dynamic> child) async {
    final name = (child['alias'] ?? child['name'] ?? 'Anak Asuh').toString();
    final avatar = (child['avatar'] ?? child['photo'] ?? '').toString();
    final city = (child['orphanage_city'] ?? child['city'] ?? '').toString();
    final category = (child['need_category'] ?? child['urgentNeeds'] ?? '').toString();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChatRoomScreen(
          childAlias: name,
          childAvatar: avatar,
          childCity: city,
          childCategory: category,
          isViewerAdmin: auth.isAdmin,
        ),
      ),
    );


    final updated = await LocalDatabase().getLastChatMessage(name);
    if (mounted) {
      setState(() => _lastMessages[name.trim().toLowerCase()] = updated);
    }
  }
}




class _ChatRoomScreen extends StatefulWidget {
  final String childAlias;
  final String childAvatar;
  final String childCity;
  final String childCategory;
  final bool isViewerAdmin;

  const _ChatRoomScreen({
    required this.childAlias,
    required this.childAvatar,
    this.childCity = '',
    this.childCategory = '',
    this.isViewerAdmin = false,
  });

  @override
  State<_ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<_ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final LocalDatabase _localDb = LocalDatabase();

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _hasTyped = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasTyped) {
        setState(() => _hasTyped = hasText);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }






  Future<void> _loadChatHistory() async {
    setState(() => _isLoading = true);

    try {
      final savedMessages = await _localDb.getChatMessages(widget.childAlias);
      if (savedMessages.isNotEmpty) {
        for (var msg in savedMessages) {
          _messages.add({
            'sender': msg['sender'] ?? 'admin',
            'text': msg['text'] ?? '',
            'time': msg['time'] ?? '',
            'type': msg['type'] ?? 'text',
            'fileUrl': msg['file_url'] ?? '',
          });
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
    _scrollToBottom();
  }




  void _sendMessage({String? text, String? fileUrl, String type = 'text'}) {
    final content = text ?? _messageController.text.trim();
    if (content.isEmpty && fileUrl == null) return;

    final now = DateTime.now();
    final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    final senderRole = widget.isViewerAdmin ? 'admin' : 'donor';

    setState(() {
      _messages.add({
        'sender': senderRole,
        'text': content,
        'time': timeStr,
        'type': type,
        'fileUrl': fileUrl ?? '',
      });
      _messageController.clear();
      _hasTyped = false;
    });
    _scrollToBottom();


    _localDb.insertChatMessage(
      childAlias: widget.childAlias,
      sender: senderRole,
      text: content,
      type: type,
      fileUrl: fileUrl ?? '',
      time: timeStr,
    );


    try {
      DioClient().dio.post('/letters', data: {
        'child_alias': widget.childAlias,
        'sender': senderRole,
        'text': content,
        'type': type,
        'file_url': fileUrl ?? '',
      });
    } catch (_) {}


    if (!widget.isViewerAdmin) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
        final replyTime = DateTime.now();
        final replyTimeStr = '${replyTime.hour}:${replyTime.minute.toString().padLeft(2, '0')}';

        String replyText;
        if (type == 'file') {
          replyText = 'Alhamdulillah, karya/file dari Kakak sudah diterima! Kami akan segera tunjukkan ke ${widget.childAlias}. Terima kasih atas perhatiannya! 🎨💛';
        } else if (_messages.length <= 2) {

          replyText = 'Waalaikumsalam Kak! Terima kasih banyak sudah menyapa ${widget.childAlias} 😊 Salam hangat dari adik-adik di Panti Asuhan Peduli Anak. Ada yang bisa kami bantu sampaikan?';
        } else {
          final replies = [
            'Pesan Kakak sudah kami catat dan akan dibacakan ke ${widget.childAlias} saat jam istirahat belajar nanti. Terima kasih banyak! 🙏💛',
            '${widget.childAlias} pasti senang sekali membaca pesan ini! Kami doakan rezeki Kakak selalu dilipatgandakan ya. Aamiin 🤲✨',
            'Alhamdulillah, insya Allah amanah pesan dan doa dari Kakak akan kami sampaikan langsung ke ${widget.childAlias} hari ini. 😊',
            'Terima kasih atas kepedulian Kakak! ${widget.childAlias} sedang belajar di kelas, nanti sore kami sampaikan ya! 📖🎒',
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


        _localDb.insertChatMessage(
          childAlias: widget.childAlias,
          sender: 'admin',
          text: replyText,
          time: replyTimeStr,
        );
      }
    });
    }
  }

  Future<void> _pickAndSendFile() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (file != null) {
      final bytes = await file.readAsBytes();
      final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      _sendMessage(text: '📎 Karya/Foto dikirim', fileUrl: b64, type: 'file');
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
          color: const Color(0xFF111827),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    buildChildAvatar(widget.childAvatar, radius: 65, iconSize: 55),
                    const SizedBox(height: 18),
                    Text(
                      widget.childAlias,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isVideo ? '📹 Video Call Sedang Berlangsung...' : '📞 Panggilan Suara Berlangsung...',
                      style: const TextStyle(color: AppColors.accent1, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '(Didampingi admin panti asuhan)',
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
                      radius: 26,
                      child: IconButton(icon: const Icon(Icons.mic, color: Colors.white), onPressed: () {}),
                    ),
                    CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      radius: 32,
                      child: IconButton(
                        icon: const Icon(Icons.call_end, color: Colors.white, size: 26),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    if (isVideo)
                      CircleAvatar(
                        backgroundColor: Colors.white24,
                        radius: 26,
                        child: IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () {}),
                      ),
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      radius: 26,
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
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        title: Row(
          children: [
            Stack(
              children: [
                buildChildAvatar(widget.childAvatar, radius: 19, iconSize: 20),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.childAlias,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    widget.childCity.isNotEmpty ? 'Aktif sekarang • ${widget.childCity}' : 'Aktif sekarang',
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: AppColors.textPrimary),
            tooltip: 'Panggilan Suara',
            onPressed: () => _startCall(isVideo: false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: AppColors.textPrimary),
            tooltip: 'Video Call',
            onPressed: () => _startCall(isVideo: true),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppColors.textPrimary),
            tooltip: 'Info Anak',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Anak Asuh: ${widget.childAlias} (${widget.childCategory})'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [

                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyStateFromScratch()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, idx) {
                            final msg = _messages[idx];
                            final isMe = widget.isViewerAdmin ? (msg['sender'] == 'admin') : (msg['sender'] == 'donor');
                            final isDonor = isMe;
                            final isFile = msg['type'] == 'file';

                            return Align(
                              alignment: isDonor ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                                child: Row(
                                  mainAxisAlignment: isDonor ? MainAxisAlignment.end : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (!isDonor) ...[
                                      buildChildAvatar(widget.childAvatar, radius: 14, iconSize: 14),
                                      const SizedBox(width: 6),
                                    ],
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          gradient: isDonor
                                              ? const LinearGradient(
                                                  colors: [AppColors.primary, AppColors.primaryDark],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: isDonor ? null : Colors.white,
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(18),
                                            topRight: const Radius.circular(18),
                                            bottomLeft: Radius.circular(isDonor ? 18 : 4),
                                            bottomRight: Radius.circular(isDonor ? 4 : 18),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.04),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: isDonor ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                          children: [
                                            if (!isDonor)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 3),
                                                child: Text(
                                                  widget.isViewerAdmin ? (msg['sender'] == 'admin' ? '👨‍💼 Anda (Admin Panti)' : '🤝 Donatur Peduli') : (msg['sender'] == 'admin' ? '👨‍💼 Admin Panti' : '🧒 ${widget.childAlias}'),
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                                ),
                                              ),
                                            if (isFile && msg['fileUrl'] != null && (msg['fileUrl'] as String).isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 6),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: _buildImage(msg['fileUrl'], 180),
                                                ),
                                              ),
                                            Text(
                                              msg['text'] ?? '',
                                              style: TextStyle(
                                                color: isDonor ? Colors.white : AppColors.textPrimary,
                                                fontSize: 14,
                                                height: 1.35,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  msg['time'] ?? '',
                                                  style: TextStyle(
                                                    color: isDonor ? Colors.white70 : AppColors.textHint,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                if (isDonor) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.done_all, size: 13, color: Colors.white70),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),


                _buildMessageInputBar(),
              ],
            ),
    );
  }




  Widget _buildEmptyStateFromScratch() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent1],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: buildChildAvatar(widget.childAvatar, radius: 46, backgroundColor: Colors.white, iconSize: 48),
          ),
          const SizedBox(height: 14),
          Text(
            widget.childAlias,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'PeduliAnak • Kebutuhan: ${widget.childCategory.isNotEmpty ? widget.childCategory : "Pendidikan"}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Belum ada pesan dengan anak asuh ini',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mulai kirimkan pesan hangat atau doa terbaikmu untuk menyapa ${widget.childAlias}. Pesanmu akan diteruskan oleh admin panti.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textHint, height: 1.4),
          ),
          const SizedBox(height: 28),


          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '💡 Kirim pesan pembuka cepat:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 10),
          _buildQuickReplyChip('👋 Halo ${widget.childAlias}, salam kenal ya!'),
          _buildQuickReplyChip('📚 Semangat terus belajarnya di sekolah ya!'),
          _buildQuickReplyChip('🎨 Kakak sangat senang bisa mendukung masa depanmu!'),
        ],
      ),
    );
  }

  Widget _buildQuickReplyChip(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () => _sendMessage(text: text),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
          ],
        ),
      ),
    );
  }




  Widget _buildMessageInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [

            IconButton(
              icon: const Icon(Icons.photo_library_outlined, color: AppColors.primary, size: 24),
              tooltip: 'Kirim Karya/Foto',
              onPressed: _pickAndSendFile,
            ),

            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade300, width: 0.8),
                ),
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Kirim pesan ke ${widget.childAlias}...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),

            _hasTyped
                ? IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary, size: 24),
                    onPressed: () => _sendMessage(),
                  )
                : IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 24),
                    tooltip: 'Kirim Kasih',
                    onPressed: () => _sendMessage(text: '❤️ (Kirim Kasih)'),
                  ),
          ],
        ),
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
      return Image.network(
        url,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Container(height: height, color: AppColors.surfaceLight, child: const Icon(Icons.image)),
      );
    }
    return Container(height: height, color: AppColors.surfaceLight, child: const Icon(Icons.image));
  }
}
