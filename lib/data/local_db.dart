// Letak file: mobile/lib/data/local_db.dart
// Fungsi: Pengelolaan database lokal SQLite (sqflite) untuk offline cache, antrean donasi offline, nota transparansi, feedback, dan profil terenkripsi AES-256 (PBI-020, PBI-029, PBI-030)

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
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // Tabel Cache Daftar Anak (FR-19, NFR-03)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_children (
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
      CREATE TABLE IF NOT EXISTS cached_donations (
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
      CREATE TABLE IF NOT EXISTS offline_donations_queue (
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
      CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY,
        name TEXT,
        phone_encrypted TEXT,
        email TEXT,
        photo_url TEXT
      )
    ''');

    // Tabel Nota / Bukti Transparansi Keuangan (Revisi Admin)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS receipts (
        id TEXT PRIMARY KEY,
        child_name TEXT,
        title TEXT,
        amount REAL,
        date TEXT,
        receipt_image TEXT,
        description TEXT,
        hash TEXT
      )
    ''');

    // Tabel Feedback / Saran & Kesan Persisten (Revisi Logout Donatur & Admin)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS feedback_entries (
        id TEXT PRIMARY KEY,
        user_email TEXT,
        user_name TEXT,
        rating INTEGER,
        category TEXT,
        message TEXT,
        created_at TEXT
      )
    ''');

    // Tabel Anak Baru yang Diinputkan Admin
    await db.execute('''
      CREATE TABLE IF NOT EXISTS new_children (
        id TEXT PRIMARY KEY,
        name TEXT,
        age INTEGER,
        gender TEXT,
        city TEXT,
        urgent_needs TEXT,
        story TEXT,
        photo TEXT,
        target REAL,
        dream TEXT,
        hobby TEXT,
        created_at TEXT
      )
    ''');
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

  // ==================== OPERASI ANAK BARU DARI ADMIN ====================
  Future<void> insertChild(Map<String, dynamic> child) async {
    final db = await database;
    await db.insert('new_children', {
      'id': child['id']?.toString() ?? 'child_${DateTime.now().millisecondsSinceEpoch}',
      'name': child['name']?.toString() ?? '',
      'age': child['age'] is int ? child['age'] : int.tryParse(child['age']?.toString() ?? '0') ?? 0,
      'gender': child['gender']?.toString() ?? 'Laki-laki',
      'city': child['city']?.toString() ?? 'PeduliAnak Lombok',
      'urgent_needs': child['urgentNeeds']?.toString() ?? child['urgent_needs']?.toString() ?? 'Pendidikan',
      'story': child['story']?.toString() ?? '',
      'photo': child['photo']?.toString() ?? '',
      'target': child['target'] is num ? (child['target'] as num).toDouble() : 500000.0,
      'dream': child['dream']?.toString() ?? '',
      'hobby': child['hobby']?.toString() ?? '',
      'created_at': child['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getNewChildren() async {
    final db = await database;
    final rows = await db.query('new_children', orderBy: 'created_at DESC');
    return rows.map((r) => {
      'id': r['id'],
      'name': r['name'],
      'alias': r['name'],
      'age': r['age'],
      'gender': r['gender'],
      'city': r['city'],
      'orphanage_city': r['city'],
      'orphanage_name': 'Peduli Anak Foundation',
      'urgentNeeds': r['urgent_needs'],
      'need_category': r['urgent_needs'],
      'story': r['story'],
      'story_summary': r['story'],
      'photo': r['photo'],
      'avatar': r['photo'],
      'target': r['target'],
      'dream': r['dream'],
      'hobby': r['hobby'],
    }).toList();
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
    final decryptedPhone = AesHelper.decrypt(row['phone_encrypted']?.toString() ?? '');

    return {
      'id': row['id']?.toString() ?? '',
      'name': row['name']?.toString() ?? '',
      'phone': decryptedPhone,
      'email': row['email']?.toString() ?? '',
      'photo_url': row['photo_url']?.toString() ?? '',
    };
  }

  // ==================== OPERASI NOTA / LAPORAN BELANJA (REVISI ADMIN) ====================
  Future<void> insertReceipt(Map<String, dynamic> receipt) async {
    final db = await database;
    await db.insert('receipts', {
      'id': receipt['id']?.toString() ?? 'rec_${DateTime.now().millisecondsSinceEpoch}',
      'child_name': receipt['childName']?.toString() ?? receipt['child_name']?.toString() ?? '',
      'title': receipt['title']?.toString() ?? '',
      'amount': receipt['amount'] is num ? (receipt['amount'] as num).toDouble() : 0.0,
      'date': receipt['date']?.toString() ?? DateTime.now().toString().split(' ')[0],
      'receipt_image': receipt['receiptImage']?.toString() ?? receipt['receipt_image']?.toString() ?? '',
      'description': receipt['description']?.toString() ?? '',
      'hash': receipt['hash']?.toString() ?? '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getReceipts() async {
    final db = await database;
    final rows = await db.query('receipts', orderBy: 'date DESC');
    return rows.map((r) => {
      'id': r['id'],
      'childName': r['child_name'],
      'title': r['title'],
      'amount': r['amount'],
      'date': r['date'],
      'receiptImage': r['receipt_image'],
      'description': r['description'],
      'hash': r['hash'],
    }).toList();
  }

  // ==================== OPERASI FEEDBACK / SARAN & KESAN (REVISI LOGOUT PERSISTENCE) ====================
  Future<void> insertFeedback(Map<String, dynamic> fb) async {
    final db = await database;
    await db.insert('feedback_entries', {
      'id': fb['id']?.toString() ?? 'fb_${DateTime.now().millisecondsSinceEpoch}',
      'user_email': fb['user_email']?.toString() ?? '',
      'user_name': fb['user_name']?.toString() ?? '',
      'rating': fb['rating'] is int ? fb['rating'] : int.tryParse(fb['rating']?.toString() ?? '5') ?? 5,
      'category': fb['category']?.toString() ?? 'Umum',
      'message': fb['message']?.toString() ?? '',
      'created_at': fb['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllFeedbacks() async {
    final db = await database;
    return await db.query('feedback_entries', orderBy: 'created_at DESC');
  }
}
