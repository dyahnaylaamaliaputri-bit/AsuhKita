

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_provider.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _saranController = TextEditingController();
  final _kesanController = TextEditingController();
  int _rating = 5;
  bool _isSubmitting = false;
  bool _isLoadingHistory = false;

  List<Map<String, dynamic>> _feedbackHistory = [];
  bool _historyLoadError = false;

  @override
  void initState() {
    super.initState();
    _loadFeedbackHistory();
  }

  Future<void> _loadFeedbackHistory() async {
    final cacheKey = _feedbackCacheKey;
    setState(() => _isLoadingHistory = true);

    try {
      final response = await DioClient().dio.get('/feedback');

      if (response.statusCode == 200) {
        final responseData = response.data;
        final rawList = responseData is List
            ? responseData
            : responseData is Map && responseData['data'] is List
            ? responseData['data'] as List
            : <dynamic>[];

        final loaded = rawList.map<Map<String, dynamic>>((e) {
          final map = Map<String, dynamic>.from(e);
          final createdAt = map['created_at']?.toString();
          return {
            'id': map['id']?.toString() ?? '',
            'name':
                map['user_name']?.toString() ??
                map['name']?.toString() ??
                'Pengguna',
            'user_email': map['user_email']?.toString() ?? '',
            'user_id': map['user_id']?.toString() ?? '',
            'rating': map['rating'] is int
                ? map['rating']
                : int.tryParse(map['rating']?.toString() ?? '5') ?? 5,
            'saran':
                map['saran']?.toString() ?? map['suggestion']?.toString() ?? '',
            'kesan':
                map['kesan']?.toString() ?? map['impression']?.toString() ?? '',
            'date':
                map['date']?.toString() ??
                (createdAt != null && createdAt.length >= 10
                    ? createdAt.substring(0, 10)
                    : ''),
          };
        }).toList();

        if (mounted) {
          setState(() {
            _feedbackHistory = loaded;
            _isLoadingHistory = false;
            _historyLoadError = false;
          });
        }

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, jsonEncode(loaded));
        } catch (error) {
          debugPrint('[Feedback] Gagal menyimpan cache riwayat: $error');
        }
        return;
      }
    } catch (error) {
      debugPrint('[Feedback] Gagal memuat riwayat dari server: $error');
    }

    await _loadFromLocalCache();
    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        _historyLoadError = true;
      });
    }
  }

  String get _feedbackCacheKey {
    return 'asuhkita_persisted_feedback_list_shared';
  }

  Future<void> _loadFromLocalCache() async {
    try {
      final cacheKey = _feedbackCacheKey;
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(cacheKey);
      List<Map<String, dynamic>> combined = [];
      if (savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(savedJson);
        combined = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }


      try {
        final dbFeedbacks = await LocalDatabase().getAllFeedbacks();
        for (var fb in dbFeedbacks) {
          final id = fb['id']?.toString() ?? '';
          if (!combined.any((item) => item['id']?.toString() == id)) {
            String saran = '';
            String kesan = '';
            final msg = fb['message']?.toString() ?? '';
            if (msg.contains('| Kesan:')) {
              final parts = msg.split('| Kesan:');
              saran = parts[0].replaceAll('Saran:', '').trim();
              kesan = parts.length > 1 ? parts[1].trim() : '';
            } else {
              saran = msg;
            }
            final createdAt = fb['created_at']?.toString() ?? '';
            combined.add({
              'id': id,
              'name': fb['user_name']?.toString() ?? 'Pengguna',
              'user_email': fb['user_email']?.toString() ?? '',
              'rating': fb['rating'] is int ? fb['rating'] : int.tryParse(fb['rating']?.toString() ?? '5') ?? 5,
              'saran': saran,
              'kesan': kesan,
              'date': createdAt.length >= 10 ? createdAt.substring(0, 10) : '',
              'created_at': createdAt,
            });
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _feedbackHistory = combined;
        });
      }
      return;
    } catch (error) {
      debugPrint('[Feedback] Gagal membaca cache riwayat: $error');
    }

    if (mounted) {
      setState(() => _feedbackHistory = []);
    }
  }

  Future<void> _saveFeedbackToLocalCache() async {
    try {
      final cacheKey = _feedbackCacheKey;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(_feedbackHistory));
    } catch (error) {
      debugPrint('[Feedback] Gagal menyimpan cache riwayat: $error');
    }
  }

  @override
  void dispose() {
    _saranController.dispose();
    _kesanController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      final auth = Provider.of<AuthProvider>(context, listen: false);

      final userName = auth.userName.isNotEmpty
          ? auth.userName
          : (auth.userRole == 'admin_panti'
                ? 'Admin Pengurus Panti'
                : 'Donatur Asuh');

      final newFeedback = {
        'id': 'fb_${DateTime.now().millisecondsSinceEpoch}',
        'name': userName,
        'user_email': auth.userEmail,
        'user_name': userName,
        'rating': _rating,
        'saran': _saranController.text.trim(),
        'kesan': _kesanController.text.trim(),
        'suggestion': _saranController.text.trim(),
        'impression': _kesanController.text.trim(),
        'date': DateTime.now().toString().substring(0, 10),
        'created_at': DateTime.now().toIso8601String(),
      };

      bool savedToServer = false;
      Map<String, dynamic>? serverFeedback;

      try {
        final response = await DioClient().dio.post(
          '/feedback',
          data: {
            'user_name': userName,
            'user_email': auth.userEmail,
            'rating': _rating,
            'saran': _saranController.text.trim(),
            'kesan': _kesanController.text.trim(),
            'suggestion': _saranController.text.trim(),
            'impression': _kesanController.text.trim(),
            'category': 'Kuliah PAM',
          },
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          savedToServer = true;
          final responseData = response.data;
          final data = responseData is Map ? responseData['data'] : null;
          if (data is Map) {
            final record = Map<String, dynamic>.from(data);
            serverFeedback = {
              ...newFeedback,
              'id': record['id']?.toString() ?? newFeedback['id'],
              'user_id': record['user_id']?.toString() ?? auth.userId,
              'user_email': record['user_email']?.toString() ?? auth.userEmail,
              'name': record['user_name']?.toString() ?? userName,
              'user_name': record['user_name']?.toString() ?? userName,
              'rating': record['rating'] is int
                  ? record['rating']
                  : int.tryParse(record['rating']?.toString() ?? '') ?? _rating,
              'saran': record['suggestion']?.toString() ?? newFeedback['saran'],
              'kesan': record['impression']?.toString() ?? newFeedback['kesan'],
              'created_at':
                  record['created_at']?.toString() ?? newFeedback['created_at'],
            };
          }
        }
      } catch (error) {
        debugPrint('[Feedback] Gagal mengirim ke server: $error');
      }

      try {
        await LocalDatabase().insertFeedback({
          'id': newFeedback['id'],
          'user_email': auth.userEmail,
          'user_name': userName,
          'rating': _rating,
          'category': 'Kuliah PAM',
          'message':
              'Saran: ${_saranController.text.trim()} | Kesan: ${_kesanController.text.trim()}',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (error) {
        debugPrint(
          '[Feedback] Gagal menyimpan feedback ke database lokal: $error',
        );
      }

      if (!mounted) return;
      setState(() {
        _feedbackHistory.insert(0, serverFeedback ?? newFeedback);
        _saranController.clear();
        _kesanController.clear();
        _isSubmitting = false;
      });

      await _saveFeedbackToLocalCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedToServer
                  ? 'Saran & Kesan terkirim dan dapat dilihat oleh admin serta donatur lain.'
                  : 'Server tidak dapat dijangkau. Saran & Kesan tersimpan di perangkat ini.',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  bool get _isAdmin =>
      Provider.of<AuthProvider>(context, listen: false).userRole ==
      'admin_panti';

  Future<void> _editFeedback(Map<String, dynamic> item) async {
    final suggestionController = TextEditingController(
      text: item['saran']?.toString() ?? '',
    );
    final impressionController = TextEditingController(
      text: item['kesan']?.toString() ?? '',
    );
    var rating = (item['rating'] as int?) ?? 5;
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Saran & Kesan'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: List.generate(
                      5,
                      (index) => IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () =>
                            setDialogState(() => rating = index + 1),
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: suggestionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Saran'),
                  ),
                  TextFormField(
                    controller: impressionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Kesan'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final suggestion = suggestionController.text.trim();
                final impression = impressionController.text.trim();
                if (suggestion.isEmpty && impression.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Isi minimal Saran atau Kesan.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'suggestion': suggestion,
                  'impression': impression,
                  'rating': rating,
                });
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    suggestionController.dispose();
    impressionController.dispose();
    if (updated == null) return;

    try {
      final response = await DioClient().dio.put(
        '/feedback/${item['id']}',
        data: updated,
      );
      final responseData = response.data;
      final result = responseData is Map ? responseData['data'] : null;
      final suggestion = updated['suggestion'] as String;
      final impression = updated['impression'] as String;
      if (!mounted) return;
      setState(() {
        final index = _feedbackHistory.indexWhere(
          (feedback) => feedback['id'] == item['id'],
        );
        if (index >= 0) {
          _feedbackHistory[index] = {
            ..._feedbackHistory[index],
            if (result is Map)
              'name': result['user_name']?.toString() ?? item['name'],
            'saran': suggestion,
            'kesan': impression,
            'suggestion': suggestion,
            'impression': impression,
            'rating': updated['rating'],
          };
        }
      });
      await _saveFeedbackToLocalCache();
    } catch (error) {
      debugPrint('[Feedback] Gagal mengubah feedback: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback gagal diubah. Coba lagi.')),
        );
      }
    }
  }

  Future<void> _deleteFeedback(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Saran & Kesan?'),
        content: const Text('Data ini akan dihapus untuk semua pengguna.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DioClient().dio.delete('/feedback/${item['id']}');
      if (!mounted) return;
      setState(() {
        _feedbackHistory.removeWhere(
          (feedback) => feedback['id'] == item['id'],
        );
      });
      await _saveFeedbackToLocalCache();
    } catch (error) {
      debugPrint('[Feedback] Gagal menghapus feedback: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback gagal dihapus. Coba lagi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Saran & Kesan PAM'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Perbarui Riwayat',
            onPressed: _loadFeedbackHistory,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Form Evaluasi Kuliah PAM',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kesan dan masukan untuk mata kuliah Pemrograman Aplikasi Mobile.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Divider(height: 20),

                      const Text(
                        'Penilaian Kepuasan Kuliah:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(5, (index) {
                          return IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 32,
                            ),
                            onPressed: () =>
                                setState(() => _rating = index + 1),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _saranController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Saran untuk Mata Kuliah PAM',
                          hintText:
                              'Tuliskan saran Anda untuk perbaikan ke depan...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Saran wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _kesanController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Kesan selama Perkuliahan PAM',
                          hintText:
                              'Tuliskan pengalaman & kesan Anda belajar PAM...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Kesan wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitFeedback,
                          icon: const Icon(Icons.send),
                          label: const Text('Kirim Saran & Kesan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Saran & Kesan Tersimpan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_isLoadingHistory)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _historyLoadError
                  ? 'Server tidak tersedia; menampilkan salinan lokal yang terakhir tersimpan.'
                  : _isAdmin
                  ? 'Admin dapat melihat dan mengelola seluruh feedback.'
                  : 'Menampilkan feedback dari semua akun donatur.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 12),

            _feedbackHistory.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Belum ada saran & kesan.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _feedbackHistory.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _feedbackHistory[index];
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['name'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item['date'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (_isAdmin) ...[
                                    const SizedBox(width: 4),
                                    PopupMenuButton<String>(
                                      tooltip: 'Kelola feedback',
                                      onSelected: (action) {
                                        if (action == 'edit') {
                                          _editFeedback(item);
                                        } else if (action == 'delete') {
                                          _deleteFeedback(item);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Hapus'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(
                                  (item['rating'] ?? 5) as int,
                                  (_) => const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Saran: "${item['saran'] ?? ''}"',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kesan: "${item['kesan'] ?? ''}"',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
