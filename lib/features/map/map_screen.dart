// Letak file: mobile/lib/features/map/map_screen.dart
// Fungsi: Layar Peta Panti LBS (Location Based Service), Jarak Haversine, & Validasi Check-In Radius 100 Meter (PBI-043, PBI-044, FR-35, FR-36, FR-37)

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Posisi simulasi pengguna di Yogyakarta (Donatur)
  final LatLng _userLocation = const LatLng(-7.797068, 110.370529);

  // Daftar Panti Asuhan terdaftar
  final List<Map<String, dynamic>> _orphanages = [
    {
      'id': 'o1',
      'name': 'Panti Asuhan Kasih Ibu',
      'address': 'Jl. Kaliurang KM 5, Sleman, D.I. Yogyakarta',
      'location': const LatLng(-7.797200, 110.370800), // ~50 meter (Dalam radius 100m)
      'phone': '0274-889911',
    },
    {
      'id': 'o2',
      'name': 'Panti Asuhan Harapan Mulia',
      'address': 'Jl. Solo KM 9, Sleman, D.I. Yogyakarta',
      'location': const LatLng(-7.782000, 110.420000), // ~6 km (Luar radius 100m)
      'phone': '0274-554433',
    },
  ];

  // Rumus Haversine menghitung jarak dalam meter (Bab 5.7 SRS)
  double _calculateDistance(LatLng pos1, LatLng pos2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, pos1, pos2);
  }

  void _handleCheckIn(Map<String, dynamic> orphanage) {
    final meters = _calculateDistance(_userLocation, orphanage['location']);
    final canCheckIn = meters <= 100; // Radius toleransi check-in 100 meter (FR-37)

    if (canCheckIn) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Check-in Berhasil!'),
            ],
          ),
          content: Text(
            'Lokasi Anda terverifikasi di ${orphanage['name']} (Jarak: ${meters.toStringAsFixed(1)} m).\nKunjungan Anda tercatat dalam sistem.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning, color: Colors.deepOrange),
              SizedBox(width: 8),
              Text('Di Luar Jangkauan'),
            ],
          ),
          content: Text(
            'Anda berjarak ${meters > 1000 ? '${(meters / 1000).toStringAsFixed(2)} km' : '${meters.toStringAsFixed(0)} m'} dari lokasi panti.\nCheck-in hanya dapat dilakukan dalam radius maksimal 100 meter.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Panti Asuhan (LBS)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Peta Interaktif OpenStreetMap (flutter_map) (FR-35)
          Expanded(
            flex: 6,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _userLocation,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.asuhkita.mobile',
                ),
                MarkerLayer(
                  markers: [
                    // Marker Posisi Pengguna (Donatur)
                    Marker(
                      point: _userLocation,
                      width: 50,
                      height: 50,
                      child: Column(
                        children: const [
                          Icon(Icons.person_pin_circle, color: Colors.blueAccent, size: 38),
                          Text('Anda', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, backgroundColor: Colors.white)),
                        ],
                      ),
                    ),
                    // Marker Panti-panti Asuhan
                    ..._orphanages.map((panti) {
                      return Marker(
                        point: panti['location'],
                        width: 50,
                        height: 50,
                        child: const Icon(Icons.location_on, color: Colors.redAccent, size: 40),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),

          // Daftar Panti Terdekat & Tombol Check-in (FR-36, FR-37)
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.white,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _orphanages.length,
                separatorBuilder: (_, _) => const Divider(height: 20),
                itemBuilder: (context, idx) {
                  final panti = _orphanages[idx];
                  final distanceMeters = _calculateDistance(_userLocation, panti['location']);
                  final isNear = distanceMeters <= 100;

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isNear ? AppColors.surfaceLight : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.apartment, color: isNear ? AppColors.primary : Colors.grey),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(panti['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(panti['address'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            Text(
                              distanceMeters > 1000
                                  ? 'Jarak: ${(distanceMeters / 1000).toStringAsFixed(2)} km'
                                  : 'Jarak: ${distanceMeters.toStringAsFixed(0)} m (Sangat Dekat)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isNear ? AppColors.primary : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _handleCheckIn(panti),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isNear ? AppColors.primary : Colors.grey.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(isNear ? 'Check-in' : 'Cek Jarak', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
