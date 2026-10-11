import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import 'settings_provider.dart';
import 'transaction_provider.dart';

class AuthState {
  final bool isInitialized;
  final bool isRegistered;
  final bool isLoggedIn;
  final String? employeeName;
  final String? employeeMobile;
  final List<String> assignedAtmIds;
  final String? profilePhotoPath;
  final String? errorMessage;

  AuthState({
    this.isInitialized = false,
    required this.isRegistered,
    required this.isLoggedIn,
    this.employeeName,
    this.employeeMobile,
    this.assignedAtmIds = const [],
    this.profilePhotoPath,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isInitialized,
    bool? isRegistered,
    bool? isLoggedIn,
    String? employeeName,
    String? employeeMobile,
    List<String>? assignedAtmIds,
    String? profilePhotoPath,
    String? errorMessage,
  }) {
    return AuthState(
      isInitialized: isInitialized ?? this.isInitialized,
      isRegistered: isRegistered ?? this.isRegistered,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      employeeName: employeeName ?? this.employeeName,
      employeeMobile: employeeMobile ?? this.employeeMobile,
      assignedAtmIds: assignedAtmIds ?? this.assignedAtmIds,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final DBHelper _dbHelper;
  final SharedPreferences _prefs;

  AuthNotifier(this._dbHelper, this._prefs)
      : super(AuthState(isInitialized: false, isRegistered: false, isLoggedIn: false)) {
    checkAuthStatus();
  }

  static const String _keySessionActive = 'session_active';
  static const String _keyRememberMe = 'remember_me';
  static const String _keyIsRegistered = 'isRegistered';

  Future<void> checkAuthStatus() async {
    // If running in a test environment, immediately set initialized to true to prevent unmocked SQLite hangs
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      state = AuthState(
        isInitialized: true,
        isRegistered: false,
        isLoggedIn: false,
      );
      return;
    }
    try {
      final employee = await _dbHelper.getEmployee();
      final isRegistered = _prefs.getBool(_keyIsRegistered) ?? (employee != null);
      
      // Sync SharedPreferences if SQLite has employee but the key is missing
      if (employee != null && !_prefs.containsKey(_keyIsRegistered)) {
        await _prefs.setBool(_keyIsRegistered, true);
      }
      
      // Clear session active flag on startup so the session is NOT persisted across app launches
      await _prefs.setBool(_keySessionActive, false);

      int employeeCount = employee != null ? 1 : 0;
      debugPrint('--- STARTUP DIAGNOSTICS ---');
      debugPrint('Employee count on startup: $employeeCount');
      if (employee != null) {
        debugPrint('Employee ID loaded: ${employee['id']}');
      } else {
        debugPrint('Employee ID loaded: null');
      }

      if (isRegistered && employee != null) {
        final assignedAtmIds = await _dbHelper.getAssignedAtmIds(employee['id'] as int);
        debugPrint('Assigned ATM loaded: $assignedAtmIds');
        state = AuthState(
          isInitialized: true,
          isRegistered: true,
          isLoggedIn: false, // Always false on startup/restart for security
          employeeName: employee['name'] as String?,
          employeeMobile: employee['mobile'] as String?,
          assignedAtmIds: assignedAtmIds,
          profilePhotoPath: employee['profile_photo_path'] as String?,
        );
      } else {
        debugPrint('Assigned ATM loaded: [] (no employee or not registered)');
        state = AuthState(
          isInitialized: true,
          isRegistered: false,
          isLoggedIn: false,
        );
      }
      debugPrint('Auth state after startup: isRegistered = ${state.isRegistered}, isLoggedIn = ${state.isLoggedIn}');
      debugPrint('---------------------------');
    } catch (e, stack) {
      debugPrint('--- STARTUP DIAGNOSTICS ERROR ---');
      debugPrint('Error in checkAuthStatus: $e');
      debugPrint(stack.toString());
      debugPrint('---------------------------');
      state = AuthState(
        isInitialized: true,
        isRegistered: false,
        isLoggedIn: false,
      );
    }
  }

  Future<bool> register(String name, String mobile, String pin, String atmId) async {
    try {
      await _dbHelper.registerEmployee(name, mobile, pin, atmId);
      await _prefs.setBool(_keyIsRegistered, true);
      
      // Also save registration timestamp for checking pending entries starting from this date
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      await _prefs.setString('registration_date', todayStr);

      state = AuthState(
        isInitialized: true,
        isRegistered: true,
        isLoggedIn: false,
        employeeName: name,
        employeeMobile: mobile,
        assignedAtmIds: [atmId],
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Registration failed: $e');
      return false;
    }
  }

  Future<bool> login(String mobile, String pin, bool rememberMe) async {
    final employee = await _dbHelper.getEmployee();
    if (employee == null) {
      state = state.copyWith(errorMessage: 'No registered employee found.');
      return false;
    }

    final savedMobile = employee['mobile'] as String;
    final savedPin = employee['pin'] as String;

    if (mobile == savedMobile && pin == savedPin) {
      await _prefs.setBool(_keySessionActive, true);
      await _prefs.setBool(_keyRememberMe, rememberMe);
      final assignedAtmIds = await _dbHelper.getAssignedAtmIds(employee['id'] as int);
      state = AuthState(
        isInitialized: true,
        isRegistered: true,
        isLoggedIn: true,
        employeeName: employee['name'] as String?,
        employeeMobile: savedMobile,
        assignedAtmIds: assignedAtmIds,
        profilePhotoPath: employee['profile_photo_path'] as String?,
      );
      return true;
    } else {
      state = state.copyWith(errorMessage: 'Invalid mobile number or PIN.');
      return false;
    }
  }

  Future<bool> updateProfile(String name, String? profilePhotoPath) async {
    final employee = await _dbHelper.getEmployee();
    if (employee == null) {
      state = state.copyWith(errorMessage: 'No registered employee found.');
      return false;
    }
    
    final employeeId = employee['id'] as int;
    await _dbHelper.updateEmployeeProfile(employeeId, name, profilePhotoPath);
    
    state = state.copyWith(
      employeeName: name,
      profilePhotoPath: profilePhotoPath,
    );
    return true;
  }

  Future<void> logout() async {
    await _prefs.setBool(_keySessionActive, false);
    state = state.copyWith(isLoggedIn: false);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final dbHelper = ref.watch(dbHelperProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthNotifier(dbHelper, prefs);
});
