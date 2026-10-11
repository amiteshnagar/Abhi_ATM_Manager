import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/non_working_day.dart';
import '../providers/auth_provider.dart';
import '../providers/non_working_day_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/glass_card.dart';
import '../utils/helpers.dart';
import '../widgets/loading_indicator.dart';

class MissingEntriesScreen extends ConsumerStatefulWidget {
  const MissingEntriesScreen({super.key});

  @override
  ConsumerState<MissingEntriesScreen> createState() => _MissingEntriesScreenState();
}

class _MissingEntriesScreenState extends ConsumerState<MissingEntriesScreen> {
  final List<String> _reasons = [
    'ATM Maintenance',
    'ATM Unavailable',
    'Holiday',
    'Employee Not Working',
    'Other',
  ];

  Future<void> _markNotWorking(BuildContext context, DateTime date, String atmId) async {
    String selectedReason = _reasons.first;
    final remarksController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Mark as Not Working'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Was this ATM not operational/worked on this date (${Helpers.formatDate(date)})?',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Reason:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    ..._reasons.map((r) => RadioListTile<String>(
                          title: Text(r, style: const TextStyle(fontSize: 13)),
                          value: r,
                          groupValue: selectedReason,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                selectedReason = val;
                              });
                            }
                          },
                        )),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksController,
                      decoration: const InputDecoration(
                        labelText: 'Remarks (Optional)',
                        hintText: 'Enter specific details...',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      final nonWorkingDay = NonWorkingDay(
        date: date,
        atmId: atmId,
        reason: selectedReason,
        remarks: remarksController.text.trim().isNotEmpty ? remarksController.text.trim() : null,
        createdAt: DateTime.now(),
      );

      await ref.read(nonWorkingDayProvider.notifier).addNonWorkingDay(nonWorkingDay);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked ATM $atmId as non-operational on ${Helpers.formatDate(date)}.'),
        ),
      );
    }
  }

  void _enterNow(DateTime date, String atmId) {
    // Populate providers for dashboard selection
    ref.read(dashboardSelectedDateProvider.notifier).state = date;
    ref.read(dashboardSelectedAtmIdProvider.notifier).state = atmId;
    ref.read(dashboardIsEditingExistingProvider.notifier).state = false;
    ref.read(dashboardIsMissingEntryModeProvider.notifier).state = true;

    // Switch tab to Dashboard (0)
    ref.read(activeTabProvider.notifier).state = 0;

    // Navigate back to Main tab controller
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final auth = ref.watch(authProvider);
    final transactions = ref.watch(transactionListProvider);
    final nonWorkingDays = ref.watch(nonWorkingDayProvider);
    final prefs = ref.watch(sharedPreferencesProvider);

    final regDateStr = prefs.getString('registration_date') ?? '';

    // Logged sets
    final loggedSets = transactions.map((t) => '${t.atmId}_${t.dateString}').toSet();
    final nonWorkingSets = nonWorkingDays.map((n) => '${n.atmId}_${n.dateString}').toSet();

    final List<Map<String, dynamic>> missingList = Helpers.calculateMissingEntries(
      assignedAtmIds: auth.assignedAtmIds,
      regDateStr: regDateStr,
      loggedSets: loggedSets,
      nonWorkingSets: nonWorkingSets,
    );

    // Sort oldest first
    missingList.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Missing Entries'),
      ),
      body: ref.watch(transactionListLoadingProvider)
          ? const LoadingIndicator(isFullPage: true, message: 'Checking missing entries...')
          : missingList.isEmpty
              ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Missing Entries!',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are all caught up.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: missingList.length,
              itemBuilder: (context, index) {
                final item = missingList[index];
                final DateTime mDate = item['date'];
                final String mAtmId = item['atmId'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              Helpers.formatDate(mDate),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Missing',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ATM Unit: $mAtmId',
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _markNotWorking(context, mDate, mAtmId),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: BorderSide(color: theme.colorScheme.primary),
                                ),
                                child: const Text(
                                  'Mark Not Working',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _enterNow(mDate, mAtmId),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text(
                                  'Enter Now',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
