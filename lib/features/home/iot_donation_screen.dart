// Letak file: mobile/lib/features/home/iot_donation_screen.dart
// Fungsi: Tampilan Event Donasi Kotak Amal Pintar IoT ESP32 & Fallback Simulasi (PBI-069, FR-52, FR-53, FR-54)

import 'package:flutter/material.dart';

class IotDonationScreen extends StatefulWidget {
  const IotDonationScreen({super.key});

  @override
  State<IotDonationScreen> createState() => _IotDonationScreenState();
}

class _IotDonationScreenState extends State<IotDonationScreen> {
  final List<Map<String, dynamic>> _iotEvents = [
    {
      'id': 'iot_01',
      'device_name': 'Kotak Amal ESP32 Panti Kasih Ibu',
      'nominal': 50000,
      'timestamp': '2026-10-19 16:30',
      'block_hash': '0000e47192837bcda12',
    },
    {
      'id': 'iot_02',
      'device_name': 'Kotak Amal ESP32 Harapan Mulia',
      'nominal': 20000,
      'timestamp': '2026-10-18 11:15',
      'block_hash': '0000109fbc81293ac44',
    },
  ];

  void _simulateIotEvent(int nominal) {
    final newEvent = {
      'id': 'iot_${DateTime.now().millisecondsSinceEpoch}',
      'device_name': 'Kotak Amal ESP32 (Simulasi Sensor IR)',
      'nominal': nominal,
      'timestamp': DateTime.now().toString().substring(0, 16),
      'block_hash': '0000${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}',
    };

    setState(() {
      _iotEvents.insert(0, newEvent);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sensor IR ESP32 Mendeteksi Uang Masuk Rp ${nominal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}! Blok DONASI_KOTAK dibuat di Ledger.'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Kotak Amal Pintar (IoT ESP32)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Banner Status IoT
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.sensors, color: Colors.teal, size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Integrasi Hardware ESP32', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 4),
                        Text(
                          'Mendeteksi uang tunai masuk lewat sensor IR, menandatangani data dengan HMAC, dan otomatis menerbitkan blok ledger.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tombol Simulasi Fallback (FR-54)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Simulasi Sensor IR & Tombol Nominal ESP32 (Fallback Demo)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _simulateIotEvent(10000),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                          child: const Text('+ Rp 10.000'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _simulateIotEvent(20000),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                          child: const Text('+ Rp 20.000'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _simulateIotEvent(50000),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                          child: const Text('+ Rp 50.000'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _simulateIotEvent(100000),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                          child: const Text('+ Rp 100.000'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Riwayat Deteksi Kotak Amal IoT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _iotEvents.length,
            itemBuilder: (context, idx) {
              final ev = _iotEvents[idx];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.amber,
                    child: Icon(Icons.savings, color: Colors.white),
                  ),
                  title: Text(
                    'Rp ${ev['nominal'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ev['device_name']),
                      Text('Blok Hash: ${ev['block_hash']}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                    ],
                  ),
                  trailing: Text(ev['timestamp'].toString().substring(11), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
