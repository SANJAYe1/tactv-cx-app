import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDb();
    return _database!;
  }

  Future<Database> initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tactv_offline.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE customers (
            id TEXT PRIMARY KEY,
            name TEXT,
            phone TEXT,
            package_tier TEXT, 
            installation_fee REAL,
            stb_mac_address TEXT,
            wallet_balance REAL,
            sync_status TEXT DEFAULT 'pending',
            updated_at TEXT
          )
        ''');
        
        await db.execute('''
          CREATE TABLE payments (
            id TEXT PRIMARY KEY,
            customer_id TEXT,
            amount REAL,
            collected_at TEXT,
            sync_status TEXT DEFAULT 'pending'
          )
        ''');

        await db.execute('''
          CREATE TABLE stb_inventory (
            mac_address TEXT PRIMARY KEY,
            status TEXT, 
            assigned_to TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE service_tickets (
            id TEXT PRIMARY KEY,
            customer_id TEXT,
            issue_type TEXT,
            status TEXT DEFAULT 'open',
            created_at TEXT,
            sync_status TEXT DEFAULT 'pending'
          )
        ''');
      },
    );
  }

  // Generic methods for two-way sync
  Future<List<Map<String, dynamic>>> getUnsynced(String table) async {
    final db = await database;
    return await db.query(table, where: 'sync_status = ?', whereArgs: ['pending']);
  }

  Future<void> markAsSynced(String table, String id) async {
    final db = await database;
    await db.update(table, {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertCloudData(String table, Map<String, dynamic> data, String idColumn) async {
    final db = await database;
    data['sync_status'] = 'synced'; // Data from cloud is already synced
    await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}