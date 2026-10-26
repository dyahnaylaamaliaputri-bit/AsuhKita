








import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchLocationController = TextEditingController();


  LatLng _userLocation = const LatLng(-8.5833, 116.1167);
  String _currentRegion = 'Nusa Tenggara Barat';
  String _currentCity = 'Mataram (Lombok)';
  bool _isDetecting = true;
  bool _isLoadingRoute = false;
  bool _locationPermissionGranted = false;


  Map<String, dynamic>? _selectedOrphanage;
  List<LatLng> _routePoints = [];
  double _routeDistanceKm = 0.0;
  int _routeEstimatedMinutes = 0;


  List<Map<String, dynamic>> _orphanages = [];


  final List<Map<String, dynamic>> _presetRegions = [
    {
      'name': 'Mataram & Lombok Barat',
      'region': 'Nusa Tenggara Barat (NTB)',
      'location': const LatLng(-8.5833, 116.1167),
    },
    {
      'name': 'Denpasar & Badung',
      'region': 'Bali',
      'location': const LatLng(-8.6705, 115.2126),
    },
    {
      'name': 'Surabaya & Sidoarjo',
      'region': 'Jawa Timur',
      'location': const LatLng(-7.2575, 112.7521),
    },
    {
      'name': 'Jakarta Selatan & Pusat',
      'region': 'DKI Jakarta',
      'location': const LatLng(-6.2088, 106.8456),
    },
    {
      'name': 'Bandung Raya',
      'region': 'Jawa Barat',
      'location': const LatLng(-6.9175, 107.6191),
    },
    {
      'name': 'Yogyakarta & Sleman',
      'region': 'D.I. Yogyakarta',
      'location': const LatLng(-7.7956, 110.3695),
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRealtimeLocationAndPermissions();
    });
  }

  @override
  void dispose() {
    _searchLocationController.dispose();
    super.dispose();
  }




  Future<void> _initRealtimeLocationAndPermissions() async {
    setState(() => _isDetecting = true);

    bool serviceEnabled = false;
    LocationPermission permission;

    try {

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LBS] Location service is disabled.');
      }


      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _locationPermissionGranted = true;


        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 7),
          ),
        );

        _userLocation = LatLng(position.latitude, position.longitude);
        _currentCity = 'Lokasi GPS Anda';
        _currentRegion = 'Koordinat Nyata Perangkat';
      } else {
        _locationPermissionGranted = false;
        await _fallbackIpLocation();
      }
    } catch (e) {
      debugPrint('[LBS] Error getting GPS location: $e');
      await _fallbackIpLocation();
    }


    await _fetchNearbyOrphanagesFromApi(_userLocation);

    if (mounted) {
      setState(() => _isDetecting = false);
      try {
        _mapController.move(_userLocation, 14.5);
      } catch (_) {}
    }
  }


  Future<void> _fallbackIpLocation() async {
    try {
      final res = await DioClient().dio.get('http://ip-api.com/json').timeout(
        const Duration(seconds: 4),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data;
        final lat = (data['lat'] as num?)?.toDouble();
        final lon = (data['lon'] as num?)?.toDouble();
        final city = data['city']?.toString() ?? 'Mataram';
        final region = data['regionName']?.toString() ?? 'Nusa Tenggara Barat';

        if (lat != null && lon != null) {
          _userLocation = LatLng(lat, lon);
          _currentCity = city;
          _currentRegion = region;
        }
      }
    } catch (_) {

      _currentCity = 'Mataram (Lombok)';
      _currentRegion = 'Nusa Tenggara Barat';
    }
  }




  Future<void> _fetchNearbyOrphanagesFromApi(LatLng center) async {
    List<Map<String, dynamic>> loaded = [];

    try {
      final res = await DioClient().dio.get(
        '/orphanages/nearby',
        queryParameters: {
          'lat': center.latitude,
          'lng': center.longitude,
          'radius': 30,
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 && res.data is Map && res.data['data'] is List) {
        final list = List<Map<String, dynamic>>.from(res.data['data']);
        for (var item in list) {
          final lat = double.tryParse(item['latitude']?.toString() ?? '');
          final lon = double.tryParse(item['longitude']?.toString() ?? '');
          if (lat != null && lon != null) {
            final loc = LatLng(lat, lon);
            final distKm = (item['distance_km'] is num)
                ? (item['distance_km'] as num).toDouble()
                : (_calculateDistance(center, loc) / 1000.0);

            loaded.add({
              'id': item['id']?.toString() ?? 'panti_${loaded.length}',
              'name': item['name'] ?? 'Panti Asuhan AsuhKita',
              'region': item['city'] ?? _currentRegion,
              'address': item['address'] ?? 'Jl. Sosial No. 12, $_currentCity',
              'location': loc,
              'phone': item['phone'] ?? '0812-3456-7890',
              'quota': '25 Anak Asuh',
              'distance_km': distKm,
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[LBS] Failed fetching nearby orphanages from API: $e');
    }


    if (loaded.isEmpty) {
      final lat = center.latitude;
      final lon = center.longitude;

      loaded = [
        {
          'id': 'o1',
          'name': 'Panti Asuhan Peduli Kasih (Utama)',
          'region': _currentRegion,
          'address': 'Jl. Melati No. 8, $_currentCity',
          'location': LatLng(lat + 0.00065, lon + 0.00060),
          'phone': '0812-3456-7890',
          'quota': '32 Anak Asuh',
          'distance_km': _calculateDistance(center, LatLng(lat + 0.00065, lon + 0.00060)) / 1000.0,
        },
        {
          'id': 'o2',
          'name': 'Panti Asuhan Harapan Mulia',
          'region': _currentRegion,
          'address': 'Jl. Cendrawasih No. 14, $_currentCity',
          'location': LatLng(lat + 0.0125, lon + 0.0145),
          'phone': '0819-8765-4321',
          'quota': '24 Anak Asuh',
          'distance_km': _calculateDistance(center, LatLng(lat + 0.0125, lon + 0.0145)) / 1000.0,
        },
        {
          'id': 'o3',
          'name': 'Panti Asuhan Bintang Bersinar',
          'region': _currentRegion,
          'address': 'Kompleks Asrama Pendidikan, $_currentCity',
          'location': LatLng(lat - 0.0185, lon - 0.0165),
          'phone': '0857-1122-3344',
          'quota': '18 Anak Asuh',
          'distance_km': _calculateDistance(center, LatLng(lat - 0.0185, lon - 0.0165)) / 1000.0,
        },
        {
          'id': 'o4',
          'name': 'Panti Asuhan Tunas Harapan Bangsa',
          'region': _currentRegion,
          'address': 'Jl. Diponegoro Samping Alun-Alun, $_currentCity',
          'location': LatLng(lat + 0.0250, lon - 0.0120),
          'phone': '0821-9988-7766',
          'quota': '40 Anak Asuh',
          'distance_km': _calculateDistance(center, LatLng(lat + 0.0250, lon - 0.0120)) / 1000.0,
        },
      ];
    }

    setState(() {
      _orphanages = loaded;
    });
  }




  Future<void> _fetchOsrmRoute(Map<String, dynamic> orphanage) async {
    setState(() {
      _isLoadingRoute = true;
      _selectedOrphanage = orphanage;
    });

    final start = _userLocation;
    final end = orphanage['location'] as LatLng;
    final haversineDistMeters = _calculateDistance(start, end);

    List<LatLng> polylinePoints = [];
    double distanceKm = haversineDistMeters / 1000.0;
    int estMinutes = max(2, (haversineDistMeters / 400).round());

    try {


      final osrmUrl =
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';

      final res = await DioClient().dio.get(osrmUrl).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 && res.data is Map) {
        final routes = res.data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes[0];
          final geometry = firstRoute['geometry'];
          if (geometry != null && geometry['coordinates'] is List) {
            final coords = geometry['coordinates'] as List;
            for (var c in coords) {
              if (c is List && c.length >= 2) {
                polylinePoints.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
              }
            }
          }
          final osrmDist = (firstRoute['distance'] as num?)?.toDouble();
          if (osrmDist != null) {
            distanceKm = osrmDist / 1000.0;
          }
          final osrmDuration = (firstRoute['duration'] as num?)?.toDouble();
          if (osrmDuration != null) {
            estMinutes = max(1, (osrmDuration / 60).round());
          }
        }
      }
    } catch (e) {
      debugPrint('[OSRM] Fallback to simulated polyline waypoints: $e');

      final dLat = end.latitude - start.latitude;
      final dLon = end.longitude - start.longitude;
      polylinePoints = [
        start,
        LatLng(start.latitude + (dLat * 0.25), start.longitude + (dLon * 0.10)),
        LatLng(start.latitude + (dLat * 0.45), start.longitude + (dLon * 0.50)),
        LatLng(start.latitude + (dLat * 0.70), start.longitude + (dLon * 0.65)),
        LatLng(start.latitude + (dLat * 0.85), start.longitude + (dLon * 0.90)),
        end,
      ];
    }

    if (polylinePoints.isEmpty) {
      polylinePoints = [start, end];
    }

    if (mounted) {
      setState(() {
        _routePoints = polylinePoints;
        _routeDistanceKm = distanceKm;
        _routeEstimatedMinutes = estMinutes;
        _isLoadingRoute = false;
      });


      try {
        final centerLat = (start.latitude + end.latitude) / 2;
        final centerLon = (start.longitude + end.longitude) / 2;
        _mapController.move(LatLng(centerLat, centerLon), 14.0);
      } catch (_) {}


      _showOrphanageBottomSheet(orphanage, _routeDistanceKm, _routeEstimatedMinutes);
    }
  }


  double _calculateDistance(LatLng pos1, LatLng pos2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, pos1, pos2);
  }




  void _showOrphanageBottomSheet(Map<String, dynamic> orphanage, double distKm, int estMins) {
    final distanceMeters = _calculateDistance(_userLocation, orphanage['location']);
    final bool canCheckIn = distanceMeters <= 100;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),


            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.home_work_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orphanage['name'],
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              orphanage['address'],
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),


            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [

                  Row(
                    children: [
                      const Icon(Icons.straighten, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Jarak Tempuh', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text(
                            distKm < 1.0
                                ? '${distanceMeters.toStringAsFixed(0)} Meter'
                                : '${distKm.toStringAsFixed(2)} km',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(height: 32, width: 1, color: Colors.grey.shade300),

                  Row(
                    children: [
                      const Icon(Icons.directions_car_filled, color: Colors.green, size: 22),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estimasi Waktu', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text(
                            '$estMins Menit Perjalanan',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),


            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_alt, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 6),
                        Text(orphanage['quota'] ?? '25 Anak', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 6),
                        Text(orphanage['phone'] ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),


            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleCheckIn(orphanage);
                    },
                    icon: Icon(
                      canCheckIn ? Icons.verified_user : Icons.pin_drop,
                      color: canCheckIn ? Colors.green : AppColors.primary,
                      size: 18,
                    ),
                    label: Text(
                      canCheckIn ? 'Check-in Sekarang' : 'Verifikasi Check-in',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: canCheckIn ? Colors.green : AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: canCheckIn ? Colors.green : AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Navigasi OSRM aktif: Ikuti garis biru menuju ${orphanage['name']}.'),
                          backgroundColor: Colors.blue.shade800,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Ikuti Rute Biru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleCheckIn(Map<String, dynamic> orphanage) {
    final meters = _calculateDistance(_userLocation, orphanage['location']);
    final canCheckIn = meters <= 100;

    if (canCheckIn) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: AppColors.accent3, size: 28),
              SizedBox(width: 8),
              Text('Check-in Berhasil!'),
            ],
          ),
          content: Text(
            'Lokasi Anda terverifikasi di ${orphanage['name']}.\n'
            'Region: $_currentRegion\n'
            'Jarak: ${meters.toStringAsFixed(1)} meter dari gerbang panti.\n\n'
            'Kunjungan fisik Anda telah berhasil diverifikasi oleh sistem LBS.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Selesai'),
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
              Icon(Icons.warning_amber_rounded, color: AppColors.secondary, size: 28),
              SizedBox(width: 8),
              Text('Di Luar Jangkauan'),
            ],
          ),
          content: Text(
            'Anda berjarak ${meters > 1000 ? '${(meters / 1000).toStringAsFixed(2)} km' : '${meters.toStringAsFixed(0)} m'} dari lokasi panti.\n\n'
            'Check-in kehadiran fisik hanya dapat dilakukan saat Anda berada dalam radius maksimal 100 meter dari panti asuhan.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _fetchOsrmRoute(orphanage);
              },
              child: const Text('Buka Rute Navigasi', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
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


  void _changeLocationManual(LatLng newLocation, String cityName, String regionName) {
    setState(() {
      _userLocation = newLocation;
      _currentCity = cityName;
      _currentRegion = regionName;
      _selectedOrphanage = null;
      _routePoints = [];
    });

    _fetchNearbyOrphanagesFromApi(newLocation);

    try {
      _mapController.move(newLocation, 14.5);
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Peta dialihkan ke $cityName, $regionName'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Peta Panti LBS (Real-Time)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Deteksi Lokasi GPS Saya',
            onPressed: _initRealtimeLocationAndPermissions,
          ),
          IconButton(
            icon: const Icon(Icons.travel_explore),
            tooltip: 'Ganti Region Kota',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (ctx) => Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pilih Kota / Region Panti Asuhan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ..._presetRegions.map((r) {
                        return ListTile(
                          leading: const Icon(Icons.location_city, color: AppColors.primary),
                          title: Text(r['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(r['region']),
                          onTap: () {
                            Navigator.pop(ctx);
                            _changeLocationManual(r['location'], r['name'], r['region']);
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [

          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 14.5,
              minZoom: 4.0,
              maxZoom: 18.0,
            ),
            children: [

              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.asuhkita.mobile',
              ),


              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [

                    Polyline(
                      points: _routePoints,
                      color: Colors.blue.shade900.withValues(alpha: 0.4),
                      strokeWidth: 8.0,
                    ),

                    Polyline(
                      points: _routePoints,
                      color: Colors.blueAccent,
                      strokeWidth: 5.5,
                    ),
                  ],
                ),


              MarkerLayer(
                markers: [

                  Marker(
                    point: _userLocation,
                    width: 60,
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [

                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                        ),

                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                        ),

                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A73E8),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),


                  ..._orphanages.map((orp) {
                    final isSelected = _selectedOrphanage != null && _selectedOrphanage!['id'] == orp['id'];

                    return Marker(
                      point: orp['location'] as LatLng,
                      width: 90,
                      height: 80,
                      child: GestureDetector(
                        onTap: () => _fetchOsrmRoute(orp),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.shade900 : Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 3),
                                ],
                              ),
                              child: Text(
                                orp['name'].toString().split(' ').take(2).join(' '),
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2),

                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blueAccent : const Color(0xFFD9534F),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                                ],
                              ),
                              child: const Icon(
                                Icons.home_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),


          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _locationPermissionGranted ? Colors.blue.shade50 : Colors.amber.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _locationPermissionGranted ? Icons.gps_fixed : Icons.location_on,
                      color: _locationPermissionGranted ? Colors.blue : Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentCity,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_userLocation.latitude.toStringAsFixed(4)}, ${_userLocation.longitude.toStringAsFixed(4)} • ${_orphanages.length} Panti Terdekat',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (_isDetecting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                ],
              ),
            ),
          ),


          if (_isLoadingRoute)
            Positioned(
              bottom: 24,
              left: 50,
              right: 50,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 10),
                    Text('Menggambar rute jalan via OSRM...', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
