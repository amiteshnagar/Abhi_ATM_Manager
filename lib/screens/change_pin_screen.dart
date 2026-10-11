import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_card.dart';

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();

    final dbHelper = DBHelper();
    final employee = await dbHelper.getEmployee();

    if (employee == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No registered employee profile found.')),
        );
      }
      return;
    }

    final savedPin = employee['pin'] as String;
    final employeeId = employee['id'] as int;

    if (currentPin != savedPin) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current PIN is incorrect.')),
        );
      }
      return;
    }

    // Save the new PIN to SQLite database
    await dbHelper.updateEmployeePin(employeeId, newPin);

    // Refresh auth state in provider
    await ref.read(authProvider.notifier).checkAuthStatus();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN changed successfully.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change PIN'),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFEFF6FF), const Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Update PIN',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep your application secure by updating your security PIN regularly.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current PIN
                        TextFormField(
                          controller: _currentPinController,
                          keyboardType: TextInputType.number,
                          obscureText: _obscureCurrent,
                          maxLength: 6,
                          style: const TextStyle(fontSize: 18, letterSpacing: 2.0),
                          decoration: InputDecoration(
                            labelText: 'Current PIN',
                            prefixIcon: const Icon(Icons.lock_open_outlined),
                            counterText: '',
                            suffixIcon: IconButton(
                              icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                              onPressed: () {
                                setState(() {
                                  _obscureCurrent = !_obscureCurrent;
                                });
                              },
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter current PIN.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // New PIN
                        TextFormField(
                          controller: _newPinController,
                          keyboardType: TextInputType.number,
                          obscureText: _obscureNew,
                          maxLength: 6,
                          style: const TextStyle(fontSize: 18, letterSpacing: 2.0),
                          decoration: InputDecoration(
                            labelText: 'New 6-Digit PIN',
                            prefixIcon: const Icon(Icons.lock_outline),
                            counterText: '',
                            suffixIcon: IconButton(
                              icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                              onPressed: () {
                                setState(() {
                                  _obscureNew = !_obscureNew;
                                });
                              },
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter new PIN.';
                            }
                            if (val.length != 6 || int.tryParse(val) == null) {
                              return 'PIN must be a 6-digit number.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirm New PIN
                        TextFormField(
                          controller: _confirmPinController,
                          keyboardType: TextInputType.number,
                          obscureText: _obscureConfirm,
                          maxLength: 6,
                          style: const TextStyle(fontSize: 18, letterSpacing: 2.0),
                          decoration: InputDecoration(
                            labelText: 'Confirm New PIN',
                            prefixIcon: const Icon(Icons.lock_outline),
                            counterText: '',
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirm = !_obscureConfirm;
                                });
                              },
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please confirm new PIN.';
                            }
                            if (val != _newPinController.text) {
                              return 'Confirm PIN does not match new PIN.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Save PIN Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _changePin,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Change PIN'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
