// Letak file: mobile/lib/data/local_db.dart
// Fungsi: Pengelolaan database lokal SQLite (sqflite) untuk offline cache, antrean donasi offline, dan penyimpanan data sensitif terenkripsi AES-256 (PBI-020, PBI-029, PBI-030)

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../core/aes_helper.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'asuhkita_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabel Cache Daftar Anak (FR-19, NFR-03)
        await db.execute('''
          CREATE TABLE cached_children (
            id TEXT PRIMARY KEY,
            orphanage_id TEXT,
            alias TEXT,
            age INTEGER,
            need_category TEXT,
            story_summary TEXT,
            avatar TEXT,
            status TEXT,
            orphanage_name TEXT,
            orphanage_city TEXT
          )
        ''');

        // Tabel Cache Riwayat Donasi (FR-19, PBI-029)
        await db.execute('''
          CREATE TABLE cached_donations (
            id TEXT PRIMARY KEY,
            sponsorship_id TEXT,
            child_alias TEXT,
            amount_original REAL,
            currency TEXT,
            rate_used REAL,
            amount_idr REAL,
            created_at TEXT,
            status TEXT
          )
        ''');

        // Tabel Antrean Donasi Offline (FR-20, PBI-030)
        await db.execute('''
          CREATE TABLE offline_donations_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            child_id TEXT,
            package_id TEXT,
            amount_original REAL,
            currency TEXT,
            rate_used REAL,
            amount_idr REAL,
            frequency TEXT,
            created_at TEXT,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        // Tabel Cache Profil Pengguna dengan Nomor HP Terenkripsi AES-256 (FR-11, FR-21)
        await db.execute('''
          CREATE TABLE user_profile (
            id TEXT PRIMARY KEY,
            name TEXT,
            phone_encrypted TEXT,
            email TEXT,
            photo_url TEXT
          )
        ''');
      },
    );
  }

  // ==================== OPERASI CACHE ANAK (PBI-020) ====================
  Future<void> cacheChildren(List<Map<String, dynamic>> childrenList) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('cached_children');
    for (var child in childrenList) {
      batch.insert('cached_children', {
        'id': child['id']?.toString() ?? '',
        'orphanage_id': child['orphanage_id']?.toString() ?? '',
        'alias': child['alias']?.toString() ?? '',
        'age': child['age'] is int ? child['age'] : int.tryParse(child['age']?.toString() ?? '0') ?? 0,
        'need_category': child['need_category']?.toString() ?? '',
        'story_summary': child['story_summary']?.toString() ?? '',
        'avatar': child['avatar']?.toString() ?? '',
        'status': child['status']?.toString() ?? 'Tersedia',
        'orphanage_name': child['orphanage_name']?.toString() ?? '',
        'orphanage_city': child['orphanage_city']?.toString() ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedChildren({String query = '', String category = ''}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (query.isNotEmpty) {
      whereClause += 'alias LIKE ?';
      whereArgs.add('%$query%');
    }

    if (category.isNotEmpty && category != 'Semua') {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'need_category = ?';
      whereArgs.add(category);
    }

    return await db.query(
      'cached_children',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'alias ASC',
    );
  }

  // ==================== OPERASI CACHE RIWAYAT DONASI (PBI-029) ====================
  Future<void> insertDonation(Map<String, dynamic> donation) async {
    final db = await database;
    await db.insert('cached_donations', {
      'id': donation['id']?.toString() ?? 'don_${DateTime.now().millisecondsSinceEpoch}',
      'sponsorship_id': donation['sponsorship_id']?.toString() ?? '',
      'child_alias': donation['child_alias']?.toString() ?? '',
      'amount_original': donation['amount_original'] is num ? (donation['amount_original'] as num).toDouble() : 0.0,
      'currency': donation['currency']?.toString() ?? 'IDR',
      'rate_used': donation['rate_used'] is num ? (donation['rate_used'] as num).toDouble() : 1.0,
      'amount_idr': donation['amount_idr'] is num ? (donation['amount_idr'] as num).toDouble() : 0.0,
      'created_at': donation['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'status': donation['status']?.toString() ?? 'Terverifikasi di Ledger',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCachedDonations() async {
    final db = await database;
    return await db.query('cached_donations', orderBy: 'created_at DESC');
  }

  // ==================== OPERASI ANTREAN OFFLINE DONASI (PBI-030) ====================
  Future<int> queueOfflineDonation({
    required String childId,
    required String packageId,
    required double amountOriginal,
    required String currency,
    required double rateUsed,
    required double amountIdr,
    required String frequency,
  }) async {
    final db = await database;
    return await db.insert('offline_donations_queue', {
      'child_id': childId,
      'package_id': packageId,
      'amount_original': amountOriginal,
      'currency': currency,
      'rate_used': rateUsed,
      'amount_idr': amountIdr,
      'frequency': frequency,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedDonations() async {
    final db = await database;
    return await db.query('offline_donations_queue', where: 'is_synced = 0');
  }

  Future<void> markDonationSynced(int queueId) async {
    final db = await database;
    await db.update(
      'offline_donations_queue',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  // ==================== PROFIL & ENKRIPSI AES-256 (FR-11, FR-21) ====================
  Future<void> saveUserProfile({
    required String id,
    required String name,
    required String plainPhone,
    required String email,
    String? photoUrl,
  }) async {
    final db = await database;
    // Enkripsi nomor HP dengan AES-256 sebelum masuk ke database lokal
    final encryptedPhone = AesHelper.encrypt(plainPhone);

    await db.insert('user_profile', {
      'id': id,
      'name': name,
      'phone_encrypted': encryptedPhone,
      'email': email,
      'photo_url': photoUrl ?? '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>?> getUserProfile(String id) async {
    final db = await database;
    final results = await db.query('user_profile', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;

    final row = results.first;
    // Dekripsi nomor HP dari AES-256
    final decryptedPhone = AesHelper.decrypt(row['phone_encrypted']?.toString() ?? '');

    return {
      'id': row['id']?.toString() ?? '',
      'name': row['name']?.toString() ?? '',
      'phone': decryptedPhone,
      'email': row['email']?.toString() ?? '',
      'photo_url': row['photo_url']?.toString() ?? '',
    };
  }
}
