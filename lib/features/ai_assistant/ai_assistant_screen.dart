// Letak file: mobile/lib/features/ai_assistant/ai_assistant_screen.dart
// Fungsi: UI Sahabat Asuh Berbasis AI/LLM - Gemini 1.5 Flash
//         - Bantu Tulis Surat untuk Anak Asuh (PBI-062, FR-49)
//         - Ringkas Laporan Perkembangan Anak  (PBI-062, FR-50)
//         - Chatbot FAQ Sahabat Asuh           (PBI-062, FR-51)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _letterChildNameController = TextEditingController(text: 'Bintang');
  final _letterTopicController = TextEditingController(
    text: 'Memberikan semangat belajar untuk ujian kenaikan kelas dan cita-citanya.',
  );
  String _generatedLetter = '';
  bool _isLoadingLetter = false;

  // -- Tab 2: Ringkas Laporan --
  final _reportInputController = TextEditingController(
    text:
        'Selama cawu ketiga, Ananda Bintang menunjukkan peningkatan luar biasa pada mata '
        'pelajaran matematika dengan nilai rata-rata 88. Di asrama, Bintang selalu tepat '
        'waktu mengikuti kegiatan mengaji sore dan terpilih menjadi ketua kelompok kebersihan kamar.',
  );
  String _summarizedReport = '';
  bool _isLoadingSummary = false;

  // -- Tab 3: Chatbot FAQ --
  final _faqQuestionController = TextEditingController();
  final _faqScrollController = ScrollController();
  bool _isLoadingFaq = false;

  // Format riwayat: {'role': 'user'/'model', 'text': '...'}
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
    if (alias.isEmpty || topic.isEmpty) return;

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
    if (text.isEmpty) return;

    setState(() => _isLoadingSummary = true);
    final result = await _gemini.summarizeReport(text);
    setState(() {
      _summarizedReport = result;
      _isLoadingSummary = false;
    });
  }

  // ----------------------------------------------------------
  // FR-51 | PBI-062 - Tanya FAQ dengan Gemini (Chat mode)
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

    // Kirim ke Gemini dengan riwayat percakapan sebelumnya
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
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.auto_awesome, color: Colors.blue, size: 14),
            SizedBox(width: 4),
            Text(
              'Powered by Gemini 1.5 Flash',
              style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Sahabat Asuh (Asisten AI)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [_geminiChip(), const SizedBox(width: 8)],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
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
                        Row(
                          children: const [
                            Icon(Icons.favorite, color: Colors.teal, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Kirim Kata-Kata Hangat untuk Anak Asuh',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gemini AI akan membantu menulis surat yang hangat dan personal.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _letterChildNameController,
                          decoration: InputDecoration(
                            labelText: 'Nama Samaran Anak',
                            prefixIcon: const Icon(Icons.face, color: Colors.teal),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _letterTopicController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Topik atau Harapan Anda',
                            prefixIcon: const Icon(Icons.lightbulb_outline, color: Colors.teal),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _isLoadingLetter ? null : _generateLetter,
                          icon: _isLoadingLetter
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(_isLoadingLetter
                              ? 'Gemini sedang menulis...'
                              : 'Buat Draf Surat dengan Gemini'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_generatedLetter.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.teal.shade50,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Draf Surat AI (Dapat Diedit)',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, color: Colors.teal, size: 20),
                                tooltip: 'Salin ke clipboard',
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: _generatedLetter));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Surat disalin ke clipboard!')),
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
                            style:
                                const TextStyle(fontSize: 14, height: 1.6),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Surat berhasil dikirim ke panti untuk disampaikan ke anak asuh!'),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            },
                            icon: const Icon(Icons.send),
                            label: const Text('Kirim Surat Ini'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
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
                        Row(
                          children: const [
                            Icon(Icons.summarize, color: Colors.teal, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Ringkas Laporan Perkembangan Anak',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tempel laporan panjang dari pengurus panti, Gemini akan meringkasnya jadi poin singkat.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _reportInputController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: 'Teks Laporan dari Pengurus Panti',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _isLoadingSummary ? null : _summarizeReport,
                          icon: _isLoadingSummary
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.compress),
                          label: Text(_isLoadingSummary
                              ? 'Gemini sedang meringkas...'
                              : 'Ringkas dengan Bahasa Sederhana'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
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
                      side: BorderSide(color: Colors.teal.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.check_circle, color: Colors.teal, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Hasil Ringkasan Gemini',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Text(
                            _summarizedReport,
                            style: const TextStyle(fontSize: 14, height: 1.7),
                          ),
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
                      // Loading indicator
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.teal),
                          ),
                        ),
                      );
                    }
                    final item = _faqHistory[idx];
                    final isUser = item['role'] == 'user';
                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.only(
                          bottom: 10,
                          left: isUser ? 40 : 0,
                          right: isUser ? 0 : 40,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Colors.teal
                              : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(isUser ? 14 : 0),
                            bottomRight: Radius.circular(isUser ? 0 : 14),
                          ),
                          border: isUser
                              ? null
                              : Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          item['text'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: isUser ? Colors.white : Colors.black87,
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
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, -2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _faqQuestionController,
                          decoration: InputDecoration(
                            hintText: 'Tanyakan sesuatu tentang AsuhKita...',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                          ),
                          onSubmitted: (_) => _askFaq(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.teal,
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
