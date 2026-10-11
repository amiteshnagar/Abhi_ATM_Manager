import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../models/non_working_day.dart';
import 'auth_provider.dart';
import 'transaction_provider.dart';

class NonWorkingDayNotifier extends StateNotifier<List<NonWorkingDay>> {
  final DBHelper _dbHelper;
  final List<String> _assignedAtmIds;

  NonWorkingDayNotifier(this._dbHelper, {this._assignedAtmIds = const []})
      : super([]) {
    loadNonWorkingDays();
  }

  Future<void> loadNonWorkingDays() async {
    final list = await _dbHelper.getNonWorkingDays();
    if (_assignedAtmIds.isNotEmpty) {
      state = list.where((day) => _assignedAtmIds.contains(day.atmId)).toList();
    } else {
      state = list;
    }
  }

  bool isNonWorking(String dateString, String atmId) {
    return state.any((day) => day.dateString == dateString && day.atmId == atmId);
  }

  NonWorkingDay? getNonWorkingDay(String dateString, String atmId) {
    try {
      return state.firstWhere((day) => day.dateString == dateString && day.atmId == atmId);
    } catch (_) {
      return null;
    }
  }

  Future<void> addNonWorkingDay(NonWorkingDay day) async {
    await _dbHelper.insertNonWorkingDay(day);
    await loadNonWorkingDays();
  }

  Future<void> removeNonWorkingDay(String dateString, String atmId) async {
    await _dbHelper.deleteNonWorkingDay(dateString, atmId);
    await loadNonWorkingDays();
  }
}

final nonWorkingDayProvider = StateNotifierProvider<NonWorkingDayNotifier, List<NonWorkingDay>>((ref) {
  final dbHelper = ref.watch(dbHelperProvider);
  final authState = ref.watch(authProvider);
  return NonWorkingDayNotifier(dbHelper, assignedAtmIds: authState.assignedAtmIds);
});
