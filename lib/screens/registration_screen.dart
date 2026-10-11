import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/glass_card.dart';
import 'login_screen.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _isLoading = false;
  String? _selectedAtmId;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final pin = _pinController.text.trim();

    if (_selectedAtmId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Assigned ATM.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final success = await ref.read(authProvider.notifier).register(name, mobile, pin, _selectedAtmId!);

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration completed successfully! Welcome.')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else if (mounted) {
      final error = ref.read(authProvider).errorMessage ?? 'Registration failed.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      ref.read(authProvider.notifier).clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final atms = ref.watch(atmListProvider);

    return Scaffold(
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  // Logo
                  Image.asset(
                    'assets/images/logo.png',
                    height: 90,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.local_atm,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title and Tagline
                  Text(
                    'Abhi ATM Manager',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Smart Management for Multiple Private ATMs',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),

                  // Registration Card
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employee Onboarding',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Name field
                        TextFormField(
                          controller: _nameController,
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Employee Name',
                            prefixIcon: Icon(Icons.person_outline),
                            hintText: 'Enter your full name',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Mobile number field
                        TextFormField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number',
                            prefixIcon: Icon(Icons.phone_android_outlined),
                            hintText: 'Enter 10-digit number',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your mobile number.';
                            }
                            if (val.trim().length < 10) {
                              return 'Please enter a valid mobile number.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Assigned ATM dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedAtmId,
                          decoration: const InputDecoration(
                            labelText: 'Assigned ATM',
                            prefixIcon: Icon(Icons.atm),
                          ),
                          items: atms.map((atm) {
                            return DropdownMenuItem<String>(
                              value: atm['id'],
                              child: Text('${atm['id']} – ${atm['name']}'),
                            );
                          }).toList(),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please select an assigned ATM.';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            setState(() {
                              _selectedAtmId = val;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Create PIN field
                        TextFormField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          obscureText: _obscurePin,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: 'Create 6-Digit PIN',
                            prefixIcon: const Icon(Icons.lock_outline),
                            counterText: '',
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                              onPressed: () {
                                setState(() {
                                  _obscurePin = !_obscurePin;
                                });
                              },
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter a PIN.';
                            }
                            if (val.length != 6 || int.tryParse(val) == null) {
                              return 'PIN must be a 6-digit number.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirm PIN field
                        TextFormField(
                          controller: _confirmPinController,
                          keyboardType: TextInputType.number,
                          obscureText: _obscureConfirmPin,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: 'Confirm PIN',
                            prefixIcon: const Icon(Icons.lock_outline),
                            counterText: '',
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirmPin ? Icons.visibility_off : Icons.visibility),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPin = !_obscureConfirmPin;
                                });
                              },
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please confirm your PIN.';
                            }
                            if (val != _pinController.text) {
                              return 'PINs do not match.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Continue'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Footer
                  Text(
                    'Designed & Developed with ❤️ by Amitesh Nagar',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.grey[600]),
                  ),
                  Text(
                    '© 2026 All Rights Reserved.',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
