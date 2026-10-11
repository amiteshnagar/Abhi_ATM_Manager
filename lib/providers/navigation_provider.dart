import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeTabProvider = StateProvider<int>((ref) => 0);

final dashboardSelectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final dashboardSelectedAtmIdProvider = StateProvider<String?>((ref) => null);
final dashboardIsEditingExistingProvider = StateProvider<bool>((ref) => false);
final dashboardIsMissingEntryModeProvider = StateProvider<bool>((ref) => false);
