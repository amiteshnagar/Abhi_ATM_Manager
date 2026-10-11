import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/non_working_day.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;
  static Future<Database>? _databaseFuture;
  static const String _dbName = 'transactions.db';
  static const int _dbVersion = 6; // Incremented database version for migration

  Future<Database> get database async {
    if (_database != null) return _database!;
    _databaseFuture ??= _initDatabase();
    _database = await _databaseFuture!;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _dbName);
    
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create the transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        atm_id TEXT NOT NULL,
        count INTEGER NOT NULL,
        rate REAL NOT NULL,
        total REAL NOT NULL,
        remarks TEXT,
        UNIQUE(date, atm_id)
      )
    ''');

    // Create an index on the date and atm_id columns for optimized queries
    await db.execute('''
      CREATE INDEX idx_transactions_date_atm ON transactions(date, atm_id)
    ''');

    // Create employees table
    await db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        mobile TEXT NOT NULL,
        pin TEXT NOT NULL,
        profile_photo_path TEXT
      )
    ''');

    // Create atms table
    await db.execute('''
      CREATE TABLE atms (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    // Create employee_atms table
    await db.execute('''
      CREATE TABLE employee_atms (
        employee_id INTEGER,
        atm_id TEXT,
        PRIMARY KEY (employee_id, atm_id),
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
        FOREIGN KEY (atm_id) REFERENCES atms (id) ON DELETE CASCADE
      )
    ''');

    // Populate initial ATMs
    await db.execute("INSERT INTO atms (id, name) VALUES ('ABHI01', 'Pachore Main')");
    await db.execute("INSERT INTO atms (id, name) VALUES ('ATM02', 'ATM02')");
    await db.execute("INSERT INTO atms (id, name) VALUES ('ATM03', 'ATM03')");
    await db.execute("INSERT INTO atms (id, name) VALUES ('ATM04', 'ATM04')");

    // Create non_working_days table
    await db.execute('''
      CREATE TABLE non_working_days (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        atm_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        remarks TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(date, atm_id)
      )
    ''');

    // Create transaction_audit table
    await db.execute('''
      CREATE TABLE transaction_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        employee_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        atm_id TEXT NOT NULL,
        action TEXT NOT NULL,
        previous_count INTEGER,
        new_count INTEGER,
        previous_rate REAL,
        new_rate REAL,
        previous_total REAL,
        new_total REAL,
        previous_remarks TEXT,
        new_remarks TEXT,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Create indexes for efficient querying
    await db.execute('CREATE INDEX idx_audit_transaction_id ON transaction_audit(transaction_id)');
    await db.execute('CREATE INDEX idx_audit_atm_id ON transaction_audit(atm_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Create employees table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS employees (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          mobile TEXT NOT NULL,
          pin TEXT NOT NULL
        )
      ''');

      // 2. Create atms table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS atms (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');

      // Populate initial ATMs if not exist
      await db.execute("INSERT OR IGNORE INTO atms (id, name) VALUES ('ABHI01', 'Pachore Main')");
      await db.execute("INSERT OR IGNORE INTO atms (id, name) VALUES ('ATM02', 'ATM02')");
      await db.execute("INSERT OR IGNORE INTO atms (id, name) VALUES ('ATM03', 'ATM03')");
      await db.execute("INSERT OR IGNORE INTO atms (id, name) VALUES ('ATM04', 'ATM04')");

      // 3. Create transactions_new table to safely alter schema and unique constraints
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transactions_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          atm_id TEXT NOT NULL,
          count INTEGER NOT NULL,
          rate REAL NOT NULL,
          total REAL NOT NULL,
          remarks TEXT,
          UNIQUE(date, atm_id)
        )
      ''');

      // Copy old records to transactions_new
      // We fill atm_id with a default value 'ABHI01'
      try {
        await db.execute('''
          INSERT INTO transactions_new (id, date, atm_id, count, rate, total, remarks)
          SELECT id, date, 'ABHI01', count, rate, total, '' FROM transactions
        ''');
        
        // Drop old table
        await db.execute('DROP TABLE transactions');
        
        // Rename transactions_new to transactions
        await db.execute('ALTER TABLE transactions_new RENAME TO transactions');
      } catch (e) {
        // Fallback: If table transactions does not exist or empty
      }

      // Create index
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_transactions_date_atm ON transactions(date, atm_id)
      ''');
    }
    if (oldVersion < 3) {
      // Create employee_atms table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS employee_atms (
          employee_id INTEGER,
          atm_id TEXT,
          PRIMARY KEY (employee_id, atm_id),
          FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
          FOREIGN KEY (atm_id) REFERENCES atms (id) ON DELETE CASCADE
        )
      ''');
      // Sync existing employees to default ATM 'ABHI01'
      try {
        await db.execute('''
          INSERT INTO employee_atms (employee_id, atm_id)
          SELECT id, 'ABHI01' FROM employees
        ''');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN profile_photo_path TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS non_working_days (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            atm_id TEXT NOT NULL,
            reason TEXT NOT NULL,
            remarks TEXT,
            created_at TEXT NOT NULL,
            UNIQUE(date, atm_id)
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS transaction_audit (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER NOT NULL,
            employee_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            atm_id TEXT NOT NULL,
            action TEXT NOT NULL,
            previous_count INTEGER,
            new_count INTEGER,
            previous_rate REAL,
            new_rate REAL,
            previous_total REAL,
            new_total REAL,
            previous_remarks TEXT,
            new_remarks TEXT,
            reason TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_transaction_id ON transaction_audit(transaction_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_atm_id ON transaction_audit(atm_id)');
      } catch (_) {}
    }
  }

  // Get the database file path
  Future<String> getDbPath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, _dbName);
  }

  // Close the database connection
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Force close and delete database file (useful for full reset/restores)
  Future<void> deleteDatabaseFile() async {
    await closeDatabase();
    final path = await getDbPath();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // Helper: Get registered employee
  Future<Map<String, dynamic>?> getEmployee() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('employees', limit: 1);
    if (maps.isEmpty) return null;
    return maps.first;
  }

  // Helper: Register employee
  Future<int> registerEmployee(String name, String mobile, String pin, String atmId) async {
    final db = await database;
    await db.delete('employees'); // Wipe any existing employee profiles
    await db.delete('employee_atms'); // Wipe any existing mappings
    
    final employeeId = await db.insert('employees', {
      'name': name,
      'mobile': mobile,
      'pin': pin,
    });

    await db.insert('employee_atms', {
      'employee_id': employeeId,
      'atm_id': atmId,
    });

    return employeeId;
  }

  // Helper: Get assigned ATM IDs for employee
  Future<List<String>> getAssignedAtmIds(int employeeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'employee_atms',
      columns: ['atm_id'],
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
    return maps.map((m) => m['atm_id'] as String).toList();
  }

  // Helper: Get all ATMs
  Future<List<Map<String, dynamic>>> getATMs() async {
    final db = await database;
    return await db.query('atms');
  }

  // Helper: Insert an ATM
  Future<int> insertATM(String id, String name) async {
    final db = await database;
    return await db.insert(
      'atms',
      {'id': id, 'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Helper: Delete an ATM
  Future<int> deleteATM(String id) async {
    final db = await database;
    return await db.delete(
      'atms',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Helper: Update employee profile (name and profile photo path)
  Future<int> updateEmployeeProfile(int id, String name, String? profilePhotoPath) async {
    final db = await database;
    return await db.update(
      'employees',
      {
        'name': name,
        'profile_photo_path': profilePhotoPath,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Helper: Update employee security PIN
  Future<int> updateEmployeePin(int id, String newPin) async {
    final db = await database;
    return await db.update(
      'employees',
      {
        'pin': newPin,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Helper: Get all non-working days
  Future<List<NonWorkingDay>> getNonWorkingDays() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('non_working_days');
    return maps.map((m) => NonWorkingDay.fromMap(m)).toList();
  }

  // Helper: Insert non-working day
  Future<int> insertNonWorkingDay(NonWorkingDay day) async {
    final db = await database;
    return await db.insert(
      'non_working_days',
      day.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Helper: Delete a non-working day
  Future<int> deleteNonWorkingDay(String date, String atmId) async {
    final db = await database;
    return await db.delete(
      'non_working_days',
      where: 'date = ? AND atm_id = ?',
      whereArgs: [date, atmId],
    );
  }

  // Helper: Update transaction with audit entry in a single safe SQL Transaction
  Future<void> updateTransactionWithAudit(Map<String, dynamic> recordMap, Map<String, dynamic> auditData) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transaction_audit', auditData);
      await txn.update(
        'transactions',
        {
          'date': recordMap['date'],
          'atm_id': recordMap['atm_id'],
          'count': recordMap['count'],
          'rate': recordMap['rate'],
          'total': recordMap['total'],
          'remarks': recordMap['remarks'],
        },
        where: 'id = ?',
        whereArgs: [recordMap['id']],
      );
    });
  }

  // Helper: Delete transaction with audit entry in a single safe SQL Transaction
  Future<void> deleteTransactionWithAudit(int transactionId, Map<String, dynamic> auditData) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transaction_audit', auditData);
      await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
  }

  // Helper: Get audit history for a transaction id
  Future<List<Map<String, dynamic>>> getAuditHistory(int transactionId) async {
    final db = await database;
    return await db.query(
      'transaction_audit',
      where: 'transaction_id = ?',
      orderBy: 'created_at DESC',
    );
  }

  // Helper: Get all audit history for assigned ATMs
  Future<List<Map<String, dynamic>>> getAllAuditHistoryForAtms(List<String> atmIds) async {
    final db = await database;
    if (atmIds.isEmpty) return [];
    final placeholders = List.filled(atmIds.length, '?').join(', ');
    return await db.query(
      'transaction_audit',
      where: 'atm_id IN ($placeholders)',
      whereArgs: atmIds,
      orderBy: 'created_at DESC',
    );
  }
}
