import '../models/transaction_record.dart';

abstract class TransactionRepository {
  Future<List<TransactionRecord>> getAllTransactions();
  Future<TransactionRecord?> getTransactionByDateAndAtm(String dateString, String atmId);
  Future<int> insertTransaction(TransactionRecord record);
  Future<int> updateTransaction(TransactionRecord record);
  Future<int> deleteTransaction(int id);
  Future<void> clearAllTransactions();
  Future<List<Map<String, dynamic>>> getAuditHistory(int transactionId);
  Future<void> updateTransactionWithAudit(TransactionRecord record, Map<String, dynamic> auditData);
  Future<void> deleteTransactionWithAudit(int transactionId, Map<String, dynamic> auditData);
}
