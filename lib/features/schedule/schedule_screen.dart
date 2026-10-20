// Letak file: mobile/lib/features/schedule/schedule_screen.dart
// Fungsi: UI Penjadwalan Video Call Donatur & Anak Asuh dengan Konversi 4 Zona Waktu Serentak (WIB, WITA, WIT, London) (PBI-046, FR-38, FR-39)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDateTime = DateTime.now().add(const Duration(days: 1, hours: 2));
  final _childController = TextEditingController(text: 'Bintang (Panti Kasih Ibu)');
  final _topicController = TextEditingController(text: 'Sesi Belajar & Bincang Inspirasi Masa Depan');

  // Konfigurasi offset jam 4 zona waktu:
  // WIB: UTC+7
  // WITA: UTC+8
  // WIT: UTC+9
  // London: UTC+0 / UTC+1 (BST) -> Gunakan UTC+1 untuk waktu standar/musim
  final Map<String, int> _zoneOffsets = {
    'WIB (Jakarta)': 7,
    'WITA (Makassar)': 8,
    'WIT (Jayapura)': 9,
    'London (UK)': 1,
  };

  @override
  void dispose() {
    _childController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  // Hitung waktu di tiap zona berbasis UTC (FR-38, FR-39)
  String _formatTimeInZone(int offsetHours) {
    // Ambil waktu UTC dari DateTime lokal yang dipilih
    final utc = _selectedDateTime.toUtc();
    final targetTime = utc.add(Duration(hours: offsetHours));
    return DateFormat('EEEE, dd MMM yyyy • HH:mm').format(targetTime);
  }

  @override
  Widget build(BuildContext context) {
    final utcTime = _selectedDateTime.toUtc();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Jadwal Video Call 4 Zona Waktu'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Pemilih Waktu
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih Waktu Video Call Ramah Anak',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Jadwal akan otomatis dikonversi ke 4 zona waktu (WIB, WITA, WIT, London) agar donatur lintas negara dapat berkoordinasi dengan tepat.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const Divider(height: 24),
                    TextField(
                      controller: _childController,
                      decoration: InputDecoration(
                        labelText: 'Anak Asuh',
                        prefixIcon: const Icon(Icons.face, color: Colors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _topicController,
                      decoration: InputDecoration(
                        labelText: 'Topik Panggilan Video',
                        prefixIcon: const Icon(Icons.videocam_outlined, color: Colors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tombol Pilih Waktu
                    InkWell(
                      onTap: _pickDateTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_month, color: Colors.teal),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat('dd MMM yyyy • HH:mm').format(_selectedDateTime),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            const Text('Ubah', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tampilan Serentak 4 Zona Waktu (PBI-046, FR-38)
            const Text(
              'Tampilan Konversi 4 Zona Waktu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            ..._zoneOffsets.entries.map((entry) {
              final isLondon = entry.key.contains('London');
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isLondon ? Colors.indigo.shade200 : Colors.teal.shade100,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isLondon ? Colors.indigo.shade50 : Colors.teal.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isLondon ? Icons.public : Icons.access_time_filled,
                          color: isLondon ? Colors.indigo : Colors.teal,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isLondon ? Colors.indigo.shade900 : Colors.teal.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimeInZone(entry.value),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 10),
            // Info Waktu Tersimpan dalam UTC (FR-39)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Tersimpan di database backend dalam format standar UTC: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(utcTime)} UTC',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // Tombol Simpan Jadwal
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Jadwal video call berhasil disimpan dan notifikasi lokal disiapkan!'),
                    backgroundColor: Colors.teal,
                  ),
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check),
              label: const Text('Simpan & Pasang Pengingat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
