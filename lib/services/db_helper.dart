import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DBHelper {
  static const _dbName = 'home_inventory.db';
  static const _dbVersion = 6;
  static Database? _database;

  static const tableHouses = 'houses';
  static const tableItems = 'items';
  static const tableMedicines = 'medicines';
  static const tableRoomPhotos = 'room_photos';
  static const tableAppSettings = 'app_settings';
  static const tableDailyReminders = 'daily_reminders';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableHouses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        bedrooms INTEGER,
        bathrooms INTEGER,
        halls INTEGER,
        kitchens INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableItems(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        houseId INTEGER,
        roomName TEXT,
        name TEXT,
        category TEXT,
        location TEXT,
        purchaseDate TEXT,
        expiryDate TEXT,
        imagePath TEXT,
        reminderAdvanceDays INTEGER DEFAULT -1
      )
    ''');

    await _createMedicinesTable(db);
    await _createRoomPhotosTable(db);
    await _createAppSettingsTable(db);
    await _createDailyRemindersTable(db);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMedicinesTable(db);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE $tableMedicines ADD COLUMN reminderAdvance INTEGER DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE $tableItems ADD COLUMN reminderAdvanceDays INTEGER DEFAULT -1');
    }
    if (oldVersion < 5) {
      await _createRoomPhotosTable(db);
      await _createAppSettingsTable(db);
    }
    if (oldVersion < 6) {
      await _createDailyRemindersTable(db);
    }
  }

  static Future<void> _createMedicinesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMedicines(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        category TEXT,
        quantity INTEGER,
        perDayFrequency INTEGER,
        timings TEXT,
        manufacturer TEXT,
        expiryDate TEXT,
        imagePath TEXT,
        lastTaken TEXT,
        reminderAdvance INTEGER DEFAULT 0
      )
    ''');
  }

  static Future<void> _createRoomPhotosTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableRoomPhotos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        houseId INTEGER NOT NULL,
        roomName TEXT NOT NULL,
        photoPath TEXT NOT NULL,
        sortOrder INTEGER DEFAULT 0
      )
    ''');
  }

  static Future<void> _createDailyRemindersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDailyReminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT DEFAULT '',
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        days TEXT NOT NULL DEFAULT 'everyday',
        enabled INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  static Future<void> _createAppSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableAppSettings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  // --- HOUSES ---
  static Future<int> insertHouse(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableHouses, row);
  }

  static Future<List<Map<String, dynamic>>> getHouses() async {
    final db = await database;
    return await db.query(tableHouses);
  }

  static Future<Map<String, dynamic>?> getPrimaryHouse() async {
    final db = await database;
    final rows = await db.query(tableHouses, orderBy: 'id ASC', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  // --- ITEMS ---
  static Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await database;
    return await db.query(tableItems);
  }

  static Future<int> insertItem(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableItems, row);
  }

  static Future<int> updateItem(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      tableItems,
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete(tableItems, where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> getItemsForRoom(int houseId, String roomName) async {
    final db = await database;
    return await db.query(
      tableItems,
      where: 'houseId = ? AND roomName = ?',
      whereArgs: [houseId, roomName],
    );
  }

  static String _sqlLikeContains(String raw) {
    final escaped = raw
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

  static Future<List<Map<String, dynamic>>> searchItemsInHouse(int houseId, String query) async {
    final db = await database;
    return await db.query(
      tableItems,
      where: "houseId = ? AND name LIKE ? ESCAPE '\\'",
      whereArgs: [houseId, _sqlLikeContains(query)],
    );
  }

  // --- ROOM PHOTOS ---
  static Future<int> insertRoomPhoto(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableRoomPhotos, row);
  }

  static Future<void> replaceRoomPhotosForHouse(
    int houseId,
    List<Map<String, dynamic>> photos,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableRoomPhotos, where: 'houseId = ?', whereArgs: [houseId]);
      for (final p in photos) {
        await txn.insert(tableRoomPhotos, {
          'houseId': houseId,
          'roomName': p['roomName'],
          'photoPath': p['photoPath'],
          'sortOrder': p['sortOrder'] ?? 0,
        });
      }
    });
  }

  static Future<List<Map<String, dynamic>>> getRoomPhotosForHouse(int houseId) async {
    final db = await database;
    return await db.query(
      tableRoomPhotos,
      where: 'houseId = ?',
      whereArgs: [houseId],
      orderBy: 'sortOrder ASC, id ASC',
    );
  }

  // --- APP SETTINGS ---
  static Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      tableAppSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(tableAppSettings, where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value']?.toString();
  }

  static Future<bool> isFindMySetupCompleted() async {
    final setting = await getSetting('find_my_setup_completed');
    return setting == 'true';
  }

  static Future<void> setFindMySetupCompleted(bool value) async {
    await setSetting('find_my_setup_completed', value ? 'true' : 'false');
  }

  // --- MEDICINES ---
  static Future<int> insertMedicine(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableMedicines, row);
  }

  static Future<int> updateMedicine(int id, Map<String, dynamic> row) async {
    final db = await database;
    final copy = Map<String, dynamic>.from(row)..remove('id');
    return await db.update(
      tableMedicines,
      copy,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> deleteMedicine(int id) async {
    final db = await database;
    return await db.delete(tableMedicines, where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> getMedicines() async {
    final db = await database;
    return await db.query(tableMedicines, orderBy: 'name COLLATE NOCASE');
  }

  static Future<List<Map<String, dynamic>>> searchMedicines(String query) async {
    final db = await database;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return await getMedicines();
    return await db.query(
      tableMedicines,
      where: "name LIKE ? ESCAPE '\\'",
      whereArgs: [_sqlLikeContains(trimmed)],
    );
  }

  // --- DAILY REMINDERS ---
  static Future<int> insertDailyReminder(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableDailyReminders, row);
  }

  static Future<List<Map<String, dynamic>>> getDailyReminders() async {
    final db = await database;
    return await db.query(tableDailyReminders, orderBy: 'id ASC');
  }

  static Future<int> updateDailyReminder(int id, Map<String, dynamic> row) async {
    final db = await database;
    final copy = Map<String, dynamic>.from(row)..remove('id');
    return await db.update(tableDailyReminders, copy, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteDailyReminder(int id) async {
    final db = await database;
    return await db.delete(tableDailyReminders, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> setDailyReminderEnabled(int id, bool enabled) async {
    final db = await database;
    await db.update(
      tableDailyReminders,
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
