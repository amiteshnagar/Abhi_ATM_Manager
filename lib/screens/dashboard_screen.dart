import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction_record.dart';
import '../models/non_working_day.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/non_working_day_provider.dart';
import '../utils/helpers.dart';
import '../database/db_helper.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/quick_log_sheet.dart';
import '../widgets/reason_dialog.dart';
import '../widgets/loading_indicator.dart';
import '../services/notification_service.dart';
import 'missing_entries_screen.dart';
import 'settings_screen.dart';
import 'activity_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedAtmId;
  bool _useCustomRate = false;
  bool _isEditingExisting = false;
  String _motivationalMessage = '';
  String? _lastNotifiedDateStr;

  final List<String> _quotes = [
    "Accuracy in logging ensures business integrity.",
    "Log your daily ATM logs on time to avoid gaps.",
    "Smart management today leads to growth tomorrow.",
    "Keep the database clean. Verify all transaction values.",
    "Every log recorded builds a stronger reports dashboard.",
    "Great job managing the Abhi Computer Private ATMs!",
  ];

  @override
  void initState() {
    super.initState();
    _countController.addListener(_calculateLiveEarnings);
    _rateController.addListener(_calculateLiveEarnings);
    _motivationalMessage = _quotes[Random().nextInt(_quotes.length)];

    // Initialize form variables after frame load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      _rateController.text = settings.defaultRate.toString();
      _initializeFirstAtm();
      NotificationService().requestPermission();
    });
  }

  @override
  void dispose() {
    _countController.removeListener(_calculateLiveEarnings);
    _rateController.removeListener(_calculateLiveEarnings);
    _countController.dispose();
    _remarksController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _loadRecordForDateAndAtm(DateTime date, String? atmId) {
    if (atmId == null) return;
    final settings = ref.read(settingsProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final record = ref.read(transactionListProvider.notifier).getRecordByDateAndAtm(dateStr, atmId);
    if (record != null) {
      _countController.text = record.count.toString();
      _remarksController.text = record.remarks ?? '';
      _useCustomRate = record.rate != settings.defaultRate;
      _rateController.text = record.rate.toString();
      _isEditingExisting = true;
    } else {
      _countController.clear();
      _remarksController.clear();
      _useCustomRate = false;
      _rateController.text = settings.defaultRate.toString();
      _isEditingExisting = false;
    }
  }

  void _initializeFirstAtm() {
    final auth = ref.read(authProvider);
    final settings = ref.read(settingsProvider);
    String? selectedAtm;
    if (auth.assignedAtmIds.length == 1) {
      selectedAtm = auth.assignedAtmIds.first;
    } else {
      final atms = ref.read(atmListProvider);
      if (atms.isNotEmpty) {
        selectedAtm = atms.first['id'];
      }
    }
    
    if (selectedAtm != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final record = ref.read(transactionListProvider.notifier).getRecordByDateAndAtm(dateStr, selectedAtm);
      setState(() {
        _selectedAtmId = selectedAtm;
        if (record != null) {
          _countController.text = record.count.toString();
          _remarksController.text = record.remarks ?? '';
          _useCustomRate = record.rate != settings.defaultRate;
          _rateController.text = record.rate.toString();
          _isEditingExisting = false;
        }
      });
    }
  }

  void _calculateLiveEarnings() {
    setState(() {});
  }

  void _resetInput() {
    final settings = ref.read(settingsProvider);
    final atms = ref.read(atmListProvider);
    ref.read(dashboardIsMissingEntryModeProvider.notifier).state = false;
    setState(() {
      _countController.clear();
      _remarksController.clear();
      _selectedDate = DateTime.now();
      _useCustomRate = false;
      _rateController.text = settings.defaultRate.toString();
      _isEditingExisting = false;
      if (atms.isNotEmpty) {
        _selectedAtmId = atms.first['id'];
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(DateTime.now()) ? DateTime.now() : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      final settings = ref.read(settingsProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      final record = ref.read(transactionListProvider.notifier).getRecordByDateAndAtm(dateStr, _selectedAtmId ?? '');
      setState(() {
        _selectedDate = picked;
        if (record != null) {
          _countController.text = record.count.toString();
          _remarksController.text = record.remarks ?? '';
          _useCustomRate = record.rate != settings.defaultRate;
          _rateController.text = record.rate.toString();
          _isEditingExisting = false;
        } else {
          _countController.clear();
          _remarksController.clear();
          _useCustomRate = false;
          _rateController.text = settings.defaultRate.toString();
          _isEditingExisting = false;
        }
      });
    }
  }

  Future<void> _saveRecord({List<Map<String, dynamic>>? pendingList}) async {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final selectedMidnight = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (selectedMidnight.isAfter(todayMidnight)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Future date entries are not allowed.')),
      );
      return;
    }

    final countText = _countController.text.trim();
    if (countText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter transaction count.')),
      );
      return;
    }

    final count = int.tryParse(countText);
    if (count == null || count < 0 || count > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid count between 0 and 1000.')),
      );
      return;
    }

    if (_selectedAtmId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an ATM.')),
      );
      return;
    }

    final rateVal = double.tryParse(_rateController.text) ?? 0.0;
    final notifier = ref.read(transactionListProvider.notifier);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Get existing record to get its id
    final existing = notifier.getRecordByDateAndAtm(dateStr, _selectedAtmId!);
    final record = TransactionRecord.calculate(
      id: existing?.id, // Pass existing id if it exists
      date: _selectedDate,
      atmId: _selectedAtmId!,
      count: count,
      rate: rateVal,
      remarks: _remarksController.text.trim(),
    );

    if (existing != null) {
      final reason = await showReasonDialog(
        context: context,
        title: 'Why are you updating this transaction?',
        labelText: 'Reason for Update',
        actionButtonText: 'Update Transaction',
      );
      if (reason == null) return; // User cancelled

      final employee = await DBHelper().getEmployee();
      final employeeId = employee?['id'] as int? ?? 0;

      final auditData = {
        'transaction_id': existing.id,
        'employee_id': employeeId,
        'date': existing.dateString,
        'atm_id': existing.atmId,
        'action': 'UPDATE',
        'previous_count': existing.count,
        'new_count': record.count,
        'previous_rate': existing.rate,
        'new_rate': record.rate,
        'previous_total': existing.total,
        'new_total': record.total,
        'previous_remarks': existing.remarks,
        'new_remarks': record.remarks,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        await notifier.updateTransactionWithAudit(record, auditData);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update transaction: $e')),
          );
        }
        return;
      }
    } else {
      await notifier.saveTransaction(record);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved successfully.')),
      );
    }

    _resetInput();

    // Auto-move to next pending date if applicable
    if (pendingList != null && pendingList.isNotEmpty) {
      // If we just submitted the oldest, find the next one
      final nextPending = pendingList.firstWhere(
        (p) => !(p['dateStr'] == dateStr && p['atmId'] == record.atmId),
        orElse: () => {},
      );
      if (nextPending.isNotEmpty) {
        final nextSettings = ref.read(settingsProvider);
        final nextRecord = notifier.getRecordByDateAndAtm(nextPending['dateStr'] as String, nextPending['atmId'] as String);
        setState(() {
          _selectedDate = nextPending['date'] as DateTime;
          _selectedAtmId = nextPending['atmId'] as String;
          if (nextRecord != null) {
            _countController.text = nextRecord.count.toString();
            _remarksController.text = nextRecord.remarks ?? '';
            _useCustomRate = nextRecord.rate != nextSettings.defaultRate;
            _rateController.text = nextRecord.rate.toString();
            _isEditingExisting = false;
          } else {
            _countController.clear();
            _remarksController.clear();
            _useCustomRate = false;
            _rateController.text = nextSettings.defaultRate.toString();
            _isEditingExisting = false;
          }
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Moved to next pending: ${nextPending['atmId']} on ${Helpers.formatDate(nextPending['date'] as DateTime)}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  int _calculateStreak(List<TransactionRecord> records) {
    if (records.isEmpty) return 0;
    final loggedDates = records.map((r) => r.dateString).toSet();
    int streak = 0;
    DateTime checkDate = DateTime.now();

    while (true) {
      final dateStr = DateFormat('yyyy-MM-dd').format(checkDate);
      if (loggedDates.contains(dateStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        if (streak == 0 && checkDate.day == DateTime.now().day) {
          checkDate = checkDate.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
    }
    return streak;
  }





  List<Map<String, dynamic>> _getPendingEntries({
    required List<TransactionRecord> records,
    required List<String> assignedAtmIds,
    required List<NonWorkingDay> nonWorkingDays,
    required String regDateStr,
    required List<Map<String, String>> atms,
  }) {
    final loggedSets = records.map((r) => '${r.atmId}_${r.dateString}').toSet();
    final nonWorkingSets = nonWorkingDays.map((n) => '${n.atmId}_${n.dateString}').toSet();

    final missing = Helpers.calculateMissingEntries(
      assignedAtmIds: assignedAtmIds,
      regDateStr: regDateStr,
      loggedSets: loggedSets,
      nonWorkingSets: nonWorkingSets,
    );

    return missing.map((m) {
      final atmId = m['atmId'] as String;
      final atmName = atms.firstWhere((a) => a['id'] == atmId, orElse: () => {'name': atmId})['name'] ?? atmId;
      return {
        'date': m['date'],
        'dateStr': m['dateStr'],
        'atmId': atmId,
        'atmName': atmName,
      };
    }).toList();
  }

  void _triggerNotification(List<Map<String, dynamic>> pendingList) {
    final settings = ref.read(settingsProvider);
    if (!settings.missingEntryReminders) return;

    if (pendingList.isNotEmpty) {
      final oldest = pendingList.first;
      final dateStr = Helpers.formatDate(oldest['date'] as DateTime);
      final key = '${oldest['atmId']}_${oldest['dateStr']}';
      
      if (_lastNotifiedDateStr != key) {
        _lastNotifiedDateStr = key;
        // Trigger offline local notification
        NotificationService().showPendingEntryReminder(dateStr);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final records = ref.watch(transactionListProvider);
    final atms = ref.watch(atmListProvider);
    final auth = ref.watch(authProvider);

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    // Load custom earnings goal
    final prefs = ref.watch(sharedPreferencesProvider);
    final goal = prefs.getDouble('monthly_earnings_goal') ?? 30000.0;
    final regDateStr = prefs.getString('registration_date') ?? '';
    final nonWorkingDays = ref.watch(nonWorkingDayProvider);

    // Synchronize with external navigation providers
    ref.listen<DateTime>(dashboardSelectedDateProvider, (previous, next) {
      if (next != _selectedDate) {
        setState(() {
          _selectedDate = next;
          _loadRecordForDateAndAtm(next, _selectedAtmId);
        });
      }
    });

    ref.listen<String?>(dashboardSelectedAtmIdProvider, (previous, next) {
      if (next != null && next != _selectedAtmId) {
        setState(() {
          _selectedAtmId = next;
          _loadRecordForDateAndAtm(_selectedDate, next);
        });
      }
    });

    ref.listen<bool>(dashboardIsEditingExistingProvider, (previous, next) {
      if (next != _isEditingExisting) {
        setState(() {
          _isEditingExisting = next;
        });
      }
    });

    final isMissingEntryMode = ref.watch(dashboardIsMissingEntryModeProvider);

    // Advanced Stats Calculations
    final currentStreak = _calculateStreak(records);
    final pendingEntriesList = _getPendingEntries(
      records: records,
      assignedAtmIds: auth.assignedAtmIds,
      nonWorkingDays: nonWorkingDays,
      regDateStr: regDateStr,
      atms: atms,
    );

    final now = DateTime.now();
    final monthlyRecords = records.where((r) => Helpers.isThisMonth(r.date));
    final double monthlyEarnings = monthlyRecords.fold(0.0, (sum, r) => sum + r.total);
    final double monthlyProgressPercent = (monthlyEarnings / goal).clamp(0.0, 1.0);

    // Trigger local notification reminder for oldest pending entry
    if (pendingEntriesList.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerNotification(pendingEntriesList);
      });
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    TransactionRecord? existingRecord;
    try {
      existingRecord = records.firstWhere(
        (r) => r.dateString == dateStr && r.atmId == (_selectedAtmId ?? ''),
      );
    } catch (_) {
      existingRecord = null;
    }
    final entryExists = existingRecord != null;

    final todayMidnight = DateTime(now.year, now.month, now.day);
    final selectedMidnight = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final isSelectedDateFuture = selectedMidnight.isAfter(todayMidnight);

    // Missing entries count calculation
    final limitDate = todayMidnight.subtract(const Duration(days: 1)); // Yesterday inclusive
    final loggedSets = records.map((t) => '${t.atmId}_${t.dateString}').toSet();
    final nonWorkingSets = nonWorkingDays.map((n) => '${n.atmId}_${n.dateString}').toSet();
    final registrationDate = DateTime.tryParse(regDateStr) ??
        todayMidnight.subtract(const Duration(days: 14));

    final List<Map<String, dynamic>> missingList = [];
    for (var atmId in auth.assignedAtmIds) {
      var checkDate = DateTime(registrationDate.year, registrationDate.month, registrationDate.day);
      while (checkDate.isBefore(limitDate) || checkDate.isAtSameMomentAs(limitDate)) {
        final checkDateStr = DateFormat('yyyy-MM-dd').format(checkDate);
        final key = '${atmId}_$checkDateStr';
        if (!loggedSets.contains(key) && !nonWorkingSets.contains(key)) {
          missingList.add({
            'date': checkDate,
            'dateStr': checkDateStr,
            'atmId': atmId,
          });
        }
        checkDate = checkDate.add(const Duration(days: 1));
      }
    }
    missingList.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    final int missingCount = missingList.length;

    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final todayRecords = records.where((r) => r.dateString == todayStr).toList();
    final double todayEarnings = todayRecords.fold(0.0, (sum, r) => sum + r.total);
    final isTodayCompleted = records.any((r) => r.dateString == todayStr && auth.assignedAtmIds.contains(r.atmId));
    final auditsAsync = ref.watch(activityAuditsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abhi ATM Manager'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                backgroundImage: auth.profilePhotoPath != null
                    ? FileImage(File(auth.profilePhotoPath!))
                    : null,
                child: auth.profilePhotoPath == null
                    ? Icon(Icons.account_circle, size: 28, color: theme.colorScheme.primary)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: ref.watch(transactionListLoadingProvider)
          ? const LoadingIndicator(isFullPage: true, message: 'Loading dashboard data...')
          : isMissingEntryMode
              ? _buildOriginalEntryLayout(
              theme: theme,
              isDark: isDark,
              settings: settings,
              records: records,
              atms: atms,
              auth: auth,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
              borderColor: borderColor,
              isMissingEntryMode: isMissingEntryMode,
              isTodayCompleted: isTodayCompleted,
              currentStreak: currentStreak,
              pendingEntriesList: pendingEntriesList,
              now: now,
              monthlyProgressPercent: monthlyProgressPercent,
              entryExists: entryExists,
              existingRecord: existingRecord,
              isSelectedDateFuture: isSelectedDateFuture,
              missingCount: missingCount,
              missingList: missingList,
              regDateStr: regDateStr,
              nonWorkingDays: nonWorkingDays,
            )
          : _buildSmartDashboard(
              context: context,
              auth: auth,
              isTodayCompleted: isTodayCompleted,
              todayCount: todayRecords.fold(0, (sum, r) => sum + r.count),
              todayEarnings: todayEarnings,
              missingList: missingList,
              monthEarnings: monthlyEarnings,
              monthlyGoal: goal,
              currencySymbol: settings.currency,
              auditsAsync: auditsAsync,
              nonWorkingDays: nonWorkingDays,
            ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 22) {
      return 'Good Evening';
    } else {
      return 'Hello';
    }
  }

  Widget _buildGreetingHeader(BuildContext context, dynamic auth, bool isTodayCompleted) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final now = DateTime.now();
    final greeting = _getGreeting();
    final name = auth.employeeName ?? "Operator";
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(now);
    final atmList = auth.assignedAtmIds.join(", ");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, $name 👋',
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isTodayCompleted ? const Color(0xFFEE1C4B) : const Color(0xFF525277),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isTodayCompleted ? "Today's Entry Completed" : "Today's Entry Pending",
                style: TextStyle(
                  fontFamily: 'Google Sans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isTodayCompleted ? const Color(0xFFEE1C4B) : secondaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            dateStr,
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontSize: 11,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Assigned ATM: $atmList',
            style: const TextStyle(
              fontFamily: 'Google Sans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFEE1C4B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(BuildContext context, int count, double earnings, String currencySymbol) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S PERFORMANCE",
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
              color: isDark ? Colors.white : const Color(0xFF1E1A4D),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontFamily: 'Google Sans',
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        color: Color(0xFFEE1C4B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Transactions',
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 11,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: borderColor,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Helpers.formatCurrency(earnings, currencySymbol),
                      style: const TextStyle(
                        fontFamily: 'Google Sans',
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        color: Color(0xFFEE1C4B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Earnings',
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 11,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmartStatusSection(
    BuildContext context,
    bool isTodayCompleted,
    List<Map<String, dynamic>> missingList,
    String? firstAssignedAtmId,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (missingList.isNotEmpty) {
      final oldestMissing = missingList.first;
      final mDate = oldestMissing['date'] as DateTime;
      final mAtmId = oldestMissing['atmId'] as String;
      final dateFormatted = DateFormat('dd MMM yyyy').format(mDate).toUpperCase();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEE1C4B).withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEE1C4B), size: 20),
                const SizedBox(width: 8),
                Text(
                  'PENDING ENTRY',
                  style: TextStyle(
                    fontFamily: 'Google Sans',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.0,
                    color: isDark ? Colors.white : const Color(0xFF1E1A4D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              dateFormatted,
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Transaction entry is still missing.',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 12,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEE1C4B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  ref.read(dashboardSelectedDateProvider.notifier).state = mDate;
                  ref.read(dashboardSelectedAtmIdProvider.notifier).state = mAtmId;
                  ref.read(dashboardIsEditingExistingProvider.notifier).state = false;
                  ref.read(dashboardIsMissingEntryModeProvider.notifier).state = true;
                },
                child: const Text(
                  'Enter Now',
                  style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (!isTodayCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEE1C4B).withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEE1C4B), size: 20),
                const SizedBox(width: 8),
                Text(
                  'ACTION REQUIRED',
                  style: TextStyle(
                    fontFamily: 'Google Sans',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.0,
                    color: isDark ? Colors.white : const Color(0xFF1E1A4D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Today's transaction entry is still pending.",
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEE1C4B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  if (firstAssignedAtmId != null) {
                    ref.read(dashboardSelectedDateProvider.notifier).state = DateTime.now();
                    ref.read(dashboardSelectedAtmIdProvider.notifier).state = firstAssignedAtmId;
                    ref.read(dashboardIsEditingExistingProvider.notifier).state = false;
                    ref.read(dashboardIsMissingEntryModeProvider.notifier).state = true;
                  }
                },
                child: const Text(
                  'Enter Now',
                  style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEE1C4B).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Color(0xFFEE1C4B), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You're all caught up",
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Today's transaction entry has been recorded.",
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 11,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMonthlyGoalCard(BuildContext context, double monthEarnings, double monthlyGoal, String currencySymbol) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final progressPercent = monthlyGoal > 0 ? (monthEarnings / monthlyGoal) * 100 : 0.0;
    final progressFraction = (progressPercent / 100).clamp(0.0, 1.0);

    if (monthlyGoal <= 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "MONTHLY GOAL",
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.0,
                color: isDark ? Colors.white : const Color(0xFF1E1A4D),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Set a monthly earnings goal in Account settings to track your progress.",
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 12,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "MONTHLY GOAL",
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
              color: isDark ? Colors.white : const Color(0xFF1E1A4D),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${Helpers.formatCurrency(monthEarnings, currencySymbol)} / ${Helpers.formatCurrency(monthlyGoal, currencySymbol)}',
                style: TextStyle(
                  fontFamily: 'Google Sans',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: primaryTextColor,
                ),
              ),
              Text(
                '${progressPercent.toStringAsFixed(0)}% completed',
                style: const TextStyle(
                  fontFamily: 'Google Sans',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFFEE1C4B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF7F7FA),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEE1C4B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "QUICK ACTIONS",
          style: TextStyle(
            fontFamily: 'Google Sans',
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 1.0,
            color: isDark ? Colors.white : const Color(0xFF1E1A4D),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _buildSmartQuickActionItem(
              context,
              label: 'Log Transaction',
              icon: Icons.add_circle_outline,
              color: const Color(0xFFEE1C4B),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const QuickLogSheet(),
                );
              },
            ),
            _buildSmartQuickActionItem(
              context,
              label: 'Complete Missing Entry',
              icon: Icons.calendar_today_outlined,
              color: const Color(0xFF1E1A4D),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MissingEntriesScreen()),
                );
              },
            ),
            _buildSmartQuickActionItem(
              context,
              label: 'View Reports',
              icon: Icons.analytics_outlined,
              color: Colors.blueGrey,
              onTap: () {
                ref.read(activeTabProvider.notifier).state = 2;
              },
            ),
            _buildSmartQuickActionItem(
              context,
              label: 'View History',
              icon: Icons.history_toggle_off,
              color: const Color(0xFF525277),
              onTap: () {
                ref.read(activeTabProvider.notifier).state = 3;
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmartQuickActionItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final cardBg = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Google Sans',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: primaryTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityPreview(
    BuildContext context,
    AsyncValue<List<Map<String, dynamic>>> auditsAsync,
    List<NonWorkingDay> nonWorkingDays,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "RECENT ACTIVITY",
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.0,
                color: isDark ? Colors.white : const Color(0xFF1E1A4D),
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(activeTabProvider.notifier).state = 1;
              },
              child: const Row(
                children: [
                  Text(
                    'View all',
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEE1C4B),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Color(0xFFEE1C4B), size: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        auditsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => const Center(child: Text("Unable to load activity")),
          data: (auditList) {
            final List<ActivityEvent> events = [];

            for (final audit in auditList) {
              final createdAt = DateTime.tryParse(audit['created_at'] ?? '') ?? DateTime.now();
              final action = audit['action'] as String? ?? 'UPDATE';
              final reason = audit['reason'] as String? ?? '';
              final prevCount = audit['previous_count'];
              final newCount = audit['new_count'];

              if (action == 'UPDATE') {
                events.add(ActivityEvent(
                  title: 'Transaction updated',
                  detail: 'Count changed from $prevCount to $newCount.\nReason: $reason',
                  timestamp: createdAt,
                  category: 'audit_update',
                ));
              } else if (action == 'DELETE') {
                events.add(ActivityEvent(
                  title: 'Transaction deleted',
                  detail: 'Deleted log for date: ${audit['date']}.\nReason: $reason',
                  timestamp: createdAt,
                  category: 'audit_delete',
                ));
              }
            }

            for (final nwd in nonWorkingDays) {
              final createdAt = nwd.createdAt;
              events.add(ActivityEvent(
                title: 'Marked Not Working',
                detail: 'ATM marked off-duty for date: ${nwd.dateString}.\nReason: ${nwd.reason}',
                timestamp: createdAt,
                category: 'non_working',
              ));
            }

            events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            if (events.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    "No recent activity",
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
              );
            }

            final previewEvents = events.take(3).toList();

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: previewEvents.length,
                itemBuilder: (context, index) {
                  final event = previewEvents[index];
                  final isLast = index == previewEvents.length - 1;
                  final timeFormatted = _formatActivityTime(event.timestamp);

                  IconData iconData = Icons.radio_button_checked;
                  Color iconColor = const Color(0xFFEE1C4B);

                  if (event.category == 'audit_update') {
                    iconData = Icons.edit_outlined;
                    iconColor = isDark ? const Color(0xFFF04A70) : const Color(0xFF1E1A4D);
                  } else if (event.category == 'audit_delete') {
                    iconData = Icons.delete_outline;
                    iconColor = const Color(0xFFEE1C4B);
                  } else if (event.category == 'non_working') {
                    iconData = Icons.block_outlined;
                    iconColor = secondaryTextColor;
                  }

                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0.0 : 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(iconData, size: 14, color: iconColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    event.title,
                                    style: TextStyle(
                                      fontFamily: 'Google Sans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  Text(
                                    timeFormatted,
                                    style: TextStyle(
                                      fontFamily: 'Google Sans',
                                      fontSize: 10,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event.detail,
                                style: TextStyle(
                                  fontFamily: 'Google Sans',
                                  fontSize: 11,
                                  color: secondaryTextColor,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatActivityTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(timestamp.year, timestamp.month, timestamp.day);

    final timeStr = DateFormat('h:mm a').format(timestamp);

    if (target == today) {
      return 'Today • $timeStr';
    } else if (target == yesterday) {
      return 'Yesterday • $timeStr';
    } else {
      return '${DateFormat('d MMM').format(timestamp)} • $timeStr';
    }
  }

  Widget _buildSmartDashboard({
    required BuildContext context,
    required dynamic auth,
    required bool isTodayCompleted,
    required int todayCount,
    required double todayEarnings,
    required List<Map<String, dynamic>> missingList,
    required double monthEarnings,
    required double monthlyGoal,
    required String currencySymbol,
    required AsyncValue<List<Map<String, dynamic>>> auditsAsync,
    required List<NonWorkingDay> nonWorkingDays,
  }) {
    final firstAssignedAtmId = auth.assignedAtmIds.isNotEmpty ? auth.assignedAtmIds.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreetingHeader(context, auth, isTodayCompleted),
          const SizedBox(height: 16),
          _buildPerformanceCard(context, todayCount, todayEarnings, currencySymbol),
          const SizedBox(height: 16),
          _buildSmartStatusSection(context, isTodayCompleted, missingList, firstAssignedAtmId),
          const SizedBox(height: 16),
          _buildMonthlyGoalCard(context, monthEarnings, monthlyGoal, currencySymbol),
          const SizedBox(height: 16),
          _buildQuickActions(context),
          const SizedBox(height: 16),
          _buildRecentActivityPreview(context, auditsAsync, nonWorkingDays),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOriginalEntryLayout({
    required ThemeData theme,
    required bool isDark,
    required dynamic settings,
    required List<TransactionRecord> records,
    required List<Map<String, String>> atms,
    required dynamic auth,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color cardBg,
    required Color borderColor,
    required bool isMissingEntryMode,
    required bool isTodayCompleted,
    required int currentStreak,
    required List<Map<String, dynamic>> pendingEntriesList,
    required DateTime now,
    required double monthlyProgressPercent,
    required bool entryExists,
    required TransactionRecord? existingRecord,
    required bool isSelectedDateFuture,
    required int missingCount,
    required List<Map<String, dynamic>> missingList,
    required String regDateStr,
    required List<NonWorkingDay> nonWorkingDays,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Greeting Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFEE1C4B).withValues(alpha: 0.12),
                  backgroundImage: auth.profilePhotoPath != null
                      ? FileImage(File(auth.profilePhotoPath!))
                      : null,
                  child: auth.profilePhotoPath == null
                      ? const Icon(Icons.person, color: Color(0xFFEE1C4B))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${auth.employeeName ?? "Operator"}!',
                        style: TextStyle(
                          fontFamily: 'Google Sans',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isTodayCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isTodayCompleted ? "Today's Entry Completed" : "Today's Entry Pending",
                            style: TextStyle(
                              fontFamily: 'Google Sans',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isTodayCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                      if (missingCount > 0) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MissingEntriesScreen()),
                            );
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '$missingCount Missing Entr${missingCount == 1 ? "y" : "ies"}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '[Review]',
                                style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Assigned ATM: ${auth.assignedAtmIds.join(", ")}',
                        style: const TextStyle(
                          fontFamily: 'Google Sans',
                          color: Color(0xFFEE1C4B),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(now),
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Compact Transaction card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Helpers.isToday(_selectedDate)
                          ? (entryExists ? "Edit Today's Entry" : "Today's Entry")
                          : (entryExists ? "Edit Entry" : "New Entry"),
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryTextColor,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          Helpers.formatDate(_selectedDate),
                          style: const TextStyle(
                            fontFamily: 'Google Sans',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFFEE1C4B),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (!isMissingEntryMode)
                          IconButton(
                            icon: const Icon(Icons.date_range, color: Color(0xFFEE1C4B), size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _selectDate(context),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFFEE1C4B), size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              _resetInput();
                            },
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (isSelectedDateFuture) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEE1C4B).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEE1C4B).withValues(alpha: 0.15)),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 40,
                          color: Color(0xFFEE1C4B),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "You cannot create transaction entries for future dates.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEE1C4B),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  if (entryExists && !_isEditingExisting) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEE1C4B).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEE1C4B).withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 40,
                            color: Color(0xFFEE1C4B),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Transaction has already been recorded.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Google Sans',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onPressed: () {
                                    final record = existingRecord!;
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Transaction Details'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Date: ${Helpers.formatDate(record.date)}'),
                                            const SizedBox(height: 8),
                                            Text('Count: ${record.count}'),
                                            const SizedBox(height: 8),
                                            Text('Rate: ${Helpers.formatCurrency(record.rate, settings.currency)}'),
                                            const SizedBox(height: 8),
                                            Text('Total: ${Helpers.formatCurrency(record.total, settings.currency)}'),
                                            const SizedBox(height: 8),
                                            Text('Remarks: ${record.remarks?.isNotEmpty == true ? record.remarks : "-"}'),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.visibility_outlined, size: 16),
                                  label: const Text('View Entry', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onPressed: () {
                                    final record = existingRecord!;
                                    setState(() {
                                      _countController.text = record.count.toString();
                                      _remarksController.text = record.remarks ?? '';
                                      _useCustomRate = record.rate != settings.defaultRate;
                                      _rateController.text = record.rate.toString();
                                      _isEditingExisting = true;
                                    });
                                  },
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  label: const Text('Edit Entry', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _countController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Enter transaction count',
                        prefixIcon: Icon(Icons.numbers),
                        labelText: 'Transaction Count',
                      ),
                      onChanged: (val) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _remarksController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        hintText: 'Remarks (optional)',
                        prefixIcon: Icon(Icons.edit_note_outlined),
                        labelText: 'Remarks',
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Checkbox(
                          value: _useCustomRate,
                          activeColor: const Color(0xFFEE1C4B),
                          onChanged: (val) {
                            setState(() {
                              _useCustomRate = val ?? false;
                              if (!_useCustomRate) {
                                _rateController.text = settings.defaultRate.toString();
                              }
                            });
                          },
                        ),
                        const Text(
                          'Override Transaction Rate',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E1A4D),
                          ),
                        ),
                      ],
                    ),
                    if (_useCustomRate) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Custom Rate Amount',
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Expected Earnings:',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 13,
                            color: Color(0xFF525277),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          Helpers.formatCurrency(
                            ((int.tryParse(_countController.text) ?? 0) *
                                (_useCustomRate
                                    ? (double.tryParse(_rateController.text) ?? settings.defaultRate)
                                    : settings.defaultRate)).toDouble(),
                            settings.currency,
                          ),
                          style: const TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEE1C4B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _isEditingExisting
                                ? () => setState(() => _isEditingExisting = false)
                                : _resetInput,
                            child: Text(_isEditingExisting ? 'Cancel' : 'Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => _saveRecord(pendingList: pendingEntriesList),
                            child: Text(_isEditingExisting ? 'Update Entry' : 'Save Entry'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Motivational rotating card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _motivationalMessage,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quick Actions Section
          Text(
            'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickActionItem(
                context,
                label: 'Log ATM',
                icon: Icons.add_circle_outline,
                color: theme.colorScheme.primary,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const QuickLogSheet(),
                  );
                },
              ),
              _buildQuickActionItem(
                context,
                label: 'History',
                icon: Icons.history_toggle_off,
                color: theme.colorScheme.secondary,
                onTap: () {
                  ref.read(activeTabProvider.notifier).state = 1;
                },
              ),
              _buildQuickActionItem(
                context,
                label: 'Reports',
                icon: Icons.analytics_outlined,
                color: theme.colorScheme.tertiary,
                onTap: () {
                  ref.read(activeTabProvider.notifier).state = 2;
                },
              ),
              _buildQuickActionItem(
                context,
                label: 'Settings',
                icon: Icons.settings_outlined,
                color: Colors.blueGrey,
                onTap: () {
                  ref.read(activeTabProvider.notifier).state = 3;
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Dashboard Horizontal Stats Cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatCard('Current Streak', '$currentStreak days', Icons.electric_bolt, Colors.orange),
                _buildStatCard('Pending Log Tasks', '${pendingEntriesList.length}', Icons.pending_actions, Colors.red),
                _buildStatCard(
                  'Monthly Target',
                  '${(monthlyProgressPercent * 100).toStringAsFixed(0)}%',
                  Icons.golf_course,
                  Colors.blue,
                ),
                _buildStatCard('Registered ATMs', '${atms.length} units', Icons.atm, Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Missing Entries Notification Banner
          if (missingList.isNotEmpty) ...[
            Text(
              'Action Required',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red[600]),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[600]!.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red[600]!.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (missingCount == 1) ...[
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Missing Entry',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Helpers.formatDate(missingList.first['date'] as DateTime),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No transaction was recorded for ATM ${missingList.first['atmId']}.',
                      style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        final item = missingList.first;
                        ref.read(dashboardSelectedDateProvider.notifier).state = item['date'] as DateTime;
                        ref.read(dashboardSelectedAtmIdProvider.notifier).state = item['atmId'] as String;
                        ref.read(dashboardIsEditingExistingProvider.notifier).state = false;
                        ref.read(dashboardIsMissingEntryModeProvider.notifier).state = true;
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Enter Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '$missingCount Missing Entries',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: missingList.map((item) {
                        final pDate = item['date'] as DateTime;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${item['atmId']}: ${DateFormat('MMM d').format(pDate)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MissingEntriesScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Review Missing Entries', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Calendar View Header
          Text(
            'Calendar Log View',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          CustomCalendarWidget(
            records: records,
            nonWorkingDays: nonWorkingDays,
            registrationDateStr: regDateStr,
            onRecordsTapped: (dateRecords) {
              if (dateRecords.isNotEmpty) {
                final record = dateRecords.first;
                final settings = ref.read(settingsProvider);
                setState(() {
                  _selectedDate = record.date;
                  _selectedAtmId = record.atmId;
                  _countController.text = record.count.toString();
                  _remarksController.text = record.remarks ?? '';
                  _useCustomRate = record.rate != settings.defaultRate;
                  _rateController.text = record.rate.toString();
                  _isEditingExisting = true; // Directly open Edit mode!
                });
              }
            },
            onEmptyDateTapped: (date) {
              final settings = ref.read(settingsProvider);
              setState(() {
                _selectedDate = date;
                _countController.clear();
                _remarksController.clear();
                _useCustomRate = false;
                _rateController.text = settings.defaultRate.toString();
                _isEditingExisting = false; // New Entry mode
              });
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 150,
      height: 110,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              )
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
