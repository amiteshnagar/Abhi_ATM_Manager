import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction_record.dart';
import '../providers/auth_provider.dart';
import 'settings_screen.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/helpers.dart';
import '../database/db_helper.dart';
import '../widgets/reason_dialog.dart';
import '../widgets/loading_indicator.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isOperating = false;

  String _searchQuery = '';
  String? _selectedAtmFilter;
  int? _selectedYear;
  int? _selectedMonth;
  DateTimeRange? _selectedDateRange;

  // Sorting
  String _sortBy = 'date_desc'; // date_desc, date_asc, count_desc, count_asc, total_desc, total_asc

  // Pagination
  final int _pageSize = 15;
  int _visibleCount = 15;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      setState(() {
        _visibleCount += _pageSize;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedAtmFilter = null;
      _selectedYear = null;
      _selectedMonth = null;
      _selectedDateRange = null;
      _sortBy = 'date_desc';
      _visibleCount = _pageSize;
    });
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _selectedYear = null;
        _selectedMonth = null;
        _visibleCount = _pageSize;
      });
    }
  }

  Future<void> _editRecord(TransactionRecord record) async {
    final TextEditingController countEditController =
        TextEditingController(text: record.count.toString());
    final TextEditingController remarksEditController =
        TextEditingController(text: record.remarks ?? '');
    final TextEditingController rateEditController =
        TextEditingController(text: record.rate.toString());

    DateTime editDate = record.date;
    String editAtmId = record.atmId;

    final atms = ref.read(atmListProvider);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Log Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Date: ${Helpers.formatDate(editDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: editDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            editDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // ATM Selection Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: editAtmId,
                      decoration: const InputDecoration(
                        labelText: 'Select ATM Unit',
                        prefixIcon: Icon(Icons.atm),
                      ),
                      items: atms.map((atm) {
                        return DropdownMenuItem<String>(
                          value: atm['id'],
                          child: Text('${atm['id']} – ${atm['name']}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            editAtmId = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Transactions count
                    TextField(
                      controller: countEditController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Transactions Count',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Rate override
                    TextField(
                      controller: rateEditController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Applied Rate',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Remarks
                    TextField(
                      controller: remarksEditController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: 'Remarks',
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final count = int.tryParse(countEditController.text);
                    final rate = double.tryParse(rateEditController.text);
                    if (count == null || count < 0 || count > 1000) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter valid count (0-1000).')),
                      );
                      return;
                    }
                    if (rate == null || rate < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid rate.')),
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) async {
      if (result == true) {
        if (!mounted) return;
        final count = int.parse(countEditController.text);
        final rate = double.parse(rateEditController.text);
        final remarks = remarksEditController.text.trim();

        final updatedRecord = TransactionRecord.calculate(
          id: record.id,
          date: editDate,
          atmId: editAtmId,
          count: count,
          rate: rate,
          remarks: remarks,
        );

        final notifier = ref.read(transactionListProvider.notifier);
        final dateStr = DateFormat('yyyy-MM-dd').format(editDate);

        final reason = await showReasonDialog(
          context: context,
          title: 'Why are you updating this transaction?',
          labelText: 'Reason for Update',
          actionButtonText: 'Update Transaction',
        );
        if (reason == null) return; // User cancelled
        if (!mounted) return;

        final employee = await DBHelper().getEmployee();
        final employeeId = employee?['id'] as int? ?? 0;

        final auditData = {
          'transaction_id': record.id,
          'employee_id': employeeId,
          'date': record.dateString,
          'atm_id': record.atmId,
          'action': 'UPDATE',
          'previous_count': record.count,
          'new_count': updatedRecord.count,
          'previous_rate': record.rate,
          'new_rate': updatedRecord.rate,
          'previous_total': record.total,
          'new_total': updatedRecord.total,
          'previous_remarks': record.remarks,
          'new_remarks': updatedRecord.remarks,
          'reason': reason,
          'created_at': DateTime.now().toIso8601String(),
        };

        // Check duplicate if key details changed (date or ATM)
        final keysChanged = dateStr != record.dateString || editAtmId != record.atmId;
        if (keysChanged && notifier.doesRecordExist(dateStr, editAtmId)) {
          if (!mounted) return;
          final confirmOverwrite = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Date & ATM Conflict'),
              content: Text(
                'A record already exists for ${Helpers.formatDate(editDate)}. Do you want to overwrite it?',
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

          if (confirmOverwrite != true) return;
          if (!mounted) return;

          final targetRecord = notifier.getRecordByDateAndAtm(dateStr, editAtmId);
          if (targetRecord != null) {
            final targetAuditData = Map<String, dynamic>.from(auditData)
              ..['transaction_id'] = targetRecord.id
              ..['action'] = 'UPDATE';
            await notifier.updateTransactionWithAudit(updatedRecord.copyWith(id: targetRecord.id), targetAuditData);
          }
          final deleteAuditData = Map<String, dynamic>.from(auditData)
            ..['action'] = 'DELETE'
            ..['reason'] = 'Overwritten and merged into $editAtmId on $dateStr';
          await notifier.deleteTransactionWithAudit(record.id!, deleteAuditData);
        } else {
          try {
            await notifier.updateTransactionWithAudit(updatedRecord, auditData);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update transaction: $e')),
              );
            }
          }
        }
      }
    });
  }

  Future<void> _confirmDelete(TransactionRecord record) async {
    if (_isOperating) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Record'),
          content: Text(
            'Are you sure you want to delete the record for ${Helpers.formatDate(record.date)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (!mounted) return;
      final reason = await showReasonDialog(
        context: context,
        title: 'Reason for deletion:',
        labelText: 'Reason',
        actionButtonText: 'Delete Transaction',
      );
      if (reason == null) return; // User cancelled
      if (!mounted) return;

      setState(() {
        _isOperating = true;
      });

      try {
        final employee = await DBHelper().getEmployee();
        final employeeId = employee?['id'] as int? ?? 0;

        final auditData = {
          'transaction_id': record.id,
          'employee_id': employeeId,
          'date': record.dateString,
          'atm_id': record.atmId,
          'action': 'DELETE',
          'previous_count': record.count,
          'new_count': null,
          'previous_rate': record.rate,
          'new_rate': null,
          'previous_total': record.total,
          'new_total': null,
          'previous_remarks': record.remarks,
          'new_remarks': null,
          'reason': reason,
          'created_at': DateTime.now().toIso8601String(),
        };

        await ref.read(transactionListProvider.notifier).deleteTransactionWithAudit(record.id!, auditData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Record deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete transaction: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isOperating = false;
          });
        }
      }
    }
  }

  Future<void> _showTransactionDetails(TransactionRecord record) async {
    final settings = ref.read(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Transaction Details',
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Helpers.formatFullDate(record.date),
                style: const TextStyle(
                  fontFamily: 'Google Sans',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Color(0xFFEE1C4B),
                ),
              ),
              const SizedBox(height: 16),
              _detailRow('Transactions:', '${record.count}', primaryTextColor, secondaryTextColor),
              _detailRow('Rate:', Helpers.formatCurrency(record.rate, settings.currency), primaryTextColor, secondaryTextColor),
              _detailRow('Expected Earnings:', Helpers.formatCurrency(record.total, settings.currency), primaryTextColor, secondaryTextColor),
              if (record.remarks != null && record.remarks!.isNotEmpty)
                _detailRow('Remarks:', record.remarks!, primaryTextColor, secondaryTextColor),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: secondaryTextColor)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmDelete(record);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEE1C4B),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _editRecord(record);
              },
              child: const Text('Edit'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEE1C4B).withValues(alpha: 0.12),
                foregroundColor: const Color(0xFFEE1C4B),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showAuditHistory(record);
              },
              child: const Text('History'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value, Color pColor, Color sColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontWeight: FontWeight.w600,
              color: sColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontWeight: FontWeight.w500,
                color: pColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAuditHistory(TransactionRecord record) async {
    final notifier = ref.read(transactionListProvider.notifier);
    final audits = await notifier.getAuditHistory(record.id!);
    
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        final settings = ref.read(settingsProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
        final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);
        final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF7F7FA);
        final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit History - ${DateFormat('dd MMM').format(record.date)}',
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: audits.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      'No changes have been recorded for this transaction.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Google Sans', fontStyle: FontStyle.italic),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: audits.length,
                    itemBuilder: (context, index) {
                      final audit = audits[index];
                      final createdAt = DateTime.tryParse(audit['created_at'] ?? '') ?? DateTime.now();
                      final formattedTime = DateFormat('dd MMM yyyy • h:mm a').format(createdAt);

                      final prevCount = audit['previous_count'];
                      final newCount = audit['new_count'];
                      final prevRate = audit['previous_rate'];
                      final newRate = audit['new_rate'];
                      final prevTotal = audit['previous_total'];
                      final newTotal = audit['new_total'];
                      final prevRemarks = audit['previous_remarks'];
                      final newRemarks = audit['new_remarks'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedTime,
                              style: const TextStyle(
                                fontFamily: 'Google Sans',
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Color(0xFFEE1C4B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (prevCount != newCount)
                              _auditChangeRow('Transactions:', '$prevCount → $newCount', primaryTextColor, secondaryTextColor),
                            if (prevRate != newRate)
                              _auditChangeRow(
                                'Rate:',
                                '${prevRate != null ? Helpers.formatCurrency((prevRate as num).toDouble(), settings.currency) : '-'} → ${newRate != null ? Helpers.formatCurrency((newRate as num).toDouble(), settings.currency) : '-'}',
                                primaryTextColor,
                                secondaryTextColor,
                              ),
                            if (prevTotal != newTotal)
                              _auditChangeRow(
                                'Earnings:',
                                '${prevTotal != null ? Helpers.formatCurrency((prevTotal as num).toDouble(), settings.currency) : '-'} → ${newTotal != null ? Helpers.formatCurrency((newTotal as num).toDouble(), settings.currency) : '-'}',
                                primaryTextColor,
                                secondaryTextColor,
                              ),
                            if (prevRemarks != newRemarks)
                              _auditChangeRow('Remarks:', '${prevRemarks ?? "-"} → ${newRemarks ?? "-"}', primaryTextColor, secondaryTextColor),
                            const SizedBox(height: 6),
                            Text(
                              'Reason: ${audit['reason']}',
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Color(0xFFEE1C4B))),
            ),
          ],
        );
      },
    );
  }

  Widget _auditChangeRow(String label, String change, Color pColor, Color sColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: sColor,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              change,
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: pColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: cardBg,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final auth = ref.watch(authProvider);
            final atms = ref.watch(atmListProvider);
            final allRecords = ref.watch(transactionListProvider);
            final years = allRecords.map((r) => r.date.year).toSet().toList()..sort((a, b) => b.compareTo(a));
            if (!years.contains(DateTime.now().year)) {
              years.add(DateTime.now().year);
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter & Sort Records',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _clearFilters();
                            Navigator.pop(context);
                          },
                          child: const Text('Clear All', style: TextStyle(color: Color(0xFFEE1C4B))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ATM Unit Selector (only if multiple ATMs are assigned)
                    if (auth.assignedAtmIds.length > 1) ...[
                      Text('ATM Unit', style: TextStyle(fontFamily: 'Google Sans', fontSize: 12, fontWeight: FontWeight.bold, color: secondaryTextColor)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedAtmFilter,
                        hint: const Text('All ATMs'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: atms.map((atm) {
                          return DropdownMenuItem<String>(
                            value: atm['id'],
                            child: Text('${atm['id']} – ${atm['name']}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setModalState(() {
                            _selectedAtmFilter = val;
                          });
                          setState(() {
                            _selectedAtmFilter = val;
                            _visibleCount = _pageSize;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Year', style: TextStyle(fontFamily: 'Google Sans', fontSize: 12, fontWeight: FontWeight.bold, color: secondaryTextColor)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                initialValue: _selectedYear,
                                hint: const Text('All'),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: years.map((y) {
                                  return DropdownMenuItem<int>(
                                    value: y,
                                    child: Text('$y'),
                                  );
                                }).toList(),
                                onChanged: (y) {
                                  setModalState(() {
                                    _selectedYear = y;
                                  });
                                  setState(() {
                                    _selectedYear = y;
                                    _selectedDateRange = null;
                                    _visibleCount = _pageSize;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Month', style: TextStyle(fontFamily: 'Google Sans', fontSize: 12, fontWeight: FontWeight.bold, color: secondaryTextColor)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                initialValue: _selectedMonth,
                                hint: const Text('All'),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: List.generate(12, (index) => index + 1).map((m) {
                                  return DropdownMenuItem<int>(
                                    value: m,
                                    child: Text(DateFormat('MMM').format(DateTime(2020, m))),
                                  );
                                }).toList(),
                                onChanged: (m) {
                                  setModalState(() {
                                    _selectedMonth = m;
                                  });
                                  setState(() {
                                    _selectedMonth = m;
                                    _selectedDateRange = null;
                                    _visibleCount = _pageSize;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text('Sort By', style: TextStyle(fontFamily: 'Google Sans', fontSize: 12, fontWeight: FontWeight.bold, color: secondaryTextColor)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _sortBy,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'date_desc', child: Text('Date: Newest First')),
                        DropdownMenuItem(value: 'date_asc', child: Text('Date: Oldest First')),
                        DropdownMenuItem(value: 'count_desc', child: Text('Count: High to Low')),
                        DropdownMenuItem(value: 'count_asc', child: Text('Count: Low to High')),
                        DropdownMenuItem(value: 'total_desc', child: Text('Earnings: High to Low')),
                        DropdownMenuItem(value: 'total_asc', child: Text('Earnings: Low to High')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            _sortBy = val;
                          });
                          setState(() {
                            _sortBy = val;
                            _visibleCount = _pageSize;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEE1C4B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = ref.watch(authProvider);
    final settings = ref.watch(settingsProvider);
    final allRecords = ref.watch(transactionListProvider);

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    // Filters & Searches logic
    List<TransactionRecord> filteredRecords = List.from(allRecords);

    // Apply Search
    if (_searchQuery.isNotEmpty) {
      filteredRecords = filteredRecords.where((record) {
        final dateFormatted = Helpers.formatDate(record.date).toLowerCase();
        final remarksText = record.remarks?.toLowerCase() ?? '';
        final countText = record.count.toString();
        return dateFormatted.contains(_searchQuery) ||
            remarksText.contains(_searchQuery) ||
            countText.contains(_searchQuery);
      }).toList();
    }

    // Apply ATM filter
    if (_selectedAtmFilter != null) {
      filteredRecords = filteredRecords.where((record) => record.atmId == _selectedAtmFilter).toList();
    }

    // Apply Date Range
    if (_selectedDateRange != null) {
      filteredRecords = filteredRecords.where((record) {
        return record.date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
            record.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Apply Year
    if (_selectedYear != null) {
      filteredRecords = filteredRecords.where((record) => record.date.year == _selectedYear).toList();
    }

    // Apply Month
    if (_selectedMonth != null) {
      filteredRecords = filteredRecords.where((record) => record.date.month == _selectedMonth).toList();
    }

    // Apply Sorting
    switch (_sortBy) {
      case 'date_asc':
        filteredRecords.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'count_desc':
        filteredRecords.sort((a, b) => b.count.compareTo(a.count));
        break;
      case 'count_asc':
        filteredRecords.sort((a, b) => a.count.compareTo(b.count));
        break;
      case 'total_desc':
        filteredRecords.sort((a, b) => b.total.compareTo(a.total));
        break;
      case 'total_asc':
        filteredRecords.sort((a, b) => a.total.compareTo(b.total));
        break;
      case 'date_desc':
      default:
        filteredRecords.sort((a, b) => b.date.compareTo(a.date));
        break;
    }

    final int endIndex = _visibleCount < filteredRecords.length ? _visibleCount : filteredRecords.length;
    final List<TransactionRecord> pagedRecords = filteredRecords.sublist(0, endIndex);

    final hasActiveFilters = _selectedAtmFilter != null || _selectedYear != null || _selectedMonth != null || _sortBy != 'date_desc';
    int activeFiltersCount = 0;
    if (_selectedAtmFilter != null) activeFiltersCount++;
    if (_selectedYear != null) activeFiltersCount++;
    if (_selectedMonth != null) activeFiltersCount++;
    if (_sortBy != 'date_desc') activeFiltersCount++;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'History',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: Color(0xFF1E1A4D),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Your daily transaction records',
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
          if (_selectedMonth != null ||
              _selectedYear != null ||
              _selectedDateRange != null ||
              _searchQuery.isNotEmpty ||
              _selectedAtmFilter != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear Filters',
              onPressed: _clearFilters,
            ),
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
      body: Column(
        children: [
          // Filter Chips Panel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                // Search Input Field
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderCol),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                          _visibleCount = _pageSize;
                        });
                      },
                      style: TextStyle(fontSize: 13, color: primaryTextColor),
                      decoration: InputDecoration(
                        hintText: 'Search date, remarks...',
                        hintStyle: TextStyle(color: secondaryTextColor),
                        prefixIcon: Icon(Icons.search, size: 18, color: secondaryTextColor),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                child: Icon(Icons.clear, size: 16, color: secondaryTextColor),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Date Range Chip
                GestureDetector(
                  onTap: _pickDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedDateRange != null ? const Color(0xFFEE1C4B).withValues(alpha: 0.08) : cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedDateRange != null ? const Color(0xFFEE1C4B) : borderCol,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.date_range_outlined,
                          size: 14,
                          color: _selectedDateRange != null ? const Color(0xFFEE1C4B) : primaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedDateRange != null ? 'Date Active' : 'Date Range',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _selectedDateRange != null ? const Color(0xFFEE1C4B) : primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Filters Chip
                GestureDetector(
                  onTap: () => _showFilterBottomSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: hasActiveFilters ? const Color(0xFFEE1C4B).withValues(alpha: 0.08) : cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hasActiveFilters ? const Color(0xFFEE1C4B) : borderCol,
                      ),
                    ),
                    child: Text(
                      hasActiveFilters ? 'Filters ($activeFiltersCount) ▼' : 'Filters ▼',
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasActiveFilters ? const Color(0xFFEE1C4B) : primaryTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Paged List view
          Expanded(
            child: ref.watch(transactionListLoadingProvider)
                ? const LoadingIndicator(isFullPage: true, message: 'Loading history logs...')
                : pagedRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions yet',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your transaction records will appear here.',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: pagedRecords.length + (endIndex < filteredRecords.length ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == pagedRecords.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final record = pagedRecords[index];
                      final prevDateStr = index > 0 ? DateFormat('yyyy-MM-dd').format(pagedRecords[index - 1].date) : null;
                      final currentDateStr = DateFormat('yyyy-MM-dd').format(record.date);
                      final showHeader = prevDateStr != currentDateStr;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeader) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 14.0, bottom: 8.0, left: 4.0),
                              child: Text(
                                DateFormat('d MMMM yyyy').format(record.date).toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'Google Sans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: secondaryTextColor,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderCol),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.01),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () => _showTransactionDetails(record),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${record.count} Transactions',
                                          style: TextStyle(
                                            fontFamily: 'Google Sans',
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${Helpers.formatCurrency(record.total, settings.currency)} Earnings',
                                          style: TextStyle(
                                            fontFamily: 'Google Sans',
                                            fontSize: 13,
                                            color: secondaryTextColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Row(
                                          children: [
                                            Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Completed',
                                              style: TextStyle(
                                                fontFamily: 'Google Sans',
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: secondaryTextColor,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
