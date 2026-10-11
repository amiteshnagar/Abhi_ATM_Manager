import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/transaction_record.dart';
import 'transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final DBHelper _dbHelper;
  
  TransactionRepositoryImpl(this._dbHelper);

  @override
  Future<List<TransactionRecord>> getAllTransactions() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
    );
    return maps.map((map) => TransactionRecord.fromMap(map)).toList();
  }

  @override
  Future<TransactionRecord?> getTransactionByDateAndAtm(String dateString, String atmId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date = ? AND atm_id = ?',
      whereArgs: [dateString, atmId],
    );
    if (maps.isEmpty) return null;
    return TransactionRecord.fromMap(maps.first);
  }

  @override
  Future<int> insertTransaction(TransactionRecord record) async {
    final db = await _dbHelper.database;
    // Check if duplicate exists (same date and atm_id)
    final List<Map<String, dynamic>> existing = await db.query(
      'transactions',
      columns: ['id'],
      where: 'date = ? AND atm_id = ?',
      whereArgs: [record.dateString, record.atmId],
    );
    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as int;
      await db.update(
        'transactions',
        record.toMap()..['id'] = existingId,
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return existingId;
    }
    return await db.insert(
      'transactions',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort, // Enforce strict unique constraint
    );
  }

  @override
  Future<int> updateTransaction(TransactionRecord record) async {
    final db = await _dbHelper.database;
    return await db.update(
      'transactions',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  @override
  Future<int> deleteTransaction(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> clearAllTransactions() async {
    final db = await _dbHelper.database;
    await db.delete('transactions');
  }

  @override
  Future<List<Map<String, dynamic>>> getAuditHistory(int transactionId) async {
    return await _dbHelper.getAuditHistory(transactionId);
  }

  @override
  Future<void> updateTransactionWithAudit(TransactionRecord record, Map<String, dynamic> auditData) async {
    await _dbHelper.updateTransactionWithAudit(record.toMap(), auditData);
  }

  @override
  Future<void> deleteTransactionWithAudit(int transactionId, Map<String, dynamic> auditData) async {
    await _dbHelper.deleteTransactionWithAudit(transactionId, auditData);
  }
}
