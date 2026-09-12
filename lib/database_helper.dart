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
      version: 1,
      onCreate: (db, version) async {
        // Local Customers Table
        await db.execute('''
          CREATE TABLE customers (
            id TEXT PRIMARY KEY,
            name TEXT,
            phone TEXT,
            wallet_balance REAL
          )
        ''');
        // Local Payments Table with sync tracking
        await db.execute('''
          CREATE TABLE payments (
            id TEXT PRIMARY KEY,
            customer_id TEXT,
            amount REAL,
            collected_at TEXT,
            sync_status TEXT DEFAULT 'pending' 
          )
        ''');
      },
    );
  }

  Future<void> upsertCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    await db.insert('customers', {
      'id': customer['id'],
      'name': customer['name'],
      'phone': customer['phone'] ?? '',
      'wallet_balance': customer['wallet_balance'] == null
          ? 0.0
          : double.parse(customer['wallet_balance'].toString()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getLocalCustomers() async {
    final db = await database;
    return await db.query('customers');
  }

  Future<void> insertPaymentOffline(Map<String, dynamic> payment) async {
    final db = await database;
    await db.insert(
      'payments',
      payment,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedPayments() async {
    final db = await database;
    return await db.query(
      'payments',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
  }

  Future<void> markPaymentAsSynced(String id) async {
    final db = await database;
    await db.update(
      'payments',
      {'sync_status': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
