import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/backup_service.dart';
import '../utils/helpers.dart';
import '../services/background_service.dart';
import '../services/notification_service.dart';
import 'about_screen.dart';
import 'login_screen.dart';
import '../widgets/loading_indicator.dart';
import 'edit_profile_screen.dart';
import 'change_pin_screen.dart';
import '../services/biometric_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final BackupService _backupService = BackupService();
  bool _isOperating = false;

  Future<void> _triggerCSVExport() async {
    final records = ref.read(transactionListProvider);
    final settings = ref.read(settingsProvider);
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transaction logs to export.')),
      );
      return;
    }
    
    try {
      await _backupService.exportToCSV(records, settings.currency);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }

  Future<void> _triggerExcelExport() async {
    final records = ref.read(transactionListProvider);
    final settings = ref.read(settingsProvider);
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transaction logs to export.')),
      );
      return;
    }

    try {
      await _backupService.exportToExcel(records, settings.currency);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export Excel: $e')),
        );
      }
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const LoadingIndicator(isCompact: true),
                const SizedBox(width: 20),
                Text(message, style: const TextStyle(fontFamily: 'Google Sans')),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _triggerDBBackup() async {
    if (_isOperating) return;
    setState(() {
      _isOperating = true;
    });
    _showLoadingDialog('Backing up database...');
    try {
      await _backupService.backupDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database backup file shared.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database backup failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.pop(context);
        setState(() {
          _isOperating = false;
        });
      }
    }
  }

  Future<void> _triggerDBRestore() async {
    if (_isOperating) return;
    setState(() {
      _isOperating = true;
    });
    _showLoadingDialog('Restoring database...');
    try {
      final success = await _backupService.restoreDatabase();
      if (success) {
        await ref.read(transactionListProvider.notifier).refreshAfterRestore();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database restored successfully.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database restore cancelled or invalid file.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database restore failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.pop(context);
        setState(() {
          _isOperating = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showDefaultRateDialog() {
    final settings = ref.read(settingsProvider);
    final controller = TextEditingController(text: settings.defaultRate.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Rate', style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Default Transaction Rate',
            prefixIcon: Icon(Icons.currency_rupee),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null && val >= 0) {
                await ref.read(settingsProvider.notifier).updateDefaultRate(val);
                if (!context.mounted) return;
                Navigator.pop(context);
                setState(() {});
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid rate.')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMonthlyGoalDialog() {
    final prefs = ref.read(sharedPreferencesProvider);
    final goal = prefs.getDouble('monthly_earnings_goal') ?? 30000.0;
    final controller = TextEditingController(text: goal.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monthly Goal', style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Monthly Earnings Goal',
            prefixIcon: Icon(Icons.flag_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null && val >= 0) {
                final prefs = ref.read(sharedPreferencesProvider);
                await prefs.setDouble('monthly_earnings_goal', val);
                if (!context.mounted) return;
                Navigator.pop(context);
                setState(() {});
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid goal amount.')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    final settings = ref.read(settingsProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme', style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System Default'),
              value: ThemeMode.system,
              groupValue: settings.themeMode,
              onChanged: (val) async {
                if (val != null) {
                  await ref.read(settingsProvider.notifier).updateThemeMode(val);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light Mode'),
              value: ThemeMode.light,
              groupValue: settings.themeMode,
              onChanged: (val) async {
                if (val != null) {
                  await ref.read(settingsProvider.notifier).updateThemeMode(val);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark Mode'),
              value: ThemeMode.dark,
              groupValue: settings.themeMode,
              onChanged: (val) async {
                if (val != null) {
                  await ref.read(settingsProvider.notifier).updateThemeMode(val);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyDialog() {
    final settings = ref.read(settingsProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency', style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('INR (₹)'),
              value: '₹',
              groupValue: settings.currency,
              onChanged: (val) async {
                if (val != null) {
                  await ref.read(settingsProvider.notifier).updateCurrency(val);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('USD (\$)'),
              value: r'$',
              groupValue: settings.currency,
              onChanged: (val) async {
                if (val != null) {
                  await ref.read(settingsProvider.notifier).updateCurrency(val);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('EUR (€)'),
              value: '€',
              groupValue: settings.currency,
              onChanged: (val) async {
                if (val != null) {
                  await ref.read(settingsProvider.notifier).updateCurrency(val);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('GBP (£)'),
              value: '£',
              groupValue: settings.currency,
              onChanged: (val) async {
                if (val != null) {
                  await ref.read(settingsProvider.notifier).updateCurrency(val);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('JPY (¥)'),
              value: '¥',
              groupValue: settings.currency,
              onChanged: (val) async {
                if (val != null) {
                  await ref.read(settingsProvider.notifier).updateCurrency(val);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupRestoreDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup / Restore', style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.backup_outlined, color: Colors.teal),
              title: const Text('Backup SQLite Database'),
              subtitle: const Text('Export & share database backup file'),
              onTap: () {
                Navigator.pop(context);
                _triggerDBBackup();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_backup_restore_outlined, color: Colors.orange),
              title: const Text('Restore SQLite Database'),
              subtitle: const Text('Import database from backup file'),
              onTap: () {
                Navigator.pop(context);
                _triggerDBRestore();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, top: 18.0, bottom: 6.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Google Sans',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF525277),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    String? subtitle,
    String? valueText,
    Widget? trailingWidget,
    VoidCallback? onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final secondaryTextColor = isDark ? Colors.grey[400]! : const Color(0xFF525277);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? primaryTextColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor ?? primaryTextColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 11,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (valueText != null) ...[
              Text(
                valueText,
                style: TextStyle(
                  fontFamily: 'Google Sans',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (trailingWidget != null)
              trailingWidget
            else
              Icon(
                Icons.chevron_right,
                size: 16,
                color: secondaryTextColor,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authProvider);
    final atms = ref.watch(atmListProvider);

    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;

    // Fetch details of assigned ATMs
    final assignedNames = authState.assignedAtmIds.map((id) {
      final atm = atms.firstWhere((a) => a['id'] == id, orElse: () => {'name': ''});
      return "$id • ${atm['name']}";
    }).join(", ");

    final prefs = ref.watch(sharedPreferencesProvider);
    final goal = prefs.getDouble('monthly_earnings_goal') ?? 30000.0;

    String themeLabel = 'System Default';
    if (settings.themeMode == ThemeMode.light) themeLabel = 'Light Mode';
    if (settings.themeMode == ThemeMode.dark) themeLabel = 'Dark Mode';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Profile Header
            Container(
              padding: const EdgeInsets.all(16),
              color: cardBg,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFFEE1C4B).withValues(alpha: 0.12),
                    backgroundImage: authState.profilePhotoPath != null
                        ? FileImage(File(authState.profilePhotoPath!))
                        : null,
                    child: authState.profilePhotoPath == null
                        ? const Icon(Icons.person, size: 32, color: Color(0xFFEE1C4B))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.employeeName ?? 'ATM Operator',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          assignedNames.isNotEmpty ? assignedNames : 'No ATM Assigned',
                          style: const TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 13,
                            color: Color(0xFF525277),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mobile: ${authState.employeeMobile ?? "-"}',
                          style: const TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 12,
                            color: Color(0xFF525277),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Color(0xFFEE1C4B)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                      ).then((_) => setState(() {}));
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            _buildSectionHeader('Profile'),
            _buildSectionCard([
              _buildSettingRow(
                icon: Icons.person_outline,
                title: 'Edit Profile Information',
                subtitle: 'Change profile picture and name details',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                  ).then((_) => setState(() {}));
                },
              ),
            ]),

            _buildSectionHeader('Security'),
            _buildSectionCard([
              _buildSettingRow(
                icon: Icons.lock_outline,
                title: 'Change PIN',
                subtitle: 'Update your 6-digit security PIN code',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChangePinScreen()),
                  );
                },
              ),
              const Divider(height: 1, indent: 50, color: Color(0xFFE2E8F0)),
              _buildSettingRow(
                icon: Icons.fingerprint_outlined,
                title: 'Biometric Login',
                subtitle: 'Use face or fingerprint recognition',
                trailingWidget: Switch(
                  value: settings.biometricLogin,
                  activeThumbColor: const Color(0xFFEE1C4B),
                  onChanged: (val) async {
                    final isAvailable = await BiometricService().isBiometricsAvailable();
                    if (!isAvailable && val) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Biometric authentication is not supported or set up on this device.')),
                        );
                      }
                      return;
                    }
                    ref.read(settingsProvider.notifier).updateBiometricLogin(val);
                  },
                ),
              ),
              const Divider(height: 1, indent: 50, color: Color(0xFFE2E8F0)),
              _buildSettingRow(
                icon: Icons.hourglass_empty_outlined,
                title: 'Inactivity Auto Lock',
                subtitle: 'Securely auto-lock app after inactivity',
                valueText: '5 mins',
                trailingWidget: const SizedBox.shrink(),
              ),
            ]),

            _buildSectionHeader('App Preferences'),
            _buildSectionCard([
              _buildSettingRow(
                icon: Icons.currency_rupee,
                title: 'Default Transaction Rate',
                valueText: Helpers.formatCurrency(settings.defaultRate, settings.currency),
                onTap: _showDefaultRateDialog,
              ),
              const Divider(height: 1, indent: 50, color: Color(0xFFE2E8F0)),
              _buildSettingRow(
                icon: Icons.outlined_flag,
                title: 'Monthly Earnings Goal',
                valueText: Helpers.formatCurrency(goal, settings.currency),
                onTap: _showMonthlyGoalDialog,
              ),
              const Divider(height: 1, indent: 50, color: Color(0xFFE2E8F0)),
              _buildSettingRow(
                icon: Icons.notifications_none_outlined,
                title: 'Missing Entry Reminders',
                subtitle: 'Alerts when transaction logs are pending',
                trailingWidget: Switch(
                  value: settings.missingEntryReminders,
                  activeThumbColor: const Color(0xFFEE1C4B),
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).updateMissingEntryReminders(val);
                    if (val) {
                      await NotificationService().requestPermission();
                    }
                  },
                ),
              ),
              const Divider(height: 1, indent: 50, color: Color(0xFFE2E8F0)),
              if (kDebugMode) ...[
                _buildSettingRow(
                  icon: Icons.bug_report_outlined,
                  title: '[DEBUG] Test Reminder Notification',
                  subtitle: 'Trigger background check & notification immediately',
                  onTap: () async {
                    final success = await runNotificationCheckTask('morning_check');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Notification check task ran successfully.'
                                : 'Notification check task execution failed.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1, indent: 50, color: Color(0xFFE2E8F0)),
              ],
              _buildSettingRow(
                icon: Icons.palette_outlined,
                title: 'App Theme',
                valueText: themeLabel,
                onTap: _showThemeDialog,
              ),
              const Divider(height: 1, indent: 50, color: Color(0xFFE2E8F0)),
              _buildSettingRow(
                icon: Icons.monetization_on_outlined,
                title: 'Currency Symbol',
                valueText: settings.currency,
                onTap: _showCurrencyDialog,
              ),
            ]),

            _buildSectionHeader('Data & Export'),
            _buildSectionCard([
              _buildSettingRow(
                icon: Icons.file_download_outlined,
                title: 'Export CSV',
                subtitle: 'Save transaction database as CSV file',
                onTap: _triggerCSVExport,
              ),
              const Divider(height: 1, indent: 50, color: Color(0xFFE2E8F0)),
              _buildSettingRow(
                icon: Icons.table_chart_outlined,
                title: 'Export Excel',
                subtitle: 'Export data openable in Excel sheet',
                onTap: _triggerExcelExport,
              ),
              const Divider(height: 1, indent: 50, color: Color(0xFFE2E8F0)),
              _buildSettingRow(
                icon: Icons.backup_outlined,
                title: 'Backup / Restore Database',
                subtitle: 'Save or restore from local SQLite .db file',
                onTap: _showBackupRestoreDialog,
              ),
            ]),

            _buildSectionHeader('About'),
            _buildSectionCard([
              _buildSettingRow(
                icon: Icons.info_outline,
                title: 'About Abhi ATM Manager',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                },
              ),
              const Divider(height: 1, indent: 50, color: Color(0xFFE2E8F0)),
              _buildSettingRow(
                icon: Icons.phonelink_setup_outlined,
                title: 'App Version',
                valueText: '1.0.0',
                trailingWidget: const SizedBox.shrink(),
              ),
            ]),

            const SizedBox(height: 16),
            // Red-themed Logout Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEE1C4B).withValues(alpha: 0.2), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEE1C4B).withValues(alpha: 0.01),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: _buildSettingRow(
                icon: Icons.logout,
                title: 'Log out',
                iconColor: const Color(0xFFEE1C4B),
                textColor: const Color(0xFFEE1C4B),
                trailingWidget: const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Color(0xFFEE1C4B),
                ),
                onTap: _logout,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
