// Letak file: mobile/lib/features/steps_game/steps_and_game_screen.dart
// Fungsi: Deteksi Langkah Sensor Accelerometer (Donasi Langkah) & Mini Game Gyroscope "Tangkap Bintang Harapan" (PBI-051, PBI-053, FR-44, FR-46, FR-47, FR-48)

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepsAndGameScreen extends StatefulWidget {
  const StepsAndGameScreen({super.key});

  @override
  State<StepsAndGameScreen> createState() => _StepsAndGameScreenState();
}

class _StepsAndGameScreenState extends State<StepsAndGameScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ========== STATE SENSOR ACCELEROMETER (DETEKSI LANGKAH) ==========
  static const String _stepsStorageKey = 'asuhkita_daily_steps';
  int _stepCount = 142; // Langkah default
  StreamSubscription? _accelerometerSub;
  DateTime _lastStepTime = DateTime.now();

  // ========== STATE SENSOR GYROSCOPE & ACCELEROMETER TILT (MINI GAME) ==========
  StreamSubscription? _gyroscopeSub;
  StreamSubscription? _gameTiltSub;
  double _basketX = 150.0; // Posisi horizontal keranjang
  double _starX = 120.0;
  double _starY = 0.0;
  int _gameScore = 0;
  bool _isGameRunning = false;
  Timer? _gameLoopTimer;
  double _canvasWidth = 320.0;
  double _canvasHeight = 400.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedSteps();
    _startPedometer();
  }

  Future<void> _loadSavedSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_stepsStorageKey);
      if (saved != null && mounted) {
        setState(() {
          _stepCount = saved;
        });
      }
    } catch (_) {}
  }

  Future<void> _persistSteps(int steps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_stepsStorageKey, steps);
    } catch (_) {}
  }

  @override
  void dispose() {
    _persistSteps(_stepCount);
    _tabController.dispose();
    _accelerometerSub?.cancel();
    _gyroscopeSub?.cancel();
    _gameTiltSub?.cancel();
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
        _persistSteps(_stepCount);
      }
    });
  }

  // 2. Mini Game Gyroscope & Kemiringan "Tangkap Bintang Harapan" (PBI-053, FR-46, FR-47)
  void _startGame() {
    setState(() {
      _isGameRunning = true;
      _gameScore = 0;
      _starY = 0.0;
      _starX = Random().nextDouble() * (_canvasWidth - 80) + 40;
      _basketX = _canvasWidth / 2;
    });

    // 1. Sensor Gyroscope (Kecepatan Rotasi Sudut HP)
    _gyroscopeSub?.cancel();
    _gyroscopeSub = gyroscopeEventStream().listen((e) {
      if (!_isGameRunning) return;
      setState(() {
        _basketX -= e.y * 14.0;
        if (_basketX < 35) _basketX = 35;
        if (_basketX > _canvasWidth - 35) _basketX = _canvasWidth - 35;
      });
    });

    // 2. Sensor Accelerometer Tilt (Sudut Kemiringan Statis Gravitasi HP)
    _gameTiltSub?.cancel();
    _gameTiltSub = accelerometerEventStream().listen((e) {
      if (!_isGameRunning) return;
      setState(() {
        // e.x bernilai negatif saat HP dimiringkan ke kanan, positif saat ke kiri
        _basketX -= e.x * 3.5;
        if (_basketX < 35) _basketX = 35;
        if (_basketX > _canvasWidth - 35) _basketX = _canvasWidth - 35;
      });
    });

    // Game loop 60 FPS (tiap 25 ms)
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (!_isGameRunning) return;

      setState(() {
        _starY += 4.5; // Bintang jatuh ke bawah

        // Cek tabrakan / tangkapan bintang dengan keranjang
        if (_starY >= _canvasHeight - 65 && _starY <= _canvasHeight - 15) {
          if ((_starX - _basketX).abs() < 55) {
            // Berhasil ditangkap!
            _gameScore += 10;
            _starY = 0.0;
            _starX = Random().nextDouble() * (_canvasWidth - 80) + 40;
          }
        }

        // Bintang jatuh terlewat batas bawah
        if (_starY > _canvasHeight) {
          _starY = 0.0;
          _starX = Random().nextDouble() * (_canvasWidth - 80) + 40;
        }
      });
    });
  }

  void _stopGame() {
    _gameLoopTimer?.cancel();
    _gyroscopeSub?.cancel();
    _gameTiltSub?.cancel();
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
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
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
                  onPressed: () async {
                    await _persistSteps(_stepCount);
                    final points = (_stepCount / 20).floor();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Selamat! $_stepCount langkah ($points Poin Kebaikan) berhasil diklaim dan disimpan!'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    }
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
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () async {
                    setState(() {
                      _stepCount = 0;
                    });
                    await _persistSteps(0);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Langkah harian di-reset ke 0 untuk hari baru.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.restart_alt, size: 16, color: Colors.grey),
                  label: const Text('Reset Langkah Hari Baru', style: TextStyle(color: Colors.grey, fontSize: 13)),
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

                // Area Game Canvas dengan CustomPainter & Touch/Tilt Control
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _canvasWidth = constraints.maxWidth;
                      _canvasHeight = constraints.maxHeight;

                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade900,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.teal.shade300, width: 2),
                        ),
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            if (!_isGameRunning) return;
                            setState(() {
                              _basketX += details.delta.dx;
                              if (_basketX < 35) _basketX = 35;
                              if (_basketX > _canvasWidth - 35) _basketX = _canvasWidth - 35;
                            });
                          },
                          onTapDown: (details) {
                            if (!_isGameRunning) return;
                            setState(() {
                              _basketX = details.localPosition.dx;
                              if (_basketX < 35) _basketX = 35;
                              if (_basketX > _canvasWidth - 35) _basketX = _canvasWidth - 35;
                            });
                          },
                          child: CustomPaint(
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                            painter: GameCanvasPainter(
                              basketX: _basketX,
                              starX: _starX,
                              starY: _starY,
                              isRunning: _isGameRunning,
                            ),
                          ),
                        ),
                      );
                    },
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
