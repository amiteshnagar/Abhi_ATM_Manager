import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'theme/theme.dart';
import 'widgets/inactivity_autolock.dart';

void main() async {
  // Ensure Flutter engine is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline notifications reminder
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('Notification initialization failed: $e');
  }

  // Initialize Workmanager for background checking
  try {
    await Workmanager().initialize(
      callbackDispatcher,
    );
    // Register initial Morning Check (12:00 PM)
    await Workmanager().registerOneOffTask(
      'morning_check_task',
      'morning_check',
      initialDelay: durationUntilNextTime(12, 0),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    debugPrint('[4.4.2 Registration] morning task registered');
    
    // Register initial Evening Check (7:00 PM)
    await Workmanager().registerOneOffTask(
      'evening_check_task',
      'evening_check',
      initialDelay: durationUntilNextTime(19, 0),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    debugPrint('[4.4.2 Registration] evening task registered');
  } catch (e) {
    debugPrint('[4.4.2 Registration] Workmanager initialization failed: $e');
  }

  // Load SharedPreferences instance before running the app
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to theme mode changes dynamically
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Abhi ATM Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: const SplashScreen(), // Launch into the Animated Splash Screen
      builder: (context, child) {
        return InactivityAutoLock(child: child ?? const SizedBox());
      },
    );
  }
}
