import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../models/transaction_record.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/transaction_repository_impl.dart';
import 'auth_provider.dart';

// Provider for SQLite DBHelper
final dbHelperProvider = Provider<DBHelper>((ref) => DBHelper());

// Provider for TransactionRepository
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final dbHelper = ref.watch(dbHelperProvider);
  return TransactionRepositoryImpl(dbHelper);
});

// Provider to track if transaction list has completed initial load
final transactionListLoadingProvider = StateProvider<bool>((ref) => true);

// StateNotifier to manage list of transaction records
class TransactionListNotifier extends StateNotifier<List<TransactionRecord>> {
  final TransactionRepository _repository;
  final List<String> assignedAtmIds;
  final Ref? _ref;

  TransactionListNotifier(this._repository, {this.assignedAtmIds = const [], this._ref})
      : super([]) {
    loadTransactions();
  }

  // Load all transactions from database sorted newest first
  Future<void> loadTransactions() async {
    try {
      final list = await _repository.getAllTransactions();
      if (assignedAtmIds.isNotEmpty) {
        state = list.where((record) => assignedAtmIds.contains(record.atmId)).toList();
      } else {
        state = list;
      }
    } finally {
      _ref?.read(transactionListLoadingProvider.notifier).state = false;
    }
  }

  // Check if a transaction already exists for a specific date and ATM
  bool doesRecordExist(String dateString, String atmId) {
    return state.any((record) => record.dateString == dateString && record.atmId == atmId);
  }

  // Get a record by date and ATM if it exists
  TransactionRecord? getRecordByDateAndAtm(String dateString, String atmId) {
    try {
      return state.firstWhere((record) => record.dateString == dateString && record.atmId == atmId);
    } catch (_) {
      return null;
    }
  }

  // Save a new transaction (checks duplicate)
  Future<void> saveTransaction(TransactionRecord record) async {
    await _repository.insertTransaction(record);
    await loadTransactions(); // Refresh local state
  }

  // Overwrite an existing record for the same date and ATM
  Future<void> overwriteTransaction(TransactionRecord record) async {
    final existing = getRecordByDateAndAtm(record.dateString, record.atmId);
    if (existing != null) {
      final updated = record.copyWith(id: existing.id);
      await _repository.updateTransaction(updated);
    } else {
      await _repository.insertTransaction(record);
    }
    await loadTransactions();
  }

  // Update a transaction record
  Future<void> updateTransaction(TransactionRecord record) async {
    await _repository.updateTransaction(record);
    await loadTransactions();
  }

  // Delete a transaction record
  Future<void> deleteTransaction(int id) async {
    await _repository.deleteTransaction(id);
    await loadTransactions();
  }

  // Clear all transactions (wipe database table)
  Future<void> resetAllTransactions() async {
    await _repository.clearAllTransactions();
    state = [];
  }

  // Reload state completely (useful after database restore)
  Future<void> refreshAfterRestore() async {
    await loadTransactions();
  }

  // Update a transaction with an audit log
  Future<void> updateTransactionWithAudit(TransactionRecord record, Map<String, dynamic> auditData) async {
    await _repository.updateTransactionWithAudit(record, auditData);
    await loadTransactions();
  }

  // Delete a transaction with an audit log
  Future<void> deleteTransactionWithAudit(int transactionId, Map<String, dynamic> auditData) async {
    await _repository.deleteTransactionWithAudit(transactionId, auditData);
    await loadTransactions();
  }

  // Fetch audit history for a transaction ID
  Future<List<Map<String, dynamic>>> getAuditHistory(int transactionId) async {
    return await _repository.getAuditHistory(transactionId);
  }
}

// Provider for TransactionListNotifier
final transactionListProvider =
    StateNotifierProvider<TransactionListNotifier, List<TransactionRecord>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final auth = ref.watch(authProvider);
  return TransactionListNotifier(repository, assignedAtmIds: auth.assignedAtmIds, ref: ref);
});

// ATM List Provider loading from SQLite
final atmListProvider = StateNotifierProvider<ATMListNotifier, List<Map<String, String>>>((ref) {
  final dbHelper = ref.watch(dbHelperProvider);
  final auth = ref.watch(authProvider);
  return ATMListNotifier(dbHelper, assignedAtmIds: auth.assignedAtmIds);
});

class ATMListNotifier extends StateNotifier<List<Map<String, String>>> {
  final DBHelper _dbHelper;
  final List<String> _assignedAtmIds;
  
  ATMListNotifier(this._dbHelper, {this._assignedAtmIds = const []})
      : super([]) {
    loadATMs();
  }

  Future<void> loadATMs() async {
    final list = await _dbHelper.getATMs();
    final mapped = list.map((item) => {
      'id': item['id'] as String,
      'name': item['name'] as String,
    }).toList();

    if (_assignedAtmIds.isNotEmpty) {
      state = mapped.where((atm) => _assignedAtmIds.contains(atm['id'])).toList();
    } else {
      state = mapped;
    }
  }

  Future<void> addATM(String id, String name) async {
    await _dbHelper.insertATM(id, name);
    await loadATMs();
  }

  Future<void> deleteATM(String id) async {
    await _dbHelper.deleteATM(id);
    await loadATMs();
  }
}
