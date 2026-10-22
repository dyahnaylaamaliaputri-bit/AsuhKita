// Letak file: mobile/lib/features/communication/family_room_screen.dart
// Fungsi: Fitur Komunikasi Hangat antara Anak Asuh & Orang Tua Asuh (Surat Cinta, Galeri Karya Sekolah, dan Video Call Ramah Anak)

import 'package:flutter/material.dart';

class FamilyRoomScreen extends StatefulWidget {
  final String childAlias;
  final String childAvatar;

  const FamilyRoomScreen({
    super.key,
    this.childAlias = 'Arfa',
    this.childAvatar = 'https://www.pedulianak.org/wp-content/uploads/2025/08/6-200x300.jpg',
  });

  @override
  State<FamilyRoomScreen> createState() => _FamilyRoomScreenState();
}

class _FamilyRoomScreenState extends State<FamilyRoomScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _messageController = TextEditingController();

  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'child',
      'text': 'Halo Ayah/Bunda Asuh! Hari ini Arfa dapat nilai 95 di ulangan Matematika lho. Terima kasih atas buku-buku yang dikirimkan!',
      'time': '10:15',
    },
    {
      'sender': 'donor',
      'text': 'Wah hebat sekali Arfa! Ayah/Bunda sangat bangga padamu. Terus semangat belajar ya nak, jaga kesehatan selalu!',
      'time': '10:20',
    },
    {
      'sender': 'child',
      'text': 'Iya Ayah/Bunda, Arfa juga sudah selesai menggambar rumah impian kita, Arfa upload di tab Karya Sekolah ya!',
      'time': '10:25',
    },
  ];

  final List<Map<String, dynamic>> _childArtworks = [
    {
      'title': 'Lukisan "Rumah Impian Masa Depan"',
      'desc': 'Dibuat saat pelajaran Seni Budaya kelas 3 SD. Juara 2 Lomba Menggambar Antar-Panti.',
      'image': 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=400&q=80',
      'date': '2026-10-18',
    },
    {
      'title': 'Kerajinan Tangan Origami Burung Harapan',
      'desc': 'Dibuat dari kertas daur ulang untuk dihadiahkan kepada orang tua asuh.',
      'image': 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&w=400&q=80',
      'date': '2026-10-12',
    },
    {
      'title': 'Rapor Cawu: Peringkat 3 di Kelas',
      'desc': 'Nilai rata-rata 89. Sangat aktif dalam pelajaran IPA dan Mengaji sore.',
      'image': 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?auto=format&fit=crop&w=400&q=80',
      'date': '2026-10-05',
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
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'sender': 'donor',
        'text': text,
        'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      });
      _messageController.clear();
    });

    // Simulasi respon hangat dari anak asuh
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'child',
            'text': 'Terima kasih banyak pesannya! Senang sekali bisa ngobrol sama Ayah/Bunda 🥰',
            'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          });
        });
      }
    });
  }

  void _startVideoCall() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Container(
          color: Colors.black87,
          child: Stack(
            children: [
              // Tampilan Video Anak Asuh
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 80,
                      backgroundImage: NetworkImage(widget.childAvatar),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.childAlias,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Video Call Kasih Sedang Berlangsung... (00:45)', style: TextStyle(color: Colors.tealAccent, fontSize: 13)),
                  ],
                ),
              ),

              // Tombol Kontrol Panggilan
              Positioned(
                bottom: 40,
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
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      radius: 28,
                      child: IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () {}),
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Ruang Kasih: ${widget.childAlias}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Video Call Ramah Anak',
            onPressed: _startVideoCall,
          ),
          IconButton(
            icon: const Icon(Icons.phone),
            tooltip: 'Panggilan Suara',
            onPressed: _startVideoCall,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.mail_outline), text: 'Surat Kasih'),
            Tab(icon: Icon(Icons.palette_outlined), text: 'Karya Sekolah'),
            Tab(icon: Icon(Icons.video_call), text: 'Telepon Kasih'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: SURAT KASIH
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, idx) {
                    final msg = _messages[idx];
                    final isDonor = msg['sender'] == 'donor';
                    return Align(
                      alignment: isDonor ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                        decoration: BoxDecoration(
                          color: isDonor ? Colors.teal : Colors.white,
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
                            Text(
                              msg['text'],
                              style: TextStyle(color: isDonor ? Colors.white : Colors.black87, fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg['time'],
                              style: TextStyle(color: isDonor ? Colors.white70 : Colors.grey, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Tulis pesan kasih untuk ${widget.childAlias}...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // TAB 2: KARYA SEKOLAH
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _childArtworks.length,
            itemBuilder: (context, idx) {
              final art = _childArtworks[idx];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.network(
                      art['image'],
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 180,
                        color: Colors.teal.shade50,
                        child: const Center(child: Icon(Icons.palette, size: 48, color: Colors.teal)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(art['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                              Text(art['date'], style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(art['desc'], style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // TAB 3: TELEPON KASIH
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(widget.childAvatar),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Panggilan Video & Suara Langsung',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Luangkan waktu berharga untuk mendengarkan cerita ${widget.childAlias} dan memberikan kehadiran orang tua asuh yang sesungguhnya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _startVideoCall,
                    icon: const Icon(Icons.videocam),
                    label: Text('Mulai Video Call Bersama ${widget.childAlias}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}
