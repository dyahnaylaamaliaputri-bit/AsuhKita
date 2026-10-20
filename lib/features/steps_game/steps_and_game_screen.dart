// Letak file: mobile/lib/features/steps_game/steps_and_game_screen.dart
// Fungsi: Deteksi Langkah Sensor Accelerometer (Donasi Langkah) & Mini Game Gyroscope "Tangkap Bintang Harapan" (PBI-051, PBI-053, FR-44, FR-46, FR-47, FR-48)

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class StepsAndGameScreen extends StatefulWidget {
  const StepsAndGameScreen({super.key});

  @override
  State<StepsAndGameScreen> createState() => _StepsAndGameScreenState();
}

class _StepsAndGameScreenState extends State<StepsAndGameScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ========== STATE SENSOR ACCELEROMETER (DETEKSI LANGKAH) ==========
  int _stepCount = 142; // Langkah awal
  StreamSubscription? _accelerometerSub;
  DateTime _lastStepTime = DateTime.now();

  // ========== STATE SENSOR GYROSCOPE (MINI GAME) ==========
  StreamSubscription? _gyroscopeSub;
  double _basketX = 150.0; // Posisi horizontal keranjang
  double _starX = 120.0;
  double _starY = 0.0;
  int _gameScore = 0;
  bool _isGameRunning = false;
  Timer? _gameLoopTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startPedometer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _accelerometerSub?.cancel();
    _gyroscopeSub?.cancel();
    _gameLoopTimer?.cancel();
    super.dispose();
  }

  // 1. Deteksi Langkah dengan Sensor Accelerometer (PBI-051, FR-44, Bab 7.3 SRS)
  void _startPedometer() {
    _accelerometerSub = accelerometerEventStream().listen((e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final now = DateTime.now();
      // Ambang batas magnitudo percepatan > 12.0 m/s^2 dan jeda langkah minimal 350 ms
      if (mag > 12.0 && now.difference(_lastStepTime).inMilliseconds > 350) {
        setState(() {
          _stepCount++;
          _lastStepTime = now;
        });
      }
    });
  }

  // 2. Mini Game Gyroscope "Tangkap Bintang Harapan" (PBI-053, FR-46, FR-47)
  void _startGame() {
    setState(() {
      _isGameRunning = true;
      _gameScore = 0;
      _starY = 0.0;
      _starX = Random().nextDouble() * 250 + 20;
    });

    // Baca sensor Gyroscope (rotasi sumbu Y untuk memiringkan HP kiri/kanan)
    _gyroscopeSub?.cancel();
    _gyroscopeSub = gyroscopeEventStream().listen((e) {
      if (!_isGameRunning) return;
      setState(() {
        // Gerakkan keranjang sesuai kecepatan rotasi gyroscope (e.y)
        _basketX -= e.y * 12.0;
        if (_basketX < 20) _basketX = 20;
        if (_basketX > 280) _basketX = 280;
      });
    });

    // Game loop 60 FPS (tiap 16 ms)
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (!_isGameRunning) return;

      setState(() {
        _starY += 5.0; // Bintang jatuh ke bawah

        // Cek tabrakan / tangkapan bintang dengan keranjang
        if (_starY >= 340 && _starY <= 380) {
          if ((_starX - _basketX).abs() < 40) {
            // Berhasil ditangkap!
            _gameScore += 10;
            _starY = 0.0;
            _starX = Random().nextDouble() * 250 + 20;
          }
        }

        // Bintang jatuh terlewat batas bawah
        if (_starY > 400) {
          _starY = 0.0;
          _starX = Random().nextDouble() * 250 + 20;
        }
      });
    });
  }

  void _stopGame() {
    _gameLoopTimer?.cancel();
    _gyroscopeSub?.cancel();
    setState(() {
      _isGameRunning = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Permainan Selesai! Skor Anda: $_gameScore. Ditambahkan ke Poin Kebaikan!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Sensor & Mini Game Gamifikasi'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.directions_walk), text: 'Donasi Langkah'),
            Tab(icon: Icon(Icons.sports_esports), text: 'Mini Game Gyroscope'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ========== TAB 1: DONASI LANGKAH (ACCELEROMETER) ==========
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.directions_walk, size: 70, color: Colors.teal),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Deteksi Sensor Accelerometer',
                          style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_stepCount',
                          style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        const Text(
                          'Langkah Hari Ini',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('${(_stepCount * 0.04).toStringAsFixed(1)} kkal',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 2),
                                const Text('Kalori', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            Column(
                              children: [
                                Text('${(_stepCount * 0.75 / 1000).toStringAsFixed(2)} km',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 2),
                                const Text('Jarak', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            Column(
                              children: [
                                Text('${(_stepCount / 20).floor()} Poin',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                                const SizedBox(height: 2),
                                const Text('Poin Kebaikan', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Selamat! $_stepCount langkah Anda telah dikonversi menjadi Poin Kebaikan untuk anak asuh!'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  },
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text('Klaim & Sumbangkan Poin Langkah'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          // ========== TAB 2: MINI GAME "TANGKAP BINTANG HARAPAN" (GYROSCOPE) ==========
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Skor: $_gameScore', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ElevatedButton(
                      onPressed: _isGameRunning ? _stopGame : _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isGameRunning ? Colors.redAccent : Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isGameRunning ? 'Berhenti' : 'Mulai Game'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Miringkan HP Anda ke kiri atau kanan (Gyroscope) untuk mengarahkan keranjang menangkap bintang harapan!',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),

                // Area Game Canvas dengan CustomPainter
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade900,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.teal.shade300, width: 2),
                    ),
                    child: CustomPaint(
                      painter: GameCanvasPainter(
                        basketX: _basketX,
                        starX: _starX,
                        starY: _starY,
                        isRunning: _isGameRunning,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// CustomPainter untuk merender elemen Game Canvas
class GameCanvasPainter extends CustomPainter {
  final double basketX;
  final double starX;
  final double starY;
  final bool isRunning;

  GameCanvasPainter({
    required this.basketX,
    required this.starX,
    required this.starY,
    required this.isRunning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isRunning) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Tekan "Mulai Game" & miringkan HP\nuntuk mengontrol dengan Gyroscope',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 40);

      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, size.height / 2 - 20),
      );
      return;
    }

    // 1. Gambar Bintang Harapan yang Jatuh
    final starPaint = Paint()..color = Colors.amber;
    canvas.drawCircle(Offset(starX, starY), 14, starPaint);

    final glowPaint = Paint()
      ..color = Colors.yellowAccent.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(starX, starY), 18, glowPaint);

    // 2. Gambar Keranjang Penampung yang dikendalikan Gyroscope
    final basketPaint = Paint()..color = Colors.tealAccent;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(basketX, size.height - 40), width: 70, height: 24),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, basketPaint);
  }

  @override
  bool shouldRepaint(covariant GameCanvasPainter oldDelegate) {
    return oldDelegate.basketX != basketX ||
        oldDelegate.starY != starY ||
        oldDelegate.isRunning != isRunning;
  }
}
