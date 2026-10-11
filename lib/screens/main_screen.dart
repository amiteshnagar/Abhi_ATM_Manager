import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/quick_log_sheet.dart';
import 'dashboard_screen.dart';
import 'activity_screen.dart';
import 'reports_screen.dart';
import 'history_screen.dart';
import 'missing_entries_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = ref.read(sharedPreferencesProvider);
      if (prefs.getBool('pending_notification_tap') == true) {
        await prefs.setBool('pending_notification_tap', false);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MissingEntriesScreen()),
          );
        }
      }
    });
  }

  final List<Widget> _screens = const [
    DashboardScreen(),
    ActivityScreen(),
    ReportsScreen(),
    HistoryScreen(),
  ];

  Widget _buildNavItem(int index, IconData outlineIcon, IconData solidIcon, String label, bool isDark) {
    final currentIndex = ref.watch(activeTabProvider);
    final isSelected = currentIndex == index;
    final activeColor = const Color(0xFFEE1C4B);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF525277);

    return InkWell(
      onTap: () {
        ref.read(activeTabProvider.notifier).state = index;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? solidIcon : outlineIcon,
            color: isSelected ? activeColor : inactiveColor,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11,
              color: isSelected ? activeColor : inactiveColor,
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
    final currentIndex = ref.watch(activeTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomAppBar(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          height: 64,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', isDark),
              _buildNavItem(1, Icons.explore_outlined, Icons.explore, 'Activity', isDark),
              const SizedBox(width: 40), // Spacing for FAB
              _buildNavItem(2, Icons.analytics_outlined, Icons.analytics, 'Reports', isDark),
              _buildNavItem(3, Icons.history_outlined, Icons.history, 'History', isDark),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFEE1C4B),
        foregroundColor: Colors.white,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const QuickLogSheet(),
          );
        },
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
