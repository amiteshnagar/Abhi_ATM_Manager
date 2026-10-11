import 'package:intl/intl.dart';

class TransactionRecord {
  final int? id;
  final DateTime date;
  final String atmId;
  final int count;
  final double rate;
  final double total;
  final String? remarks;

  TransactionRecord({
    this.id,
    required this.date,
    required this.atmId,
    required this.count,
    required this.rate,
    required this.total,
    this.remarks,
  });

  // Calculate total automatically if not provided
  factory TransactionRecord.calculate({
    int? id,
    required DateTime date,
    required String atmId,
    required int count,
    required double rate,
    String? remarks,
  }) {
    return TransactionRecord(
      id: id,
      date: date,
      atmId: atmId,
      count: count,
      rate: rate,
      total: count * rate,
      remarks: remarks,
    );
  }

  // Create a copy of the record with updated fields
  TransactionRecord copyWith({
    int? id,
    DateTime? date,
    String? atmId,
    int? count,
    double? rate,
    double? total,
    String? remarks,
  }) {
    return TransactionRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      atmId: atmId ?? this.atmId,
      count: count ?? this.count,
      rate: rate ?? this.rate,
      total: total ?? this.total,
      remarks: remarks ?? this.remarks,
    );
  }

  // Convert a TransactionRecord into a Map for SQLite insertion
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'atm_id': atmId,
      'count': count,
      'rate': rate,
      'total': total,
      'remarks': remarks ?? '',
    };
  }

  // Convert a Map from SQLite into a TransactionRecord
  factory TransactionRecord.fromMap(Map<String, dynamic> map) {
    return TransactionRecord(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      atmId: (map['atm_id'] as String?) ?? 'ABHI01',
      count: map['count'] as int,
      rate: (map['rate'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      remarks: map['remarks'] as String?,
    );
  }

  // Get date in 'yyyy-MM-dd' string format
  String get dateString => DateFormat('yyyy-MM-dd').format(date);
}
