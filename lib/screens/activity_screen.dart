import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/non_working_day_provider.dart';
import '../database/db_helper.dart';
import 'settings_screen.dart';

// Event model for chronological Activity Timeline
class ActivityEvent {
  final String title;
  final String detail;
  final DateTime timestamp;
  final String category; // 'audit_update', 'audit_delete', 'non_working'

  ActivityEvent({
    required this.title,
    required this.detail,
    required this.timestamp,
    required this.category,
  });
}

// Read-only FutureProvider for audits
final activityAuditsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final auth = ref.watch(authProvider);
  return await DBHelper().getAllAuditHistoryForAtms(auth.assignedAtmIds);
});

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  String _getDayHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) {
      return 'TODAY';
    } else if (target == yesterday) {
      return 'YESTERDAY';
    } else {
      return DateFormat('d MMMM yyyy').format(date).toUpperCase();
    }
  }

  Widget _buildTimelineItem(BuildContext context, ActivityEvent event, bool isLast) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);
    final timelineLineColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line and indicator dot
          Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, size: 14, color: iconColor),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast ? Colors.transparent : timelineLineColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18.0),
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
                        DateFormat('h:mm a').format(event.timestamp),
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
                      fontSize: 12,
                      color: secondaryTextColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = ref.watch(authProvider);
    final auditsAsync = ref.watch(activityAuditsProvider);
    final nonWorkingDays = ref.watch(nonWorkingDayProvider);

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: Color(0xFF1E1A4D),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Recent actions and events log',
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
      body: auditsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Failed to load logs: $err', style: TextStyle(color: primaryTextColor)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.refresh(activityAuditsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (auditList) {
          _fadeController.forward(from: 0.0);

          // Combine Audits and NonWorkingDays
          final List<ActivityEvent> events = [];

          // 1. Process Audits
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

          // 2. Process Non Working Days
          for (final nwd in nonWorkingDays) {
            final createdAt = nwd.createdAt;
            events.add(ActivityEvent(
              title: 'Marked Not Working',
              detail: 'ATM marked off-duty for date: ${nwd.dateString}.\nReason: ${nwd.reason}',
              timestamp: createdAt,
              category: 'non_working',
            ));
          }

          // Sort events newest first
          events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_toggle_off_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No recent activity',
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your recent actions will appear here.',
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

          return FadeTransition(
            opacity: _fadeController,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final prevHeader = index > 0 ? _getDayHeader(events[index - 1].timestamp) : null;
                final currentHeader = _getDayHeader(event.timestamp);
                final showHeader = prevHeader != currentHeader;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showHeader) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0, bottom: 12.0),
                        child: Text(
                          currentHeader,
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
                    _buildTimelineItem(context, event, index == events.length - 1),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
