import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/biometric_service.dart';
import '../widgets/glass_card.dart';
import 'main_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();

  bool _obscurePin = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  bool _isBiometricSupported = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0.0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _checkBiometricsSupport();
  }

  Future<void> _checkBiometricsSupport() async {
    final available = await BiometricService().isBiometricsAvailable();
    if (mounted) {
      setState(() {
        _isBiometricSupported = available;
      });
    }
    
    // Auto-trigger biometric authentication if setting is enabled and device supports it
    final settings = ref.read(settingsProvider);
    if (settings.biometricLogin && available) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticateWithBiometrics();
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _authenticateWithBiometrics() async {
    final success = await BiometricService().authenticate();
    if (success && mounted) {
      final employee = await DBHelper().getEmployee();
      if (employee != null) {
        final mobile = employee['mobile'] as String;
        final pin = employee['pin'] as String;

        setState(() {
          _isLoading = true;
        });

        final loginSuccess = await ref.read(authProvider.notifier).login(mobile, pin, _rememberMe);

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        if (loginSuccess && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final pin = _pinController.text.trim();

    // Look up the registered employee directly from SQLite to obtain mobile number
    final employee = await DBHelper().getEmployee();
    if (employee == null) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No registered employee profile found. Please register first.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final mobile = employee['mobile'] as String;
    final success = await ref.read(authProvider.notifier).login(mobile, pin, _rememberMe);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else if (mounted) {
      final error = ref.read(authProvider).errorMessage ?? 'Invalid PIN.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red[600],
        ),
      );
      ref.read(authProvider.notifier).clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1A4D);

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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        Image.asset(
                          'assets/images/logo.png',
                          height: 80,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.local_atm,
                            size: 60,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // App Name
                        Text(
                          'Abhi ATM Manager',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        // Tagline
                        Text(
                          'Smart Management for Multiple Private ATMs',
                          style: TextStyle(fontFamily: 'Google Sans', fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        const SizedBox(height: 28),

                        // Login Card
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Welcome Back',
                                style: TextStyle(
                                  fontFamily: 'Google Sans',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Enter your security PIN to login',
                                style: TextStyle(
                                  fontFamily: 'Google Sans',
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // PIN input field (no mobile number field shown)
                              TextFormField(
                                controller: _pinController,
                                keyboardType: TextInputType.number,
                                obscureText: _obscurePin,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Google Sans',
                                  fontSize: 22,
                                  letterSpacing: 6.0,
                                  fontWeight: FontWeight.bold,
                                  color: primaryTextColor,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Security PIN',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
                                    return 'Please enter your PIN.';
                                  }
                                  if (val.length != 6 || int.tryParse(val) == null) {
                                    return 'PIN must be a 6-digit number.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Remember Login check
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      activeColor: const Color(0xFFEE1C4B),
                                      onChanged: (val) {
                                        setState(() {
                                          _rememberMe = val ?? true;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _rememberMe = !_rememberMe;
                                      });
                                    },
                                    child: Text(
                                      'Remember Login',
                                      style: TextStyle(
                                        fontFamily: 'Google Sans',
                                        fontSize: 13,
                                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // Login button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEE1C4B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Login',
                                          style: TextStyle(fontFamily: 'Google Sans', fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ),

                              // Use Biometric Button if supported
                              if (_isBiometricSupported) ...[
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _authenticateWithBiometrics,
                                  icon: const Icon(Icons.fingerprint, size: 22, color: Color(0xFFEE1C4B)),
                                  label: const Text(
                                    'Use Biometric Login',
                                    style: TextStyle(fontFamily: 'Google Sans', color: Color(0xFFEE1C4B), fontWeight: FontWeight.bold),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                        
                        // Footer branding
                        Text(
                          'Designed & Developed with ❤️ by Amitesh Nagar',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '© 2026 All Rights Reserved.',
                          style: TextStyle(fontFamily: 'Google Sans', fontSize: 10, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
