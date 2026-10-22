// Letak file: mobile/lib/features/schedule/schedule_screen.dart
// Fungsi: UI Penjadwalan Video Call Donatur & Anak Asuh dengan Konversi 4 Zona Waktu Serentak (WIB, WITA, WIT, London) (PBI-046, FR-38, FR-39)
// Upgrade : Integrasi NotificationService pengingat Video Call (PBI-055, FR-41)

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';

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
        backgroundColor: AppColors.primary,
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
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
                        prefixIcon: const Icon(Icons.face, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _topicController,
                      decoration: InputDecoration(
                        labelText: 'Topik Panggilan Video',
                        prefixIcon: const Icon(Icons.videocam_outlined, color: AppColors.primary),
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
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_month, color: AppColors.primary),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat('dd MMM yyyy • HH:mm').format(_selectedDateTime),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            const Text('Ubah', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
                    color: isLondon ? Colors.indigo.shade200 : AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isLondon ? Colors.indigo.shade50 : AppColors.surfaceLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isLondon ? Icons.public : Icons.access_time_filled,
                          color: isLondon ? Colors.indigo : AppColors.primary,
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
                                color: isLondon ? Colors.indigo.shade900 : AppColors.primaryDark,
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
              onPressed: () async {
                // FR-41 | PBI-055: Jadwalkan notifikasi lokal pengingat video call
                await NotificationService().scheduleVideoCallReminder(
                  id: _selectedDateTime.millisecondsSinceEpoch ~/ 1000 % 100000,
                  childAlias: _childController.text.trim(),
                  scheduledDateTime: _selectedDateTime,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Jadwal video call berhasil disimpan! Notifikasi pengingat 30 menit sebelum disiapkan.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Simpan & Pasang Pengingat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
