


import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';

class StepsAndGameScreen extends StatefulWidget {
  const StepsAndGameScreen({super.key});

  @override
  State<StepsAndGameScreen> createState() => _StepsAndGameScreenState();
}

class _StepsAndGameScreenState extends State<StepsAndGameScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _getUserEmailKey() {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.userEmail.isNotEmpty) {
        return auth.userEmail.toLowerCase().trim();
      }
    } catch (_) {}
    return 'default';
  }


  static const String _stepsStorageKey = 'asuhkita_daily_steps';
  int _stepCount = 0;
  StreamSubscription? _accelerometerSub;
  DateTime _lastStepTime = DateTime.now();


  StreamSubscription? _gyroscopeSub;
  StreamSubscription? _gameTiltSub;
  double _basketX = 150.0;
  double _starX = 120.0;
  double _starY = 0.0;
  int _gameScore = 0;
  bool _isGameRunning = false;
  Timer? _gameLoopTimer;
  double _canvasWidth = 320.0;
  double _canvasHeight = 400.0;


  int _totalUserPoints = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSavedSteps();
    _loadUserPoints();
    _startPedometer();
  }

  Future<void> _loadUserPoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final emailKey = _getUserEmailKey();
      final points = prefs.getInt('asuhkita_kebaikan_points_$emailKey') ?? 0;
      if (mounted) {
        setState(() {
          _totalUserPoints = points;
        });
      }
    } catch (_) {}
  }


  Future<void> _loadSavedSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final emailKey = _getUserEmailKey();
      final lastDate = prefs.getString('asuhkita_steps_date_$emailKey');

      if (lastDate != today) {

        await prefs.setString('asuhkita_steps_date_$emailKey', today);
        await prefs.setInt('${_stepsStorageKey}_$emailKey', 0);
        if (mounted) {
          setState(() {
            _stepCount = 0;
          });
        }
      } else {

        final saved = prefs.getInt('${_stepsStorageKey}_$emailKey') ?? 0;
        if (mounted) {
          setState(() {
            _stepCount = saved;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _stepCount = 0);
    }
  }

  Future<void> _persistSteps(int steps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final emailKey = _getUserEmailKey();
      await prefs.setString('asuhkita_steps_date_$emailKey', today);
      await prefs.setInt('${_stepsStorageKey}_$emailKey', steps);
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


  void _startPedometer() {
    _accelerometerSub = accelerometerEventStream().listen((e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final now = DateTime.now();

      if (mag > 12.0 && now.difference(_lastStepTime).inMilliseconds > 350) {
        setState(() {
          _stepCount++;
          _lastStepTime = now;
        });
        _persistSteps(_stepCount);
      }
    });
  }


  void _startGame() {
    setState(() {
      _isGameRunning = true;
      _gameScore = 0;
      _starY = 0.0;
      _starX = Random().nextDouble() * (_canvasWidth - 80) + 40;
      _basketX = _canvasWidth / 2;
    });


    _gyroscopeSub?.cancel();
    _gyroscopeSub = gyroscopeEventStream().listen((e) {
      if (!_isGameRunning) return;
      setState(() {
        _basketX -= e.y * 14.0;
        if (_basketX < 35) _basketX = 35;
        if (_basketX > _canvasWidth - 35) _basketX = _canvasWidth - 35;
      });
    });


    _gameTiltSub?.cancel();
    _gameTiltSub = accelerometerEventStream().listen((e) {
      if (!_isGameRunning) return;
      setState(() {
        _basketX -= e.x * 3.5;
        if (_basketX < 35) _basketX = 35;
        if (_basketX > _canvasWidth - 35) _basketX = _canvasWidth - 35;
      });
    });


    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (!_isGameRunning) return;

      setState(() {
        _starY += 4.5;


        if (_starY >= _canvasHeight - 65 && _starY <= _canvasHeight - 15) {
          if ((_starX - _basketX).abs() < 55) {

            _gameScore += 10;
            _starY = 0.0;
            _starX = Random().nextDouble() * (_canvasWidth - 80) + 40;
          }
        }


        if (_starY > _canvasHeight) {
          _starY = 0.0;
          _starX = Random().nextDouble() * (_canvasWidth - 80) + 40;
        }
      });
    });
  }


  Future<void> _stopGame() async {
    _gameLoopTimer?.cancel();
    _gyroscopeSub?.cancel();
    _gameTiltSub?.cancel();
    setState(() {
      _isGameRunning = false;
    });

    final earnedScore = _gameScore;

    if (earnedScore > 0) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final emailKey = _getUserEmailKey();
        final currentPoin = prefs.getInt('asuhkita_kebaikan_points_$emailKey') ?? 0;
        final newTotal = currentPoin + earnedScore;
        await prefs.setInt('asuhkita_kebaikan_points_$emailKey', newTotal);
        await prefs.setInt('asuhkita_game_score_$emailKey', newTotal);
        await prefs.setInt('asuhkita_kebaikan_points', newTotal);
        await prefs.setInt('asuhkita_game_score', newTotal);
        _loadUserPoints();
      } catch (_) {}
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.stars, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text('Permainan Selesai!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.military_tech, size: 50, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                '+$earnedScore Poin Kebaikan!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Poin mini game Anda langsung tersimpan dan meningkatkan Peringkat Donatur (Ranking Tier)!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('OK, Mantap!'),
            ),
          ],
        ),
      );
    }
  }



  Map<String, dynamic> _getTierInfo(int points) {
    if (points >= 10000) {
      return {
        'title': 'Pahlawan Kebaikan Utama 🏆',
        'level': 5,
        'badgeColor': const Color(0xFFD32F2F),
        'nextThreshold': 10000,
        'progress': 1.0,
        'desc': 'Tingkat tertinggi! Anda adalah pilar kebaikan bagi masa depan anak asuh.',
      };
    } else if (points >= 5000) {
      return {
        'title': 'Duta Asuh Mulia 💎',
        'level': 4,
        'badgeColor': const Color(0xFF1976D2),
        'nextThreshold': 10000,
        'progress': points / 10000,
        'desc': 'Luar biasa! Menginspirasi donatur lain dengan kontribusi nyata.',
      };
    } else if (points >= 3000) {
      return {
        'title': 'Pejuang Kebaikan 🌟',
        'level': 3,
        'badgeColor': const Color(0xFFF57C00),
        'nextThreshold': 5000,
        'progress': points / 5000,
        'desc': 'Sangat aktif berbagi kebaikan dan mengumpulkan langkah harian.',
      };
    } else if (points >= 1000) {
      return {
        'title': 'Sahabat Peduli ⭐',
        'level': 2,
        'badgeColor': const Color(0xFF00796B),
        'nextThreshold': 3000,
        'progress': points / 3000,
        'desc': 'Konsisten mendampingi dan mendukung kegiatan anak panti.',
      };
    } else {
      return {
        'title': 'Pemula Berbagi 🌱',
        'level': 1,
        'badgeColor': const Color(0xFF689F38),
        'nextThreshold': 1000,
        'progress': points / 1000,
        'desc': 'Awal dari langkah mulia Anda untuk mendampingi masa depan anak bangsa.',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = _getTierInfo(_totalUserPoints);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gamifikasi & Ranking Peduli'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent2,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.directions_walk), text: 'Langkah'),
            Tab(icon: Icon(Icons.sports_esports), text: 'Mini Game'),
            Tab(icon: Icon(Icons.stars), text: 'Poin & Level'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [

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
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.directions_walk, size: 70, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Deteksi Sensor Accelerometer',
                          style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_stepCount',
                          style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: AppColors.primary),
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
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
                    final points = (_stepCount / 20).floor();
                    if (points <= 0) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ayo berjalan minimal 20 langkah dulu untuk mengklaim 1 Poin Kebaikan!'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                      return;
                    }

                    final claimedSteps = points * 20;
                    final remainingSteps = _stepCount - claimedSteps;

                    try {
                      final prefs = await SharedPreferences.getInstance();
                      final emailKey = _getUserEmailKey();
                      final currentPoin = prefs.getInt('asuhkita_kebaikan_points_$emailKey') ?? 0;
                      final newTotalPoin = currentPoin + points;
                      await prefs.setInt('asuhkita_kebaikan_points_$emailKey', newTotalPoin);
                      await prefs.setInt('asuhkita_kebaikan_points', newTotalPoin);

                      setState(() {
                        _stepCount = remainingSteps;
                        _totalUserPoints = newTotalPoin;
                      });
                      await _persistSteps(remainingSteps);

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '🎉 Sukses! $claimedSteps langkah berhasil diklaim menjadi $points Poin Kebaikan! Total Poin Anda: $newTotalPoin Poin.',
                          ),
                          backgroundColor: AppColors.primary,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal menyimpan poin: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text('Klaim & Sumbangkan Poin Langkah'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        setState(() {
                          _stepCount += 100;
                        });
                        await _persistSteps(_stepCount);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('+100 langkah simulasi berhasil ditambahkan. Silakan klik Klaim!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                      label: const Text('+100 Langkah (Demo)', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        setState(() {
                          _stepCount = 0;
                        });
                        await _persistSteps(0);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Langkah harian di-reset ke 0 untuk hari baru.'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(Icons.restart_alt, size: 16, color: Colors.grey),
                      label: const Text('Reset', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),


          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Skor: $_gameScore', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ElevatedButton(
                      onPressed: _isGameRunning ? _stopGame : _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isGameRunning ? Colors.redAccent : AppColors.primary,
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


                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _canvasWidth = constraints.maxWidth;
                      _canvasHeight = constraints.maxHeight;

                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF14241E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
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


          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'LEVEL ${tier['level']}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.stars, color: Colors.amberAccent, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '$_totalUserPoints Poin',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tier['title'],
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tier['desc'],
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (tier['progress'] as double).clamp(0.0, 1.0),
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent2),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_totalUserPoints} / ${tier['nextThreshold']} Poin menuju tier berikutnya',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const SizedBox(height: 20),


                const Row(
                  children: [
                    Icon(Icons.workspace_premium, color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Tingkat & Keistimewaan Level Donatur',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tingkatkan level kebaikan Anda dengan konsisten berjalan kaki dan bermain mini game peduli anak.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),

                _buildLevelTierCard(
                  level: 1,
                  title: 'Pemula Berbagi 🌱',
                  pointRange: '0 - 999 Poin',
                  desc: 'Awal mulia mendampingi anak asuh. Akses katalog anak & chat Ruang Kasih.',
                  color: const Color(0xFF689F38),
                  isCurrent: tier['level'] == 1,
                ),
                const SizedBox(height: 10),
                _buildLevelTierCard(
                  level: 2,
                  title: 'Sahabat Peduli ⭐',
                  pointRange: '1.000 - 2.999 Poin',
                  desc: 'Akses panggilan video call inspirasi bersama anak asuh secara berkala.',
                  color: const Color(0xFF00796B),
                  isCurrent: tier['level'] == 2,
                ),
                const SizedBox(height: 10),
                _buildLevelTierCard(
                  level: 3,
                  title: 'Pejuang Kebaikan 🌟',
                  pointRange: '3.000 - 4.999 Poin',
                  desc: 'Sertifikat digital resmi penghargaan donatur dan badge perak profil.',
                  color: const Color(0xFFF57C00),
                  isCurrent: tier['level'] == 3,
                ),
                const SizedBox(height: 10),
                _buildLevelTierCard(
                  level: 4,
                  title: 'Duta Asuh Mulia 💎',
                  pointRange: '5.000 - 9.999 Poin',
                  desc: 'Laporan perkembangan akademik eksklusif dari wali panti dan badge emas.',
                  color: const Color(0xFF1976D2),
                  isCurrent: tier['level'] == 4,
                ),
                const SizedBox(height: 10),
                _buildLevelTierCard(
                  level: 5,
                  title: 'Pahlawan Kebaikan Utama 🏆',
                  pointRange: '10.000+ Poin',
                  desc: 'Tingkat tertinggi! Piagam pahlawan kebaikan dan undangan temu fisik panti.',
                  color: const Color(0xFFD32F2F),
                  isCurrent: tier['level'] == 5,
                ),

                const SizedBox(height: 20),


                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Cara Mengumpulkan Poin Kebaikan',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Berjalan Kaki (Sensor Accelerometer): Setiap 100 langkah bernilai 1 Poin Kebaikan.\n'
                        '• Mini Game Gyroscope: Setiap bintang yang berhasil ditangkap menghasilkan 5 Poin Kebaikan.\n'
                        '• Berdonasi Rutin: Setiap kali Anda menyalurkan donasi untuk anak asuh, poin Anda otomatis bertambah.',
                        style: TextStyle(fontSize: 12, height: 1.5, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelTierCard({
    required int level,
    required String title,
    required String pointRange,
    required String desc,
    required Color color,
    required bool isCurrent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent ? color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? color : Colors.grey.shade200,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              'L$level',
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isCurrent ? color : AppColors.textPrimary,
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Level Anda', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  pointRange,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


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


    final starPaint = Paint()..color = Colors.amber;
    canvas.drawCircle(Offset(starX, starY), 14, starPaint);

    final glowPaint = Paint()
      ..color = Colors.yellowAccent.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(starX, starY), 18, glowPaint);


    final basketPaint = Paint()..color = AppColors.accent1;
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
