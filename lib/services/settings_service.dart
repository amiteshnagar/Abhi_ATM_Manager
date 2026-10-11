import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  static const String _keyDefaultRate = 'default_rate';
  static const String _keyCurrency = 'currency_symbol';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyMissingEntryReminders = 'missing_entry_reminders';

  // Get current default rate, defaulting to 6.0
  double getDefaultRate() {
    return _prefs.getDouble(_keyDefaultRate) ?? 6.0;
  }

  // Save default rate
  Future<void> setDefaultRate(double rate) async {
    await _prefs.setDouble(_keyDefaultRate, rate);
  }

  // Get current currency symbol, defaulting to '₹'
  String getCurrency() {
    return _prefs.getString(_keyCurrency) ?? '₹';
  }

  // Save currency symbol
  Future<void> setCurrency(String symbol) async {
    await _prefs.setString(_keyCurrency, symbol);
  }

  // Get theme mode, defaulting to 'system'
  String getThemeMode() {
    return _prefs.getString(_keyThemeMode) ?? 'system';
  }

  // Save theme mode ('light', 'dark', 'system')
  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(_keyThemeMode, mode);
  }

  static const String _keyBiometricLogin = 'biometric_login';

  // Get missing entry reminders setting, defaulting to true
  bool getMissingEntryReminders() {
    return _prefs.getBool(_keyMissingEntryReminders) ?? true;
  }

  // Save missing entry reminders setting
  Future<void> setMissingEntryReminders(bool value) async {
    await _prefs.setBool(_keyMissingEntryReminders, value);
  }

  // Get biometric login setting, defaulting to false
  bool getBiometricLogin() {
    return _prefs.getBool(_keyBiometricLogin) ?? false;
  }

  // Save biometric login setting
  Future<void> setBiometricLogin(bool value) async {
    await _prefs.setBool(_keyBiometricLogin, value);
  }
}
