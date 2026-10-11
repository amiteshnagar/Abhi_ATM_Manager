import 'package:intl/intl.dart';

class NonWorkingDay {
  final int? id;
  final DateTime date;
  final String atmId;
  final String reason;
  final String? remarks;
  final DateTime createdAt;

  NonWorkingDay({
    this.id,
    required this.date,
    required this.atmId,
    required this.reason,
    this.remarks,
    required this.createdAt,
  });

  String get dateString => DateFormat('yyyy-MM-dd').format(date);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': dateString,
      'atm_id': atmId,
      'reason': reason,
      'remarks': remarks,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory NonWorkingDay.fromMap(Map<String, dynamic> map) {
    return NonWorkingDay(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      atmId: map['atm_id'] as String,
      reason: map['reason'] as String,
      remarks: map['remarks'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
