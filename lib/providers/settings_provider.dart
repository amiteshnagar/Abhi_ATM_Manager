import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';

// Represents the state for all settings
class SettingsState {
  final ThemeMode themeMode;
  final double defaultRate;
  final String currency;
  final bool missingEntryReminders;
  final bool biometricLogin;

  SettingsState({
    required this.themeMode,
    required this.defaultRate,
    required this.currency,
    required this.missingEntryReminders,
    required this.biometricLogin,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    double? defaultRate,
    String? currency,
    bool? missingEntryReminders,
    bool? biometricLogin,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      defaultRate: defaultRate ?? this.defaultRate,
      currency: currency ?? this.currency,
      missingEntryReminders: missingEntryReminders ?? this.missingEntryReminders,
      biometricLogin: biometricLogin ?? this.biometricLogin,
    );
  }
}

// Provider for SharedPreferences, overridden at main() entry point
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// Provider for SettingsService
final settingsServiceProvider = Provider<SettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsService(prefs);
});

// StateNotifier for settings
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsService _service;

  SettingsNotifier(this._service)
      : super(SettingsState(
          themeMode: _parseThemeMode(_service.getThemeMode()),
          defaultRate: _service.getDefaultRate(),
          currency: _service.getCurrency(),
          missingEntryReminders: _service.getMissingEntryReminders(),
          biometricLogin: _service.getBiometricLogin(),
        ));

  static ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  // Update theme mode
  Future<void> updateThemeMode(ThemeMode mode) async {
    await _service.setThemeMode(_themeModeToString(mode));
    state = state.copyWith(themeMode: mode);
  }

  // Update default transaction rate
  Future<void> updateDefaultRate(double rate) async {
    await _service.setDefaultRate(rate);
    state = state.copyWith(defaultRate: rate);
  }

  // Update currency symbol
  Future<void> updateCurrency(String symbol) async {
    await _service.setCurrency(symbol);
    state = state.copyWith(currency: symbol);
  }

  // Update missing entry reminders setting
  Future<void> updateMissingEntryReminders(bool value) async {
    await _service.setMissingEntryReminders(value);
    state = state.copyWith(missingEntryReminders: value);
  }

  // Update biometric login setting
  Future<void> updateBiometricLogin(bool value) async {
    await _service.setBiometricLogin(value);
    state = state.copyWith(biometricLogin: value);
  }
}

// Provider for SettingsNotifier
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return SettingsNotifier(service);
});
