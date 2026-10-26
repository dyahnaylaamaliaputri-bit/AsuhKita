


import 'dart:convert';
import 'package:crypto/crypto.dart';
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

    final db = await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedDefaultAuthUsers(db);
        await clearDummyChildren(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
        await _seedDefaultAuthUsers(db);
        await clearDummyChildren(db);
      },
    );
    await clearDummyChildren(db);
    return db;
  }

  Future<void> _createTables(Database db) async {

    await db.execute('''
      CREATE TABLE IF NOT EXISTS auth_users (
        email TEXT PRIMARY KEY,
        password_hash TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        phone TEXT,
        created_at TEXT
      )
    ''');


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
        status TEXT,
        donor_name TEXT,
        donor_email TEXT,
        need_category TEXT
      )
    ''');


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


    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY,
        name TEXT,
        phone_encrypted TEXT,
        email TEXT,
        photo_url TEXT
      )
    ''');


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
        created_at TEXT,
        category_budgets TEXT
      )
    ''');


    try {
      await db.execute('ALTER TABLE new_children ADD COLUMN category_budgets TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_donations ADD COLUMN donor_name TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_donations ADD COLUMN need_category TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_donations ADD COLUMN donor_email TEXT');
    } catch (_) {}


    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        child_alias TEXT NOT NULL,
        sender TEXT NOT NULL,
        text TEXT,
        type TEXT DEFAULT 'text',
        file_url TEXT,
        time TEXT,
        created_at TEXT
      )
    ''');
  }


  static String hashPassword(String password) {
    const salt = 'asuhkita_secure_salt_2026_xyz';
    final bytes = utf8.encode('$salt$password');
    return sha256.convert(bytes).toString();
  }

  Future<void> _seedDefaultAuthUsers(Database db) async {

    await db.insert(
      'auth_users',
      {
        'email': 'donatur@asuhkita.id',
        'password_hash': hashPassword('donatur123'),
        'name': 'Donatur Asuh',
        'role': 'donatur',
        'phone': '081234567890',
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );


    await db.insert(
      'auth_users',
      {
        'email': 'admin@asuhkita.id',
        'password_hash': hashPassword('admin123!'),
        'name': 'Admin Pengurus Panti',
        'role': 'admin_panti',
        'phone': '081987654321',
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
  Future<void> clearDummyChildren([Database? targetDb]) async {
    final db = targetDb ?? await database;
    await db.delete('cached_children', where: "id LIKE 'child_dummy_%'");
    await db.delete('new_children', where: "id LIKE 'child_dummy_%'");
    const dummyNames = [
      'Arfa Pratama', 'Ayra Humaira', 'Bintang Ramadhan', 'Citra Kirana', 'Dimas Anggara',
      'Elsa Safitri', 'Fahri Ramdani', 'Gita Gutawa', 'Hafiz Al-Fatih', 'Intan Permata',
      'Joko Susilo', 'Khadijah Az-Zahra', 'Luki Hermawan', 'Manda Cantika', 'Noval Kurniawan',
      'Olivia Zahrani', 'Putra Perkasa', 'Qiana Azzahra', 'Rafi Ahmad Fauzi', 'Siti Nurhaliza'
    ];
    for (var name in dummyNames) {
      await db.delete('cached_children', where: 'alias = ?', whereArgs: [name]);
      await db.delete('new_children', where: 'name = ?', whereArgs: [name]);
    }
  }

  Future<void> seed20DummyChildren([Database? targetDb]) async {

    await clearDummyChildren(targetDb);
  }

  Future<void> saveAuthUser({
    required String email,
    required String password,
    required String name,
    required String role,
    String phone = '',
  }) async {
    final db = await database;
    final cleanEmail = email.toLowerCase().trim();
    await db.insert(
      'auth_users',
      {
        'email': cleanEmail,
        'password_hash': hashPassword(password),
        'name': name.trim(),
        'role': role,
        'phone': phone.trim(),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> verifyAuthUser({
    required String email,
    required String password,
  }) async {
    final db = await database;
    final cleanEmail = email.toLowerCase().trim();
    final rows = await db.query(
      'auth_users',
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final user = rows.first;
    final storedHash = user['password_hash']?.toString() ?? '';
    final inputHash = hashPassword(password);

    if (storedHash == inputHash) {
      return {
        'id': 'usr_${user['email'].hashCode.abs()}',
        'name': user['name']?.toString() ?? cleanEmail.split('@').first,
        'email': cleanEmail,
        'role': user['role']?.toString() ?? (cleanEmail.contains('admin') ? 'admin_panti' : 'donatur'),
        'phone': user['phone']?.toString() ?? '',
      };
    }
    return null;
  }

  Future<bool> isEmailRegistered(String email) async {
    final db = await database;
    final cleanEmail = email.toLowerCase().trim();
    final rows = await db.query(
      'auth_users',
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );
    return rows.isNotEmpty;
  }


  Future<void> cacheChildren(List<Map<String, dynamic>> childrenList) async {
    if (childrenList.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    batch.delete('cached_children');
    batch.delete('new_children');
    for (var child in childrenList) {
      batch.insert('cached_children', {
        'id': child['id']?.toString() ?? '',
        'orphanage_id': child['orphanage_id']?.toString() ?? '',
        'alias': child['alias']?.toString() ?? child['name']?.toString() ?? '',
        'age': child['age'] is int ? child['age'] : int.tryParse(child['age']?.toString() ?? '0') ?? 0,
        'need_category': child['need_category']?.toString() ?? child['urgentNeeds']?.toString() ?? '',
        'story_summary': child['story_summary']?.toString() ?? child['story']?.toString() ?? '',
        'avatar': child['avatar']?.toString() ?? child['photo']?.toString() ?? '',
        'status': child['status']?.toString() ?? 'Tersedia',
        'orphanage_name': child['orphanage_name']?.toString() ?? '',
        'orphanage_city': child['orphanage_city']?.toString() ?? child['city']?.toString() ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearAllChildrenCache() async {
    final db = await database;
    await db.delete('cached_children');
    await db.delete('new_children');
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
      whereClause += 'need_category LIKE ?';
      whereArgs.add('%$category%');
    }

    return await db.query(
      'cached_children',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'alias ASC',
    );
  }


  Future<void> insertChild(Map<String, dynamic> child) async {
    final db = await database;
    await db.insert('new_children', {
      'id': child['id']?.toString() ?? 'child_${DateTime.now().millisecondsSinceEpoch}',
      'name': child['name']?.toString() ?? child['alias']?.toString() ?? '',
      'age': child['age'] is int ? child['age'] : int.tryParse(child['age']?.toString() ?? '0') ?? 0,
      'gender': child['gender']?.toString() ?? 'Laki-laki',
      'city': child['city']?.toString() ?? child['orphanage_city']?.toString() ?? 'PeduliAnak Lombok',
      'urgent_needs': child['urgentNeeds']?.toString() ?? child['urgent_needs']?.toString() ?? child['need_category']?.toString() ?? 'Pendidikan',
      'story': child['story']?.toString() ?? child['story_summary']?.toString() ?? '',
      'photo': child['photo']?.toString() ?? child['avatar']?.toString() ?? '',
      'target': child['target'] is num ? (child['target'] as num).toDouble() : 500000.0,
      'dream': child['dream']?.toString() ?? '',
      'hobby': child['hobby']?.toString() ?? '',
      'created_at': child['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      'category_budgets': child['category_budgets']?.toString() ?? child['categoryBudgets']?.toString() ?? '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);


    try {
      await db.insert('cached_children', {
        'id': child['id']?.toString() ?? 'child_${DateTime.now().millisecondsSinceEpoch}',
        'orphanage_id': 'panti_peduli_anak',
        'alias': child['name']?.toString() ?? child['alias']?.toString() ?? '',
        'age': child['age'] is int ? child['age'] : int.tryParse(child['age']?.toString() ?? '0') ?? 0,
        'need_category': child['urgentNeeds']?.toString() ?? child['urgent_needs']?.toString() ?? child['need_category']?.toString() ?? 'Pendidikan',
        'story_summary': child['story']?.toString() ?? child['story_summary']?.toString() ?? '',
        'avatar': child['photo']?.toString() ?? child['avatar']?.toString() ?? '',
        'status': 'Tersedia',
        'orphanage_name': 'Peduli Anak Foundation',
        'orphanage_city': child['city']?.toString() ?? child['orphanage_city']?.toString() ?? 'PeduliAnak Lombok',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<void> updateChild(Map<String, dynamic> child) async {
    final db = await database;
    final childId = child['id']?.toString() ?? '';
    final name = child['name']?.toString() ?? child['alias']?.toString() ?? '';

    await db.update('new_children', {
      'name': name,
      'age': child['age'] is int ? child['age'] : int.tryParse(child['age']?.toString() ?? '0') ?? 0,
      'gender': child['gender']?.toString() ?? 'Laki-laki',
      'city': child['city']?.toString() ?? child['orphanage_city']?.toString() ?? 'PeduliAnak Lombok',
      'urgent_needs': child['urgentNeeds']?.toString() ?? child['urgent_needs']?.toString() ?? child['need_category']?.toString() ?? 'Pendidikan',
      'story': child['story']?.toString() ?? child['story_summary']?.toString() ?? '',
      'photo': child['photo']?.toString() ?? child['avatar']?.toString() ?? '',
      'target': child['target'] is num ? (child['target'] as num).toDouble() : 500000.0,
      'dream': child['dream']?.toString() ?? '',
      'hobby': child['hobby']?.toString() ?? '',
      'category_budgets': child['category_budgets']?.toString() ?? child['categoryBudgets']?.toString() ?? '',
    }, where: 'id = ? OR name = ?', whereArgs: [childId, name]);


    await db.update('cached_children', {
      'alias': name,
      'age': child['age'] is int ? child['age'] : int.tryParse(child['age']?.toString() ?? '0') ?? 0,
      'need_category': child['urgentNeeds']?.toString() ?? child['urgent_needs']?.toString() ?? child['need_category']?.toString() ?? 'Pendidikan',
      'story_summary': child['story']?.toString() ?? child['story_summary']?.toString() ?? '',
      'avatar': child['photo']?.toString() ?? child['avatar']?.toString() ?? '',
      'orphanage_city': child['city']?.toString() ?? child['orphanage_city']?.toString() ?? 'PeduliAnak Lombok',
    }, where: 'id = ? OR alias = ?', whereArgs: [childId, name]);
  }

  Future<void> deleteChild(String childId, [String? childName]) async {
    final db = await database;
    final name = childName ?? childId;
    await db.delete('new_children', where: 'id = ? OR name = ?', whereArgs: [childId, name]);
    await db.delete('cached_children', where: 'id = ? OR alias = ?', whereArgs: [childId, name]);
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
      'category_budgets': r['category_budgets'],
      'categoryBudgets': r['category_budgets'],
    }).toList();
  }


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
      'donor_name': donation['donor_name']?.toString() ?? '',
      'donor_email': donation['donor_email']?.toString() ?? '',
      'need_category': donation['need_category']?.toString() ?? '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCachedDonations() async {
    final db = await database;
    return await db.query('cached_donations', orderBy: 'created_at DESC');
  }


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


  Future<void> insertChatMessage({
    required String childAlias,
    required String sender,
    required String text,
    String type = 'text',
    String fileUrl = '',
    String? time,
  }) async {
    final db = await database;
    final now = DateTime.now();
    await db.insert('chat_messages', {
      'child_alias': childAlias.trim(),
      'sender': sender,
      'text': text,
      'type': type,
      'file_url': fileUrl,
      'time': time ?? '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      'created_at': now.toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getChatMessages(String childAlias) async {
    final db = await database;
    final clean = childAlias.trim().toLowerCase();
    return await db.query(
      'chat_messages',
      where: 'LOWER(TRIM(child_alias)) = ?',
      whereArgs: [clean],
      orderBy: 'id ASC',
    );
  }

  Future<Map<String, dynamic>?> getLastChatMessage(String childAlias) async {
    final db = await database;
    final clean = childAlias.trim().toLowerCase();
    final rows = await db.query(
      'chat_messages',
      where: 'LOWER(TRIM(child_alias)) = ?',
      whereArgs: [clean],
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<bool> hasAnyChatMessages() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM chat_messages');
    final count = Sqflite.firstIntValue(res) ?? 0;
    return count > 0;
  }
}
