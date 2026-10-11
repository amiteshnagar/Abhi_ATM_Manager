import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction_record.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/helpers.dart';
import '../database/db_helper.dart';
import 'reason_dialog.dart';
import 'loading_indicator.dart';

class QuickLogSheet extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final String? initialAtmId;
  const QuickLogSheet({super.key, this.initialDate, this.initialAtmId});

  @override
  ConsumerState<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends ConsumerState<QuickLogSheet> {
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final FocusNode _countFocusNode = FocusNode();

  late DateTime _selectedDate;
  String? _selectedAtmId;
  bool _useCustomRate = false;
  bool _isSaved = false;
  bool _dismissed = false;
  bool _isLoading = false;
  int _savedCount = 0;
  double _savedEarnings = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedAtmId = widget.initialAtmId;
    _countController.addListener(_calculateLiveEarnings);
    _rateController.addListener(_calculateLiveEarnings);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      _rateController.text = settings.defaultRate.toString();
      final atms = ref.read(atmListProvider);
      final auth = ref.read(authProvider);
      if (auth.assignedAtmIds.length == 1) {
        setState(() {
          _selectedAtmId = auth.assignedAtmIds.first;
        });
      } else if (_selectedAtmId == null && atms.isNotEmpty) {
        setState(() {
          _selectedAtmId = atms.first['id'];
        });
      }
      _countFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _countController.removeListener(_calculateLiveEarnings);
    _rateController.removeListener(_calculateLiveEarnings);
    _countController.dispose();
    _remarksController.dispose();
    _rateController.dispose();
    _countFocusNode.dispose();
    super.dispose();
  }

  void _calculateLiveEarnings() {
    setState(() {});
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(DateTime.now()) ? DateTime.now() : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveRecord() async {
    if (_isLoading) return;

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

    setState(() {
      _isLoading = true;
    });

    try {
      final rateVal = double.tryParse(_rateController.text) ?? 0.0;
      final notifier = ref.read(transactionListProvider.notifier);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final record = TransactionRecord.calculate(
        date: _selectedDate,
        atmId: _selectedAtmId!,
        count: count,
        rate: rateVal,
        remarks: _remarksController.text.trim(),
      );

      if (notifier.doesRecordExist(dateStr, _selectedAtmId!)) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Duplicate Record'),
            content: Text(
              'A transaction record already exists for ${Helpers.formatDate(_selectedDate)}. Do you want to edit/overwrite it?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Overwrite'),
              ),
            ],
          ),
        );

        if (confirm != true) return;
        if (!mounted) return;
        
        final reason = await showReasonDialog(
          context: context,
          title: 'Why are you updating this transaction?',
          labelText: 'Reason for Update',
          actionButtonText: 'Update Transaction',
        );
        if (reason == null) return; // User cancelled
        if (!mounted) return;

        final existing = notifier.getRecordByDateAndAtm(dateStr, _selectedAtmId!);
        if (existing != null) {
          final recordWithId = record.copyWith(id: existing.id);
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
            await notifier.updateTransactionWithAudit(recordWithId, auditData);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update transaction: $e')),
              );
            }
            return;
          }
        }
      } else {
        await notifier.saveTransaction(record);
      }

      if (mounted) {
        setState(() {
          _isSaved = true;
          _savedCount = count;
          _savedEarnings = count * rateVal;
          _dismissed = false;
        });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted && !_dismissed) {
          _dismissed = true;
          Navigator.pop(context, true);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final isDark = theme.brightness == Brightness.dark;

    if (_isSaved) {
      return GestureDetector(
        onTap: () {
          if (!_dismissed) {
            _dismissed = true;
            Navigator.pop(context, true);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFFEE1C4B),
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Entry Saved',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Google Sans',
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E1A4D),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF7F7FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '$_savedCount Transactions',
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E1A4D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Helpers.formatCurrency(_savedEarnings, settings.currency)} Earnings',
                      style: const TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEE1C4B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tap anywhere to dismiss',
                style: TextStyle(
                  fontFamily: 'Google Sans',
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    final records = ref.watch(transactionListProvider);
    TransactionRecord? existingRecord;
    if (_selectedAtmId != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      for (final r in records) {
        if (r.dateString == dateStr && r.atmId == _selectedAtmId) {
          existingRecord = r;
          break;
        }
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Log ATM Transaction',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        Helpers.formatDate(_selectedDate),
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.date_range),
                    onPressed: () => _selectDate(context),
                  ),
                ],
              ),
              if (existingRecord != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEE1C4B).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEE1C4B).withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 16, color: Color(0xFFEE1C4B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Last saved: ${existingRecord.count} transactions (${Helpers.formatCurrency(existingRecord.total, settings.currency)})",
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1E1A4D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _countController,
                focusNode: _countFocusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Enter transaction count',
                  prefixIcon: Icon(Icons.numbers),
                  labelText: 'Count (0 - 1000)',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _remarksController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  hintText: 'Any specific remarks/notes (optional)',
                  prefixIcon: Icon(Icons.edit_note_outlined),
                  labelText: 'Remarks',
                ),
              ),
              const SizedBox(height: 16),
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
                  Text(
                    'Override Default Transaction Rate',
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E1A4D),
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
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Expected Earnings:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'Google Sans',
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEE1C4B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _countController.clear();
                        _remarksController.clear();
                        setState(() {
                          _useCustomRate = false;
                          _rateController.text = settings.defaultRate.toString();
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveRecord,
                      child: _isLoading
                          ? const LoadingIndicator(isCompact: true)
                          : const Text('Save Record'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
