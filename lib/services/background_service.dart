import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../database/db_helper.dart';
import '../models/non_working_day.dart';
import '../utils/helpers.dart';
import 'notification_service.dart';

Duration durationUntilNextTime(int hour, int minute) {
  final now = DateTime.now();
  var target = DateTime(now.year, now.month, now.day, hour, minute);
  if (target.isBefore(now)) {
    target = target.add(const Duration(days: 1));
  }
  return target.difference(now);
}

Future<List<Map<String, dynamic>>> checkMissingEntriesInBackground() async {
  final dbHelper = DBHelper();
  final db = await dbHelper.database;

  // 1. Get employee
  final employee = await dbHelper.getEmployee();
  final employeeId = employee != null ? employee['id'] as int : -1;

  // 2. Get assigned ATM IDs
  final assignedAtmIds = employee != null ? await dbHelper.getAssignedAtmIds(employeeId) : <String>[];

  // 3. Get non-working days
  final List<NonWorkingDay> nonWorkingDays = await dbHelper.getNonWorkingDays();
  final nonWorkingSets = nonWorkingDays.map((n) => '${n.atmId}_${n.dateString}').toSet();

  // 4. Get transactions
  final List<Map<String, dynamic>> txMaps = await db.query('transactions');
  final loggedSets = txMaps.map((t) => '${t['atm_id']}_${t['date']}').toSet();

  // Part C DB prints
  final dbInit = db.isOpen;
  debugPrint('[4.4.1 Database] database initialized = $dbInit');
  debugPrint('[4.4.1 Database] transaction records = ${txMaps.length}');
  debugPrint('[4.4.1 Database] non-working records = ${nonWorkingDays.length}');

  // 5. Get registration date from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final regDateStr = prefs.getString('registration_date') ?? '';

  return Helpers.calculateMissingEntries(
    assignedAtmIds: assignedAtmIds,
    regDateStr: regDateStr,
    loggedSets: loggedSets,
    nonWorkingSets: nonWorkingSets,
  );
}

Future<bool> runNotificationCheckTask(String taskName) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // 1. Initialize notifications plugin
    final notificationService = NotificationService();
    await notificationService.init();

    // 2. Respect "Missing Entry Reminders" setting
    final prefs = await SharedPreferences.getInstance();
    final remindersOn = prefs.getBool('missing_entry_reminders') ?? true;

    // Part C Preferences log
    debugPrint('[4.4.1 Preferences] reminder enabled = $remindersOn');

    // 3. Query SQLite for missing entries
    final missingEntries = await checkMissingEntriesInBackground();

    // Part C MissingEntry logs
    final today = DateTime.now();
    final todayStr = DateFormat('dd MMM yyyy').format(today);
    final regDateStr = prefs.getString('registration_date') ?? '';
    final registrationDate = DateTime.tryParse(regDateStr) ?? today.subtract(const Duration(days: 14));
    final regStr = DateFormat('dd MMM yyyy').format(registrationDate);
    final missingDatesText = missingEntries.map((m) => DateFormat('dd MMM yyyy').format(m['date'] as DateTime)).toList().toString();

    debugPrint('[4.4.1 MissingEntry] current date = $todayStr');
    debugPrint('[4.4.1 MissingEntry] registration date = $regStr');
    debugPrint('[4.4.1 MissingEntry] calculated missing dates = $missingDatesText');

    // 4. Check notification details
    final permissionGranted = await notificationService.checkPermission();
    final permissionStr = permissionGranted ? 'granted' : 'denied';
    debugPrint('[4.4.1 Notification] permission = $permissionStr');
    debugPrint('[4.4.1 Notification] channel = background_reminders_channel');

    final isMorning = taskName == 'morning_check' || taskName == 'morning_check_task';
    final isEvening = taskName == 'evening_check' || taskName == 'evening_check_task';
    final isTest = taskName == 'test_check' || (!isMorning && !isEvening);

    final simulatedTaskName = isTest ? 'morning_check' : taskName;
    final isMorningSim = simulatedTaskName == 'morning_check' || simulatedTaskName == 'morning_check_task';

    final notificationEligible = remindersOn && missingEntries.isNotEmpty && permissionGranted;
    debugPrint('[4.4.1 Notification] eligible = $notificationEligible');

    if (notificationEligible) {
      final int count = missingEntries.length;
      String message = '';
      String title = '⚠️ Abhi ATM Manager';

      if (isMorningSim) {
        if (count == 1) {
          final dateStr = DateFormat('dd MMM').format(missingEntries.first['date'] as DateTime);
          message = 'Your ATM transaction entry for $dateStr is still missing.';
        } else {
          message = '$count ATM transaction entries are still missing.';
        }
      } else {
        if (count == 1) {
          final dateStr = DateFormat('dd MMM').format(missingEntries.first['date'] as DateTime);
          message = 'Your ATM transaction entry for $dateStr is still pending.';
        } else {
          message = '$count ATM transaction entries still need attention.';
        }
      }

      debugPrint('[4.4.1 Notification] calling show()');
      await notificationService.showBackgroundReminder(title, message);
      debugPrint('[4.4.1 Notification] show completed = true');
    } else {
      debugPrint('[4.4.1 Notification] show completed = false');
    }

    // 5. Reschedule the task for exactly 24 hours later if WorkManager scheduled task
    if (isMorning) {
      await Workmanager().registerOneOffTask(
        'morning_check_task',
        'morning_check',
        initialDelay: const Duration(hours: 24),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      debugPrint('[4.4.2 Scheduler] Rescheduled morning_check_task for 24 hours later.');
    } else if (isEvening) {
      await Workmanager().registerOneOffTask(
        'evening_check_task',
        'evening_check',
        initialDelay: const Duration(hours: 24),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      debugPrint('[4.4.2 Scheduler] Rescheduled evening_check_task for 24 hours later.');
    }
    
    debugPrint('[4.4.2 Worker] result = success');
    return true;
  } catch (e) {
    debugPrint('[4.4.2 Worker] result = failure');
    debugPrint('[4.4.2 Retry] reason = $e');
    return false;
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final isRecognized = taskName == 'morning_check' ||
        taskName == 'morning_check_task' ||
        taskName == 'evening_check' ||
        taskName == 'evening_check_task';

    debugPrint('[4.4.2 Worker] callback entered');
    debugPrint('[4.4.2 Worker] taskName = $taskName');
    debugPrint('[4.4.2 Worker] task recognized = $isRecognized');
    debugPrint('[4.4.2 Worker] background initialization complete');
    debugPrint('[4.4.2 Worker] execution started');

    final success = await runNotificationCheckTask(taskName);
    
    final resultStr = success ? 'success' : 'failure';
    debugPrint('[4.4.2 Worker] execution completed');
    debugPrint('[4.4.2 Worker] result = $resultStr');
    
    return Future.value(success);
  });
}
