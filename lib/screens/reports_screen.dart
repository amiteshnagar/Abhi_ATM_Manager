import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction_record.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/backup_service.dart';
import '../utils/helpers.dart';
import '../widgets/chart_widgets.dart';
import '../widgets/loading_indicator.dart';
import 'settings_screen.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isMonthly = true;
  DateTime? _selectedMonth;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String? _exportingType;

  Widget _buildReportCard(BuildContext context, String title, String value, String sub, Color accentColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.01),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: secondaryTextColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  void _exportFilteredPDF(BuildContext context, WidgetRef ref, List<TransactionRecord> filteredRecords, String type, String periodRange) async {
    if (filteredRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No transaction logs for $type report.')),
      );
      return;
    }
    if (_exportingType != null) return;
    setState(() {
      _exportingType = 'pdf';
    });
    try {
      final settings = ref.read(settingsProvider);
      final auth = ref.read(authProvider);
      final backupService = BackupService();
      await backupService.exportToPDF(
        filteredRecords,
        settings.currency,
        auth.employeeName ?? 'Default Employee',
        reportType: type,
        periodRange: periodRange,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportingType = null;
        });
      }
    }
  }

  void _exportCSV(BuildContext context, WidgetRef ref, List<TransactionRecord> records, String fileName) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transaction logs to export.')),
      );
      return;
    }
    if (_exportingType != null) return;
    setState(() {
      _exportingType = 'csv';
    });
    try {
      final settings = ref.read(settingsProvider);
      final backupService = BackupService();
      await backupService.exportToCSV(records, settings.currency, fileName: fileName);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export CSV: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportingType = null;
        });
      }
    }
  }

  void _exportExcel(BuildContext context, WidgetRef ref, List<TransactionRecord> records, String fileName) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transaction logs to export.')),
      );
      return;
    }
    if (_exportingType != null) return;
    setState(() {
      _exportingType = 'excel';
    });
    try {
      final settings = ref.read(settingsProvider);
      final backupService = BackupService();
      await backupService.exportToExcel(records, settings.currency, fileName: fileName);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export Excel: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportingType = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final WidgetRef ref = this.ref;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final records = ref.watch(transactionListProvider);
    final auth = ref.watch(authProvider);

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (ref.watch(transactionListLoadingProvider)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reports & Analytics'),
        ),
        body: const LoadingIndicator(isFullPage: true, message: 'Loading report analytics...'),
      );
    }

    if (records.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reports & Analytics'),
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No report data yet',
                style: TextStyle(
                  fontFamily: 'Google Sans',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Start recording transactions to see your performance here.',
                style: TextStyle(
                  fontFamily: 'Google Sans',
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();

    // Generate monthly dynamically from existing transaction records
    final List<DateTime> availableMonths = [];
    final Set<String> seenMonths = {};
    for (var r in records) {
      final date = r.date;
      final key = DateFormat('yyyy-MM').format(date);
      if (!seenMonths.contains(key)) {
        seenMonths.add(key);
        availableMonths.add(DateTime(date.year, date.month, 1));
      }
    }
    availableMonths.sort((a, b) => b.compareTo(a));
    if (availableMonths.isEmpty) {
      availableMonths.add(DateTime(now.year, now.month, 1));
    }

    _selectedMonth ??= availableMonths.first;
    _customStartDate ??= DateTime(now.year, now.month, 1);
    _customEndDate ??= now;

    DateTime startDate;
    DateTime endDate;
    String periodRangeLabel;
    String reportTitle;
    String fileBaseName;

    if (_isMonthly) {
      final selectedMonth = _selectedMonth ?? DateTime(now.year, now.month, 1);
      startDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
      endDate = DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);
      periodRangeLabel = '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
      reportTitle = '${DateFormat('MMMM yyyy').format(startDate)} Transaction Report';
      fileBaseName = 'abhi_atm_report_${DateFormat('MMMM_yyyy').format(startDate)}';
    } else {
      final sDate = _customStartDate ?? now;
      final eDate = _customEndDate ?? now;
      startDate = DateTime(sDate.year, sDate.month, sDate.day, 0, 0, 0);
      endDate = DateTime(eDate.year, eDate.month, eDate.day, 23, 59, 59);
      periodRangeLabel = '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
      reportTitle = '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)} Transaction Report';
      fileBaseName = 'abhi_atm_report_${DateFormat('dd_MMM_yyyy').format(startDate)}_to_${DateFormat('dd_MMM_yyyy').format(endDate)}';
    }

    final filteredRecords = records.where((r) {
      return r.date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
             r.date.isBefore(endDate.add(const Duration(seconds: 1)));
    }).toList();

    final int filteredTotalCount = filteredRecords.fold(0, (sum, r) => sum + r.count);
    final double filteredTotalEarnings = filteredRecords.fold(0.0, (sum, r) => sum + r.total);
    final int filteredLoggingDays = filteredRecords.map((r) => r.dateString).toSet().length;

    final bool isDateRangeInvalid = !_isMonthly && _customStartDate != null && _customEndDate != null && _customStartDate!.isAfter(_customEndDate!);

    // 1. Basic Ranges Calculations
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final todayRecords = records.where((r) => r.dateString == todayStr).toList();
    final double todayEarnings = todayRecords.fold(0.0, (sum, r) => sum + r.total);
    final int todayCount = todayRecords.fold(0, (sum, r) => sum + r.count);

    final weekRecords = records.where((r) => Helpers.isThisWeek(r.date)).toList();
    final double weekEarnings = weekRecords.fold(0.0, (sum, r) => sum + r.total);
    final int weekCount = weekRecords.fold(0, (sum, r) => sum + r.count);

    final monthRecords = records.where((r) => Helpers.isThisMonth(r.date)).toList();
    final double monthEarnings = monthRecords.fold(0.0, (sum, r) => sum + r.total);
    final int monthCount = monthRecords.fold(0, (sum, r) => sum + r.count);

    final yearRecords = records.where((r) => Helpers.isThisYear(r.date)).toList();
    final double yearEarnings = yearRecords.fold(0.0, (sum, r) => sum + r.total);
    final int yearCount = yearRecords.fold(0, (sum, r) => sum + r.count);

    final int totalTransactions = records.fold(0, (sum, r) => sum + r.count);
    final double totalEarnings = records.fold(0.0, (sum, r) => sum + r.total);
    final int workingDays = records.map((r) => r.dateString).toSet().length;

    // 2. Advanced Statistics & Grouped Calculations
    // 2a. Current Logging Streak (matching dashboard)
    final loggedDates = records.map((r) => r.dateString).toSet();
    int currentStreak = 0;
    DateTime checkDate = DateTime.now();
    while (true) {
      final dateStr = DateFormat('yyyy-MM-dd').format(checkDate);
      if (loggedDates.contains(dateStr)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        if (currentStreak == 0 && checkDate.day == DateTime.now().day) {
          checkDate = checkDate.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
    }

    // 2b. Best Performance Day (Grouped by date, earnings basis, count tie-breaker)
    final Map<String, List<TransactionRecord>> recordsByDate = {};
    for (var r in records) {
      recordsByDate.putIfAbsent(r.dateString, () => []).add(r);
    }
    String? bestDateStr;
    int bestCount = 0;
    double bestEarnings = 0.0;

    recordsByDate.forEach((dateStr, list) {
      int dayCount = list.fold(0, (sum, r) => sum + r.count);
      double dayEarnings = list.fold(0.0, (sum, r) => sum + r.total);
      if (bestDateStr == null) {
        bestDateStr = dateStr;
        bestCount = dayCount;
        bestEarnings = dayEarnings;
      } else {
        if (dayEarnings > bestEarnings) {
          bestEarnings = dayEarnings;
          bestCount = dayCount;
          bestDateStr = dateStr;
        } else if (dayEarnings == bestEarnings) {
          if (dayCount > bestCount) {
            bestEarnings = dayEarnings;
            bestCount = dayCount;
            bestDateStr = dateStr;
          }
        }
      }
    });
    final DateTime? bestDate = bestDateStr != null ? DateTime.parse(bestDateStr!) : null;

    // 2c. Monthly Goal Projection
    final prefs = ref.watch(sharedPreferencesProvider);
    final double monthlyGoal = prefs.getDouble('monthly_earnings_goal') ?? 30000.0;
    final int daysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
    final int elapsedDays = now.day;
    final double projectedEarnings = elapsedDays > 0 ? (monthEarnings / elapsedDays) * daysInCurrentMonth : 0.0;
    final bool hasEnoughProjectionData = monthRecords.isNotEmpty && elapsedDays > 0;

    // 2d. Period Comparison (MoM)
    final prevMonthStart = DateTime(now.year, now.month - 1, 1);
    final prevMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
    final prevMonthRecords = records.where((r) => r.date.isAfter(prevMonthStart.subtract(const Duration(seconds: 1))) && r.date.isBefore(prevMonthEnd.add(const Duration(seconds: 1)))).toList();
    final double prevMonthEarnings = prevMonthRecords.fold(0.0, (sum, r) => sum + r.total);
    double percentChange = 0.0;
    final bool hasPrevPeriodBaseline = prevMonthRecords.isNotEmpty && prevMonthEarnings > 0;
    if (hasPrevPeriodBaseline) {
      percentChange = ((monthEarnings - prevMonthEarnings) / prevMonthEarnings) * 100;
    }

    // 2e. Smart Insights Generation
    final List<String> insights = [];
    if (records.isNotEmpty) {
      if (bestDate != null) {
        insights.add('Your highest performing day was ${DateFormat('EEEE, d MMMM yyyy').format(bestDate)} with ${Helpers.formatCurrency(bestEarnings, settings.currency)}.');
      }
      if (currentStreak >= 3) {
        insights.add('Keep it up! You are on a $currentStreak-day consecutive logging streak.');
      } else {
        insights.add('Log your transaction entries consistently every day to build a performance streak.');
      }
      if (hasEnoughProjectionData) {
        if (projectedEarnings >= monthlyGoal) {
          insights.add('You are currently on track to reach or exceed your monthly earnings goal.');
        } else {
          insights.add('Increase daily logging volume or select higher-rate shifts to stay on track for your goal.');
        }
      }
      if (hasPrevPeriodBaseline) {
        if (percentChange > 0) {
          insights.add('Your monthly earnings have increased by ${percentChange.toStringAsFixed(1)}% compared with the previous month.');
        } else if (percentChange < 0) {
          insights.add('Monthly earnings are down by ${percentChange.abs().toStringAsFixed(1)}% compared with the previous month.');
        }
      }
    }

    final double avgDailyCount = workingDays > 0 ? totalTransactions / workingDays : 0.0;
    final double avgDailyEarnings = workingDays > 0 ? totalEarnings / workingDays : 0.0;

    // Grouping by Month for Monthly summary
    final Map<String, double> monthlyEarningsMap = {};
    for (var r in records) {
      final monthName = DateFormat('MMMM yyyy').format(r.date);
      monthlyEarningsMap[monthName] = (monthlyEarningsMap[monthName] ?? 0.0) + r.total;
    }

    // Grouping by ATM ID for statistics
    final Map<String, double> atmEarningsMap = {};
    for (var r in records) {
      atmEarningsMap[r.atmId] = (atmEarningsMap[r.atmId] ?? 0.0) + r.total;
    }

    // 3. Chart Data Generation
    final last7Logs = records.take(7).toList().reversed.toList();
    final List<double> dailyEarningsData = last7Logs.map((r) => r.total).toList();
    final List<String> dailyEarningsLabels = last7Logs.map((r) => DateFormat('E').format(r.date)).toList();

    final List<double> last6MonthsData = [];
    final List<String> last6MonthsLabels = [];
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthStr = DateFormat('yyyy-MM').format(date);
      final monthLabel = DateFormat('MMM').format(date);
      
      final sum = records
          .where((r) => DateFormat('yyyy-MM').format(r.date) == monthStr)
          .fold(0.0, (s, r) => s + r.total);
      
      last6MonthsData.add(sum);
      last6MonthsLabels.add(monthLabel);
    }

    final List<double> last4WeeksData = [];
    final List<String> last4WeeksLabels = [];
    for (int i = 3; i >= 0; i--) {
      final start = DateTime.now().subtract(Duration(days: now.weekday - 1 + (i * 7)));
      final end = start.add(const Duration(days: 6, hours: 23, minutes: 59));
      
      final sum = records
          .where((r) => r.date.isAfter(start.subtract(const Duration(seconds: 1))) && r.date.isBefore(end.add(const Duration(seconds: 1))))
          .fold(0.0, (s, r) => s + r.total);
      
      last4WeeksData.add(sum);
      last4WeeksLabels.add('Wk ${4 - i}');
    }

    final last10Logs = records.take(10).toList().reversed.toList();
    final List<double> txTrendData = last10Logs.map((r) => r.count.toDouble()).toList();
    final List<String> txTrendLabels = last10Logs.map((r) => DateFormat('d/M').format(r.date)).toList();

    // Assigned ATM Details
    final assignedNames = auth.assignedAtmIds.map((id) {
      final atm = ref.watch(atmListProvider).firstWhere((a) => a['id'] == id, orElse: () => {'name': ''});
      return "$id • ${atm['name']}";
    }).join(", ");

    final currentMonthLabel = DateFormat('MMMM yyyy').format(now);

    // Monthly Earnings Goal calculations
    final progressPercent = monthlyGoal > 0 ? (monthEarnings / monthlyGoal) * 100 : 0.0;
    final progressFraction = (progressPercent / 100).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: Color(0xFF1E1A4D),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Track your performance and earnings',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontWeight: FontWeight.w400,
                fontSize: 12,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ATM Info and read-only Period Selector
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ASSIGNED ATM',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: secondaryTextColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          assignedNames.isNotEmpty ? assignedNames : 'No ATM Assigned',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 32,
                    width: 1,
                    color: borderColor,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'REPORT PERIOD',
                        style: TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: secondaryTextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFFEE1C4B)),
                          const SizedBox(width: 4),
                          Text(
                            currentMonthLabel,
                            style: const TextStyle(
                              fontFamily: 'Google Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEE1C4B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Summaries Grid (KPI Cards)
            Text(
              'Earnings Summary',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _buildReportCard(context, 'Today', Helpers.formatCurrency(todayEarnings, settings.currency), '$todayCount Trans', const Color(0xFFEE1C4B)),
                _buildReportCard(context, 'This Week', Helpers.formatCurrency(weekEarnings, settings.currency), '$weekCount Trans', const Color(0xFFEE1C4B)),
                _buildReportCard(context, 'This Month', Helpers.formatCurrency(monthEarnings, settings.currency), '$monthCount Trans', const Color(0xFFEE1C4B)),
                _buildReportCard(context, 'This Year', Helpers.formatCurrency(yearEarnings, settings.currency), '$yearCount Trans', const Color(0xFFEE1C4B)),
              ],
            ),
            const SizedBox(height: 20),

            // Performance / Goal Summary Card
            Text(
              'Goal Performance',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Earnings Goal',
                        style: TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: secondaryTextColor,
                        ),
                      ),
                      Text(
                        '${progressPercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEE1C4B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressFraction,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF7F7FA),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEE1C4B)),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Earned: ${Helpers.formatCurrency(monthEarnings, settings.currency)}',
                        style: TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Goal: ${Helpers.formatCurrency(monthlyGoal, settings.currency)}',
                        style: TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Advanced Performance Overview
            Text(
              'Advanced Performance Overview',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AVG DAILY TRANSACTIONS',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          avgDailyCount.toStringAsFixed(1),
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'transactions / day',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 10,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AVG DAILY EARNINGS',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          Helpers.formatCurrency(avgDailyEarnings, settings.currency),
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'earnings / day',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 10,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Color(0xFFEE1C4B), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOGGING CONSISTENCY',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$currentStreak Days Logging Streak',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Best Performance Day
            Text(
              'Best Performance Day',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: bestDate != null
                  ? Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEE1C4B).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emoji_events,
                            color: Color(0xFFEE1C4B),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('d MMM yyyy').format(bestDate).toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'Google Sans',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: secondaryTextColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEEE').format(bestDate),
                                style: TextStyle(
                                  fontFamily: 'Google Sans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.functions, size: 14, color: secondaryTextColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$bestCount Transactions',
                                    style: TextStyle(
                                      fontFamily: 'Google Sans',
                                      fontSize: 12,
                                      color: secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.currency_rupee, size: 14, color: secondaryTextColor),
                                  const SizedBox(width: 2),
                                  Text(
                                    Helpers.formatCurrency(bestEarnings, settings.currency),
                                    style: TextStyle(
                                      fontFamily: 'Google Sans',
                                      fontSize: 12,
                                      color: secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        'No record data available',
                        style: TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // Performance Trend
            Text(
              'Performance Trend',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    hasPrevPeriodBaseline
                        ? (percentChange >= 0 ? Icons.trending_up : Icons.trending_down)
                        : Icons.show_chart,
                    color: hasPrevPeriodBaseline
                        ? (percentChange >= 0 ? Colors.green[600] : const Color(0xFFEE1C4B))
                        : secondaryTextColor,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MONTH-OVER-MONTH COMPARISON',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: secondaryTextColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (hasPrevPeriodBaseline) ...[
                          Text(
                            '${percentChange >= 0 ? '↑' : '↓'} ${percentChange.abs().toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontFamily: 'Google Sans',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: percentChange >= 0 ? Colors.green[600] : const Color(0xFFEE1C4B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Compared with previous month (${Helpers.formatCurrency(prevMonthEarnings, settings.currency)})',
                            style: TextStyle(
                              fontFamily: 'Google Sans',
                              fontSize: 11,
                              color: secondaryTextColor,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Not enough historical data',
                            style: TextStyle(
                              fontFamily: 'Google Sans',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Comparison baseline requires logs from the previous month.',
                            style: TextStyle(
                              fontFamily: 'Google Sans',
                              fontSize: 10,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Daily Earnings Line Chart
            Text(
              'Daily Earnings Trend (Last 7 Days)',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8, right: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: SizedBox(
                height: 200,
                child: CustomLineChart(
                  data: dailyEarningsData,
                  labels: dailyEarningsLabels,
                  valPrefix: settings.currency,
                  lineColor: const Color(0xFFEE1C4B),
                  fillColor: const Color(0xFFEE1C4B).withValues(alpha: 0.06),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Transaction Trends Line Chart
            Text(
              'Transaction Volume Trend (Last 10 Days)',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8, right: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: SizedBox(
                height: 200,
                child: CustomLineChart(
                  data: txTrendData,
                  labels: txTrendLabels,
                  lineColor: const Color(0xFFEE1C4B),
                  fillColor: const Color(0xFFEE1C4B).withValues(alpha: 0.06),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Weekly Comparison Chart
            Text(
              'Weekly Earnings Comparison (Last 4 Weeks)',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8, right: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: SizedBox(
                height: 200,
                child: CustomBarChart(
                  data: last4WeeksData,
                  labels: last4WeeksLabels,
                  valPrefix: settings.currency,
                  barColor: const Color(0xFF525277),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Monthly Earnings Bar Chart
            Text(
              'Monthly Earnings (Last 6 Months)',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8, right: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: SizedBox(
                height: 200,
                child: CustomBarChart(
                  data: last6MonthsData,
                  labels: last6MonthsLabels,
                  valPrefix: settings.currency,
                  barColor: const Color(0xFFEE1C4B),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Goal Projection
            Text(
              'Goal Projection',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasEnoughProjectionData) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Projected Monthly Earnings',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: secondaryTextColor,
                          ),
                        ),
                        Text(
                          Helpers.formatCurrency(projectedEarnings, settings.currency),
                          style: const TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEE1C4B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      projectedEarnings >= monthlyGoal
                          ? 'On track to reach your monthly goal!'
                          : 'Behind pace to reach your goal.',
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: projectedEarnings >= monthlyGoal ? Colors.green[600] : const Color(0xFFEE1C4B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pacing calculation basis: Earned so far ÷ $elapsedDays days elapsed × $daysInCurrentMonth days in month.',
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 9,
                        color: secondaryTextColor,
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: secondaryTextColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Not enough data for projection. Log at least one transaction in the current month.',
                            style: TextStyle(
                              fontFamily: 'Google Sans',
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Performance Insights
            if (insights.isNotEmpty) ...[
              Text(
                'Performance Insights',
                style: TextStyle(
                  fontFamily: 'Google Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: insights.map((insight) {
                    final isFirst = insights.indexOf(insight) == 0;
                    return Padding(
                      padding: EdgeInsets.only(top: isFirst ? 0.0 : 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            child: const Icon(
                              Icons.insights,
                              color: Color(0xFFEE1C4B),
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              insight,
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 12,
                                color: primaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            // Generate & Export Report
            Text(
              'Generate & Export Report',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isMonthly = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isMonthly ? const Color(0xFFEE1C4B) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _isMonthly ? const Color(0xFFEE1C4B) : borderColor),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Monthly Report',
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _isMonthly ? Colors.white : secondaryTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isMonthly = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isMonthly ? const Color(0xFFEE1C4B) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: !_isMonthly ? const Color(0xFFEE1C4B) : borderColor),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Custom Range',
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: !_isMonthly ? Colors.white : secondaryTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isMonthly) ...[
                    DropdownButtonFormField<DateTime>(
                      initialValue: _selectedMonth,
                      decoration: InputDecoration(
                        labelText: 'Select Month',
                        labelStyle: TextStyle(color: secondaryTextColor, fontSize: 12, fontFamily: 'Google Sans'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFEE1C4B)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      dropdownColor: cardBg,
                      items: availableMonths.map((date) {
                        return DropdownMenuItem<DateTime>(
                          value: date,
                          child: Text(
                            DateFormat('MMMM yyyy').format(date),
                            style: TextStyle(color: primaryTextColor, fontFamily: 'Google Sans', fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedMonth = val;
                          });
                        }
                      },
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _customStartDate ?? now,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  _customStartDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FROM DATE',
                                    style: TextStyle(fontFamily: 'Google Sans', fontSize: 9, fontWeight: FontWeight.bold, color: secondaryTextColor),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _customStartDate != null ? DateFormat('dd MMM yyyy').format(_customStartDate!) : 'Select Date',
                                    style: TextStyle(fontFamily: 'Google Sans', fontSize: 12, fontWeight: FontWeight.bold, color: primaryTextColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _customEndDate ?? now,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  _customEndDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TO DATE',
                                    style: TextStyle(fontFamily: 'Google Sans', fontSize: 9, fontWeight: FontWeight.bold, color: secondaryTextColor),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _customEndDate != null ? DateFormat('dd MMM yyyy').format(_customEndDate!) : 'Select Date',
                                    style: TextStyle(fontFamily: 'Google Sans', fontSize: 12, fontWeight: FontWeight.bold, color: primaryTextColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isDateRangeInvalid)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Start date cannot be after end date.',
                          style: const TextStyle(fontFamily: 'Google Sans', fontSize: 11, color: Color(0xFFEE1C4B), fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Report Preview
            Text(
              'Report Preview',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REPORT PERIOD',
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: secondaryTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isMonthly
                        ? DateFormat('MMMM yyyy').format(startDate)
                        : periodRangeLabel,
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEE1C4B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (filteredRecords.isEmpty && !isDateRangeInvalid) ...[
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: secondaryTextColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No transactions found for selected period.',
                            style: TextStyle(
                              fontFamily: 'Google Sans',
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$filteredLoggingDays Logging Days',
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total active days',
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 10,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '$filteredTotalCount Transactions',
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total count',
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 10,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Helpers.formatCurrency(filteredTotalEarnings, settings.currency),
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total earnings',
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 10,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Export Actions
            Text(
              'Export Report',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEE1C4B),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark ? const Color(0xFF334155) : Colors.grey[300],
                      disabledForegroundColor: isDark ? Colors.grey[600] : Colors.grey[500],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _exportingType == 'pdf'
                        ? const LoadingIndicator(isCompact: true)
                        : const Icon(Icons.picture_as_pdf, size: 16),
                    label: Text(
                      _exportingType == 'pdf' ? 'Loading' : 'PDF',
                      style: const TextStyle(fontFamily: 'Google Sans', fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: (filteredRecords.isEmpty || isDateRangeInvalid || _exportingType != null)
                        ? null
                        : () => _exportFilteredPDF(context, ref, filteredRecords, reportTitle, periodRangeLabel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark ? const Color(0xFF334155) : Colors.grey[300],
                      disabledForegroundColor: isDark ? Colors.grey[600] : Colors.grey[500],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _exportingType == 'csv'
                        ? const LoadingIndicator(isCompact: true)
                        : const Icon(Icons.description, size: 16),
                    label: Text(
                      _exportingType == 'csv' ? 'Loading' : 'CSV',
                      style: const TextStyle(fontFamily: 'Google Sans', fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: (filteredRecords.isEmpty || isDateRangeInvalid || _exportingType != null)
                        ? null
                        : () => _exportCSV(context, ref, filteredRecords, fileBaseName),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark ? const Color(0xFF334155) : Colors.grey[300],
                      disabledForegroundColor: isDark ? Colors.grey[600] : Colors.grey[500],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _exportingType == 'excel'
                        ? const LoadingIndicator(isCompact: true)
                        : const Icon(Icons.table_chart, size: 16),
                    label: Text(
                      _exportingType == 'excel' ? 'Loading' : 'Excel',
                      style: const TextStyle(fontFamily: 'Google Sans', fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: (filteredRecords.isEmpty || isDateRangeInvalid || _exportingType != null)
                        ? null
                        : () => _exportExcel(context, ref, filteredRecords, fileBaseName),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ATM Breakdown
            Text(
              'Earnings by ATM Unit',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: atmEarningsMap.length,
                itemBuilder: (context, index) {
                  final key = atmEarningsMap.keys.elementAt(index);
                  final earnings = atmEarningsMap[key]!;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(key, style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, color: primaryTextColor, fontSize: 13)),
                    trailing: Text(
                      Helpers.formatCurrency(earnings, settings.currency),
                      style: const TextStyle(
                        fontFamily: 'Google Sans',
                        color: Color(0xFFEE1C4B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Monthly Breakdown List
            Text(
              'Monthly Earnings Breakdown',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: monthlyEarningsMap.length,
                itemBuilder: (context, index) {
                  final key = monthlyEarningsMap.keys.elementAt(index);
                  final earnings = monthlyEarningsMap[key]!;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(key, style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, color: primaryTextColor, fontSize: 13)),
                    trailing: Text(
                      Helpers.formatCurrency(earnings, settings.currency),
                      style: const TextStyle(
                        fontFamily: 'Google Sans',
                        color: Color(0xFFEE1C4B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),

            // Branded Footer Credits
            Center(
              child: Column(
                children: [
                  Text(
                    'Generated by Abhi ATM Manager',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Designed & Developed with ❤️ by Amitesh Nagar',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '© 2026 All Rights Reserved.',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 8, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
