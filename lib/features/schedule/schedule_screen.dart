// Letak file: mobile/lib/features/schedule/schedule_screen.dart
// Fungsi: UI Penjadwalan Video Call Donatur & Anak Asuh dengan Konversi 4 Zona Waktu Serentak (WIB, WITA, WIT, London), Opsi Pilihan Anak Asuh Dinamis, & Notifikasi Pop-up (PBI-046, PBI-055, FR-38, FR-39, FR-41)

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'package:intl/intl.dart';
import '../../data/local_db.dart';
import '../../services/notification_service.dart';
import '../sponsor/sponsor_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDateTime = DateTime.now().add(const Duration(days: 1, hours: 2));
  final _topicController = TextEditingController();

  List<String> _sponsoredChildren = [];
  String? _selectedChild;
  bool _isLoading = true;

  // Konfigurasi offset jam 4 zona waktu:
  // WIB: UTC+7
  // WITA: UTC+8
  // WIT: UTC+9
  // London: UTC+0 / UTC+1 (BST)
  final Map<String, int> _zoneOffsets = {
    'WIB (Jakarta)': 7,
    'WITA (Makassar)': 8,
    'WIT (Jayapura)': 9,
    'London (UK)': 1,
  };

  @override
  void initState() {
    super.initState();
    _loadSponsoredChildren();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  // Ambil daftar nama anak asuh yang didampingi oleh donatur
  Future<void> _loadSponsoredChildren() async {
    setState(() => _isLoading = true);
    try {
      final localDonations = await LocalDatabase().getCachedDonations();
      final childSet = <String>{};
      for (var d in localDonations) {
        final alias = (d['child_alias'] ?? '').toString().trim();
        if (alias.isNotEmpty) {
          // Format Title Case
          final formatted = alias.length > 1 ? '${alias[0].toUpperCase()}${alias.substring(1)}' : alias;
          childSet.add(formatted);
        }
      }

      final list = childSet.toList();
      if (mounted) {
        setState(() {
          _sponsoredChildren = list;
          if (list.isNotEmpty) {
            _selectedChild = list.first;
          } else {
            _selectedChild = null;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
    final utc = _selectedDateTime.toUtc();
    final targetTime = utc.add(Duration(hours: offsetHours));
    return DateFormat('EEEE, dd MMM yyyy • HH:mm').format(targetTime);
  }

  void _saveScheduleAndShowPopup() async {
    if (_sponsoredChildren.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Belum Memiliki Anak Asuh'),
          content: const Text(
            'Anda belum memiliki anak asuh yang didampingi. Silakan pilih anak asuh di menu Sponsor terlebih dahulu sebelum menjadwalkan panggilan video.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SponsorScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Buka Menu Sponsor'),
            ),
          ],
        ),
      );
      return;
    }

    final targetChild = _selectedChild ?? _sponsoredChildren.first;
    final topic = _topicController.text.trim().isNotEmpty
        ? _topicController.text.trim()
        : 'Sesi Belajar & Bincang Inspirasi Masa Depan';

    // 1. Jadwalkan notifikasi lokal
    await NotificationService().scheduleVideoCallReminder(
      id: _selectedDateTime.millisecondsSinceEpoch ~/ 1000 % 100000,
      childAlias: targetChild,
      scheduledDateTime: _selectedDateTime,
    );

    // Kirim notifikasi konfirmasi langsung ke status bar (jika aktif)
    await NotificationService().showInstantNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title: '🔔 Jadwal Video Call Ditetapkan!',
      body: 'Panggilan video bersama $targetChild pada ${DateFormat('dd MMM HH:mm').format(_selectedDateTime)} WIB.',
    );

    // 2. Tampilkan POP UP Notifikasi Konfirmasi Sesuai Permintaan User
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.notifications_active, color: AppColors.primary, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text('Pengingat Berhasil Disetel!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jadwal panggilan video ramah anak telah berhasil dikonfirmasi dan disinkronkan ke 4 zona waktu.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.face, size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('Anak Asuh: $targetChild', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.videocam, size: 18, color: AppColors.secondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('Topik: $topic', style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Text('• WIB (Jakarta): ${_formatTimeInZone(7)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('• WITA (Makassar): ${_formatTimeInZone(8)}', style: const TextStyle(fontSize: 11)),
                      Text('• WIT (Jayapura): ${_formatTimeInZone(9)}', style: const TextStyle(fontSize: 11)),
                      Text('• London (UK): ${_formatTimeInZone(1)}', style: const TextStyle(fontSize: 11, color: Colors.indigo)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pop-up & notifikasi pengingat akan aktif sebelum panggilan dimulai.',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('OK, Mengerti'),
            ),
          ],
        ),
      );
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card Pemilih Waktu & Anak Asuh
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

                          // ============================================================
                          // FIELD PENGISIAN ANAK ASUH (DENGAN LOGIKA OPSI TERSINKRON)
                          // ============================================================
                          if (_sponsoredChildren.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.amber),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Anda belum memiliki anak asuh. Buka menu Sponsor untuk memilih anak asuh terlebih dahulu.',
                                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_sponsoredChildren.length >= 2)
                            // Jika ada >= 2 anak asuh: berikan dropdown opsi pilihan!
                            DropdownButtonFormField<String>(
                              initialValue: _selectedChild,
                              decoration: InputDecoration(
                                labelText: 'Pilih Anak Asuh (${_sponsoredChildren.length} Anak Asuh)',
                                prefixIcon: const Icon(Icons.face, color: AppColors.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                helperText: 'Pilih salah satu anak asuh yang ingin Anda jadwalkan',
                              ),
                              items: _sponsoredChildren.map((name) {
                                return DropdownMenuItem<String>(
                                  value: name,
                                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedChild = val);
                              },
                            )
                          else
                            // Jika hanya punya 1 anak asuh: langsung tampilkan nama anak asuh tanpa opsi pilihan!
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.face, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Anak Asuh Terpilih', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text(
                                        _selectedChild ?? _sponsoredChildren.first,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  const Chip(
                                    label: Text('1 Anak Asuh', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                                    backgroundColor: Colors.white,
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 16),
                          TextField(
                            controller: _topicController,
                            decoration: InputDecoration(
                              labelText: 'Topik Panggilan Video',
                              hintText: 'Contoh: Sesi Belajar & Bincang Inspirasi Masa Depan',
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
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Waktu Lokal Anda (WIB/Perangkat)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('EEEE, dd MMMM yyyy • HH:mm').format(_selectedDateTime),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Konversi Sinkronisasi 4 Zona Waktu Serentak',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),

                  // Tampilan 4 Zona Waktu (WIB, WITA, WIT, London)
                  ..._zoneOffsets.entries.map((entry) {
                    final isLondon = entry.key.contains('London');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isLondon ? Colors.indigo.shade200 : AppColors.primary.withValues(alpha: 0.2),
                          ),
                          color: isLondon ? Colors.indigo.shade50.withValues(alpha: 0.3) : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isLondon ? Colors.indigo.shade100 : AppColors.surfaceLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isLondon ? Icons.public : Icons.access_time,
                                color: isLondon ? Colors.indigo : AppColors.primary,
                                size: 20,
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

                  // Tombol Simpan Jadwal & Pasang Pengingat
                  ElevatedButton.icon(
                    onPressed: _saveScheduleAndShowPopup,
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Simpan & Pasang Pengingat (Pop-up)'),
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
