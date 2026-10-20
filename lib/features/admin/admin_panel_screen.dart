// Letak file: mobile/lib/features/admin/admin_panel_screen.dart
// Fungsi: Layar Panel Pengurus Panti untuk kelola data anak, upload laporan perkembangan & bukti dana (PBI-039, FR-32, FR-33, FR-34)

import 'package:flutter/material.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _aliasController = TextEditingController();
  final _ageController = TextEditingController();
  final _reportSummaryController = TextEditingController();
  final _expenseAmountController = TextEditingController();
  String _selectedCategory = 'Pendidikan';

  final List<Map<String, dynamic>> _managedChildren = [
    {'id': 'c1', 'alias': 'Bintang', 'age': 9, 'category': 'Pendidikan', 'status': 'Aktif Disponsori'},
    {'id': 'c2', 'alias': 'Alya', 'age': 7, 'category': 'Kebutuhan Sehari-hari', 'status': 'Tersedia'},
  ];

  @override
  void dispose() {
    _aliasController.dispose();
    _ageController.dispose();
    _reportSummaryController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  void _showAddChildDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Data Anak Asuh'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _aliasController,
                decoration: const InputDecoration(labelText: 'Nama Samaran (Alias)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Usia (Tahun)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                items: ['Pendidikan', 'Kebutuhan Sehari-hari', 'Perawatan Esensial']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
                decoration: const InputDecoration(labelText: 'Kategori Kebutuhan'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (_aliasController.text.isNotEmpty && _ageController.text.isNotEmpty) {
                setState(() {
                  _managedChildren.add({
                    'id': 'c_${DateTime.now().millisecondsSinceEpoch}',
                    'alias': _aliasController.text.trim(),
                    'age': int.tryParse(_ageController.text) ?? 8,
                    'category': _selectedCategory,
                    'status': 'Tersedia',
                  });
                  _aliasController.clear();
                  _ageController.clear();
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Anak asuh baru berhasil didaftarkan!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showUploadProofDialog(String childAlias) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unggah Penyaluran Dana ($childAlias)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _expenseAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nominal Penyaluran (IDR)', prefixText: 'Rp '),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reportSummaryController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Keterangan Penggunaan Dana & Kuitansi'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Foto kuitansi berhasil dilampirkan.')),
                  );
                },
                icon: const Icon(Icons.attach_file),
                label: const Text('Lampirkan Kuitansi/Bukti'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Laporan & Bukti Berhasil Diunggah! Blok PENYALURAN baru dicatat ke Blockchain.'),
                  backgroundColor: Colors.teal,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('Kirim ke Ledger'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Panel Admin Pengurus Panti'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddChildDialog,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Tambah Anak Asuh', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings, color: Colors.teal, size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Kelola Transparansi Panti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Setiap bukti pengeluaran yang diunggah akan otomatis diterbitkan ke rantai blok ledger.', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Daftar Anak Asuh Terdaftar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _managedChildren.length,
            itemBuilder: (context, idx) {
              final ch = _managedChildren[idx];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: const Icon(Icons.face, color: Colors.teal),
                  ),
                  title: Text('${ch['alias']} (${ch['age']} th)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${ch['category']} • Status: ${ch['status']}'),
                  trailing: ElevatedButton(
                    onPressed: () => _showUploadProofDialog(ch['alias']),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10)),
                    child: const Text('Bukti Dana', style: TextStyle(fontSize: 12)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
