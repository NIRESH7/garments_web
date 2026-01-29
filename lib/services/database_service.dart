import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'textile_lot_management.db');
    return await openDatabase(
      path,
      version: 3, // Bumped version
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          // Force recreate all tables for dev consistency
          var tables = [
            'lots',
            'items',
            'parties',
            'item_assignments',
            'inwards',
            'inward_rows',
            'outwards',
            'outward_items',
            'dropdowns',
          ];
          for (var table in tables) {
            await db.execute("DROP TABLE IF EXISTS $table");
          }
          await _createTables(db);
        }
      },
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE dropdowns (
        id TEXT PRIMARY KEY,
        category TEXT,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE lots (
        id TEXT PRIMARY KEY,
        lot_number TEXT,
        party_name TEXT,
        process TEXT,
        remarks TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        item_name TEXT,
        gsm TEXT,
        item_group TEXT,
        size TEXT,
        set_val TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE parties (
        id TEXT PRIMARY KEY,
        name TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE item_assignments (
        id TEXT PRIMARY KEY,
        item_name TEXT,
        size TEXT,
        dia TEXT,
        efficiency TEXT,
        dozen_weight REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE inwards (
        id TEXT PRIMARY KEY,
        lot_number TEXT,
        from_party TEXT,
        process TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE inward_rows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inward_id TEXT,
        dia TEXT,
        colour TEXT,
        roll INTEGER,
        weight REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE outwards (
        id TEXT PRIMARY KEY,
        lot_number TEXT,
        set_no TEXT,
        party_name TEXT,
        dc_number TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE outward_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        outward_id TEXT,
        colour TEXT,
        weight REAL
      )
    ''');
  }
}
