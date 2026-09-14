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
      await db.execute('''
        CREATE TABLE areas (
          id TEXT PRIMARY KEY,
          name TEXT,
          pincode TEXT,
          sync_status TEXT DEFAULT 'synced'
        )
      ''');

      await db.execute('''
        CREATE TABLE packages (
          id TEXT PRIMARY KEY,
          name TEXT,
          monthly_price REAL,
          sync_status TEXT DEFAULT 'synced'
        )
      ''');

      await db.execute('''
        CREATE TABLE customers (
          id TEXT PRIMARY KEY,
          area_id TEXT,
          name TEXT,
          phone TEXT,
          wallet_balance REAL DEFAULT 0.0,
          sync_status TEXT DEFAULT 'pending',
          updated_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE stbs (
          box_id TEXT PRIMARY KEY,
          customer_id TEXT,
          package_id TEXT,
          status TEXT DEFAULT 'active',
          installation_date TEXT,
          sync_status TEXT DEFAULT 'pending'
        )
      ''');

      await db.execute('''
        CREATE TABLE payments (
          id TEXT PRIMARY KEY,
          customer_id TEXT,
          amount REAL,
          collection_type TEXT,
          collected_at TEXT,
          sync_status TEXT DEFAULT 'pending'
        )
      ''');
    },
  );
}

  // Generic methods for two-way sync
  Future<List<Map<String, dynamic>>> getUnsynced(String table) async {
    final db = await database;
    return await db.query(
      table,
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
  }

  Future<List<Map<String, dynamic>>> getLocalCustomers() async {
    final db = await database;
    return await db.query('customers');
  }

  Future<void> upsertCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    await db.insert(
      'customers',
      customer,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertPaymentOffline(Map<String, dynamic> payment) async {
    final db = await database;
    await db.insert('payments', payment);
  }

  // --- Relational Queries ---

  Future<List<Map<String, dynamic>>> getAreas() async {
    final db = await database;
    // Get areas with a count of active customers in each
    return await db.rawQuery('''
      SELECT a.id, a.name, a.pincode, COUNT(c.id) as customer_count
      FROM areas a
      LEFT JOIN customers c ON a.id = c.area_id
      GROUP BY a.id
    ''');
  }

  Future<List<Map<String, dynamic>>> getCustomersByArea(String areaId) async {
    final db = await database;
    // Get customers and calculate their dynamically aggregated monthly due
    return await db.rawQuery('''
      SELECT c.*, IFNULL(SUM(p.monthly_price), 0) as total_monthly_due
      FROM customers c
      LEFT JOIN stbs s ON c.id = s.customer_id AND s.status = 'active'
      LEFT JOIN packages p ON s.package_id = p.id
      WHERE c.area_id = ?
      GROUP BY c.id
    ''', [areaId]);
  }

  Future<List<Map<String, dynamic>>> getCustomerSTBs(String customerId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT s.*, p.name as package_name, p.monthly_price
      FROM stbs s
      LEFT JOIN packages p ON s.package_id = p.id
      WHERE s.customer_id = ?
    ''', [customerId]);
  }

  Future<void> markAsSynced(String table, String idColumn, String idValue) async {
    final db = await database;
    await db.update(table, {'sync_status': 'synced'}, where: '$idColumn = ?', whereArgs: [idValue]);
  }

  Future<void> upsertCloudData(String table, Map<String, dynamic> data, String idColumn) async {
    final db = await database;
    data['sync_status'] = 'synced'; // Data from cloud is already synced
    // Remove updated_at if SQLite table doesn't have it (areas, packages, stbs, payments don't in our current local schema)
    if (table != 'customers') data.remove('updated_at'); 
    
    await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Global Ledger Queries ---

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT c.*, a.name as area_name
      FROM customers c
      LEFT JOIN areas a ON c.area_id = a.id
      ORDER BY c.name ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getAllSTBs() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT s.*, c.name as customer_name, p.name as package_name
      FROM stbs s
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN packages p ON s.package_id = p.id
      ORDER BY s.box_id ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getAllPayments() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, c.name as customer_name
      FROM payments p
      LEFT JOIN customers c ON p.customer_id = c.id
      ORDER BY p.collected_at DESC
    ''');
  }

  // --- CRUD Operations ---
  Future<void> upsertPackage(Map<String, dynamic> package) async {
    final db = await database;
    // Set status to pending so the SyncEngine knows to upload it
    package['sync_status'] = 'pending'; 
    await db.insert('packages', package, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Search & Filter Queries ---
  Future<List<Map<String, dynamic>>> searchCustomers(String query, int limit, int offset) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT c.*, a.name as area_name
      FROM customers c
      LEFT JOIN areas a ON c.area_id = a.id
      WHERE c.name LIKE ? OR c.phone LIKE ?
      ORDER BY c.name ASC
      LIMIT ? OFFSET ?
    ''', ['%$query%', '%$query%', limit, offset]);
  }
}
