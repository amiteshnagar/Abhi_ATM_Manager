import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_record.dart';
import '../models/non_working_day.dart';

class CustomCalendarWidget extends StatefulWidget {
  final List<TransactionRecord> records;
  final List<NonWorkingDay> nonWorkingDays;
  final String registrationDateStr;
  final Function(List<TransactionRecord>) onRecordsTapped; // Updated to support list of records
  final Function(DateTime) onEmptyDateTapped;

  const CustomCalendarWidget({
    super.key,
    required this.records,
    required this.nonWorkingDays,
    required this.registrationDateStr,
    required this.onRecordsTapped,
    required this.onEmptyDateTapped,
  });

  @override
  State<CustomCalendarWidget> createState() => _CustomCalendarWidgetState();
}

class _CustomCalendarWidgetState extends State<CustomCalendarWidget> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime.now();
    _selectedDate = DateTime.now();
  }

  int _getDaysInMonth(DateTime date) {
    var firstDayOfNextMonth = DateTime(date.year, date.month + 1, 1);
    return firstDayOfNextMonth.subtract(const Duration(days: 1)).day;
  }

  int _getFirstWeekdayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday;
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final daysCount = _getDaysInMonth(_focusedMonth);
    final firstWeekday = _getFirstWeekdayOfMonth(_focusedMonth);
    
    final offset = firstWeekday - 1;

    // Map records by date string to a list of records for that day
    final Map<String, List<TransactionRecord>> recordMap = {};
    for (var record in widget.records) {
      recordMap.putIfAbsent(record.dateString, () => []).add(record);
    }

    final Map<String, NonWorkingDay> nonWorkingDaysMap = {};
    for (var day in widget.nonWorkingDays) {
      nonWorkingDaysMap[day.dateString] = day;
    }

    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Card(
      elevation: 0,
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: borderCol,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Calendar Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Weekday Headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                return SizedBox(
                  width: 32,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            
            // Days Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: daysCount + offset,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                if (index < offset) {
                  return const SizedBox.shrink();
                }
                
                final dayNumber = index - offset + 1;
                final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
                final dateKey = DateFormat('yyyy-MM-dd').format(date);
                
                final dayRecords = recordMap[dateKey] ?? [];
                final hasRecord = dayRecords.isNotEmpty;
                final isNonWorking = nonWorkingDaysMap.containsKey(dateKey);

                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;

                final isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;

                final today = DateTime.now();
                final todayMidnight = DateTime(today.year, today.month, today.day);
                final dateMidnight = DateTime(date.year, date.month, date.day);
                final isFuture = dateMidnight.isAfter(todayMidnight);
                final isPast = dateMidnight.isBefore(todayMidnight);

                final regDate = DateTime.tryParse(widget.registrationDateStr) ??
                    todayMidnight.subtract(const Duration(days: 30));
                final regDateMidnight = DateTime(regDate.year, regDate.month, regDate.day);
                final isMissing = isPast && !dateMidnight.isBefore(regDateMidnight) && !hasRecord && !isNonWorking;

                Color? indicatorColor;
                if (isFuture) {
                  indicatorColor = null;
                } else if (hasRecord) {
                  indicatorColor = const Color(0xFF10B981); // 🟢 Completed Entry
                } else if (isNonWorking) {
                  indicatorColor = const Color(0xFF3B82F6); // 🔵 Not Working
                } else if (isToday) {
                  indicatorColor = const Color(0xFFF59E0B); // 🟡 Today
                } else if (isMissing) {
                  indicatorColor = const Color(0xFFEF4444); // 🔴 Missing Entry
                }

                return GestureDetector(
                  onTap: isFuture
                      ? null
                      : () {
                          setState(() {
                            _selectedDate = date;
                          });
                          if (hasRecord) {
                            widget.onRecordsTapped(dayRecords);
                          } else {
                            widget.onEmptyDateTapped(date);
                          }
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isFuture
                          ? Colors.transparent
                          : isSelected
                              ? theme.colorScheme.primary
                              : (isToday ? theme.colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent),
                      shape: BoxShape.circle,
                      border: isToday && !isSelected && !isFuture
                          ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: (isToday || isSelected) && !isFuture ? FontWeight.bold : FontWeight.normal,
                            color: isFuture
                                ? (isDark ? Colors.white30 : Colors.black26)
                                : isSelected
                                    ? Colors.white
                                    : (hasRecord ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white70 : Colors.black54)),
                          ),
                        ),
                        if (indicatorColor != null && !isSelected && !isFuture)
                          Positioned(
                            bottom: 4,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: indicatorColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: indicatorColor.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Calendar Legend Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(const Color(0xFF10B981), 'Completed'),
                  const SizedBox(width: 12),
                  _buildLegendItem(const Color(0xFFEF4444), 'Missing'),
                  const SizedBox(width: 12),
                  _buildLegendItem(const Color(0xFFF59E0B), 'Today'),
                  const SizedBox(width: 12),
                  _buildLegendItem(const Color(0xFF3B82F6), 'Not Working'),
                  const SizedBox(width: 12),
                  _buildLegendItem(isDark ? Colors.white30 : Colors.black26, 'Locked'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
