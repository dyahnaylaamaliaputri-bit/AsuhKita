// Letak file: mobile/lib/features/ai_assistant/ai_assistant_screen.dart
// Fungsi: UI Sahabat Asuh Berbasis AI/LLM - Gemini 1.5 Flash
//         - Bantu Tulis Surat untuk Anak Asuh (PBI-062, FR-49)
//         - Ringkas Laporan Perkembangan Anak  (PBI-062, FR-50)
//         - Chatbot FAQ Sahabat Asuh           (PBI-062, FR-51)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../services/gemini_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GeminiService _gemini = GeminiService();

  // -- Tab 1: Bantu Tulis Surat --
  final _letterChildNameController = TextEditingController();
  final _letterTopicController = TextEditingController();
  String _generatedLetter = '';
  bool _isLoadingLetter = false;

  // -- Tab 2: Ringkas Laporan --
  final _reportInputController = TextEditingController();
  String _summarizedReport = '';
  bool _isLoadingSummary = false;

  // -- Tab 3: Chatbot FAQ --
  final _faqQuestionController = TextEditingController();
  final _faqScrollController = ScrollController();
  bool _isLoadingFaq = false;

  // Format riwayat: {'role': 'user'/'model', 'text': '...'}
  // Riwayat dipertahankan selama sesi agar konteks percakapan menyambung
  final List<Map<String, String>> _faqHistory = [
    {
      'role': 'model',
      'text':
          'Halo! Saya Sahabat Asuh, asisten AI AsuhKita yang siap membantu. '
          'Tanyakan apapun tentang donasi, anak asuh, atau cara penggunaan aplikasi!',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _letterChildNameController.dispose();
    _letterTopicController.dispose();
    _reportInputController.dispose();
    _faqQuestionController.dispose();
    _faqScrollController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // FR-49 | PBI-062 - Generate Surat dengan Gemini
  // ----------------------------------------------------------
  Future<void> _generateLetter() async {
    final alias = _letterChildNameController.text.trim();
    final topic = _letterTopicController.text.trim();
    if (alias.isEmpty || topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon isi nama anak dan topik terlebih dahulu.')),
      );
      return;
    }

    setState(() => _isLoadingLetter = true);
    final result = await _gemini.generateLetter(childAlias: alias, topic: topic);
    setState(() {
      _generatedLetter = result;
      _isLoadingLetter = false;
    });
  }

  // ----------------------------------------------------------
  // FR-50 | PBI-062 - Ringkas Laporan dengan Gemini
  // ----------------------------------------------------------
  Future<void> _summarizeReport() async {
    final text = _reportInputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon masukkan teks laporan terlebih dahulu.')),
      );
      return;
    }

    setState(() => _isLoadingSummary = true);
    final result = await _gemini.summarizeReport(text);
    setState(() {
      _summarizedReport = result;
      _isLoadingSummary = false;
    });
  }

  // ----------------------------------------------------------
  // FR-51 | PBI-062 - Tanya FAQ dengan Gemini (Chat mode)
  // Percakapan harus menyambung dan sesuai konteks
  // ----------------------------------------------------------
  Future<void> _askFaq() async {
    final q = _faqQuestionController.text.trim();
    if (q.isEmpty || _isLoadingFaq) return;

    setState(() {
      _faqHistory.add({'role': 'user', 'text': q});
      _faqQuestionController.clear();
      _isLoadingFaq = true;
    });
    _scrollToBottom();

    // Kirim ke Gemini dengan SELURUH riwayat percakapan sebelumnya
    // agar jawaban sesuai konteks dan menyambung
    final answer = await _gemini.askFaq(q, history: _faqHistory);

    setState(() {
      _faqHistory.add({'role': 'model', 'text': answer});
      _isLoadingFaq = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_faqScrollController.hasClients) {
        _faqScrollController.animateTo(
          _faqScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ----------------------------------------------------------
  // Widget Helpers
  // ----------------------------------------------------------
  Widget _geminiChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              'Gemini AI',
              style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sahabat Asuh (Asisten AI)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [_geminiChip(), const SizedBox(width: 8)],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent2,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note), text: 'Bantu Tulis Surat'),
            Tab(icon: Icon(Icons.summarize), text: 'Ringkas Laporan'),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Tanya FAQ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --------------- TAB 1: BANTU TULIS SURAT (FR-49) ---------------
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.favorite, color: AppColors.secondary, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Kirim Kata-Kata Hangat untuk Anak Asuh',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Gemini AI akan membantu menulis surat yang hangat dan personal.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _letterChildNameController,
                          decoration: InputDecoration(
                            labelText: 'Nama Samaran Anak',
                            prefixIcon: const Icon(Icons.face, color: AppColors.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _letterTopicController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Topik atau Harapan Anda',
                            prefixIcon: const Icon(Icons.lightbulb_outline, color: AppColors.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _isLoadingLetter ? null : _generateLetter,
                          icon: _isLoadingLetter
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.auto_awesome),
                          label: Text(_isLoadingLetter ? 'Gemini sedang menulis...' : 'Buat Draf Surat dengan Gemini'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_generatedLetter.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: AppColors.surfaceLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Draf Surat AI (Dapat Diedit)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                              IconButton(
                                icon: const Icon(Icons.copy, color: AppColors.primary, size: 20),
                                tooltip: 'Salin ke clipboard',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _generatedLetter));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Surat disalin ke clipboard!')),
                                  );
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 12),
                          TextFormField(
                            initialValue: _generatedLetter,
                            maxLines: null,
                            decoration: const InputDecoration(border: InputBorder.none),
                            style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Surat berhasil dikirim ke panti!'), backgroundColor: AppColors.primary),
                              );
                            },
                            icon: const Icon(Icons.send),
                            label: const Text('Kirim Surat Ini'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // --------------- TAB 2: RINGKAS LAPORAN (FR-50) ---------------
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.summarize, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ringkas Laporan Perkembangan Anak',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tempel laporan panjang dari pengurus panti, Gemini akan meringkasnya jadi poin singkat.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _reportInputController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: 'Teks Laporan dari Pengurus Panti',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _isLoadingSummary ? null : _summarizeReport,
                          icon: _isLoadingSummary
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.compress),
                          label: Text(_isLoadingSummary ? 'Gemini sedang meringkas...' : 'Ringkas dengan Bahasa Sederhana'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_summarizedReport.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: AppColors.accent1, size: 18),
                              SizedBox(width: 6),
                              Text('Hasil Ringkasan Gemini', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                            ],
                          ),
                          const Divider(height: 14),
                          Text(_summarizedReport, style: const TextStyle(fontSize: 14, height: 1.7, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // --------------- TAB 3: CHATBOT FAQ (FR-51) ---------------
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _faqScrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _faqHistory.length + (_isLoadingFaq ? 1 : 0),
                  itemBuilder: (context, idx) {
                    if (idx == _faqHistory.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                        ),
                      );
                    }
                    final item = _faqHistory[idx];
                    final isUser = item['role'] == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.only(
                          bottom: 10,
                          left: isUser ? 40 : 0,
                          right: isUser ? 0 : 40,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(isUser ? 14 : 0),
                            bottomRight: Radius.circular(isUser ? 0 : 14),
                          ),
                          border: isUser ? null : Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Text(
                          item['text'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: isUser ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _faqQuestionController,
                          decoration: InputDecoration(
                            hintText: 'Tanyakan sesuatu tentang AsuhKita...',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.primary)),
                          ),
                          onSubmitted: (_) => _askFaq(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _isLoadingFaq ? null : _askFaq,
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.send, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
