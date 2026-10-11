import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/missing_entries_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final prefs = await SharedPreferences.getInstance();
        final isSessionActive = prefs.getBool('session_active') ?? false;
        if (isSessionActive) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (context) => const MissingEntriesScreen()),
          );
          await prefs.setBool('pending_notification_tap', false);
        } else {
          await prefs.setBool('pending_notification_tap', true);
        }
      },
    );

    // Explicitly create notification channels for Android to ensure correct system registration
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const AndroidNotificationChannel backgroundChannel = AndroidNotificationChannel(
        'background_reminders_channel',
        'Background Reminders',
        description: 'Scheduled morning/evening reminders for missing daily entries',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidPlugin.createNotificationChannel(backgroundChannel);

      const AndroidNotificationChannel pendingChannel = AndroidNotificationChannel(
        'pending_entries_channel',
        'Pending Entries Reminders',
        description: 'Reminders for logging missing daily ATM transactions',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidPlugin.createNotificationChannel(pendingChannel);
    }
  }

  Future<bool?> requestPermission() async {
    return await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<bool> checkPermission() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final enabled = await androidPlugin.areNotificationsEnabled();
      return enabled ?? false;
    }
    return true;
  }

  Future<void> showPendingEntryReminder(String dateStr) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'pending_entries_channel',
      'Pending Entries Reminders',
      channelDescription: 'Reminders for logging missing daily ATM transactions',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      100, // Notification ID
      'Missing ATM Entry',
      'Please submit the ATM transaction record for $dateStr.',
      platformDetails,
    );
  }

  Future<void> showBackgroundReminder(String title, String message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'background_reminders_channel',
      'Background Reminders',
      channelDescription: 'Scheduled morning/evening reminders for missing daily entries',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      200, // Background notification ID
      title,
      message,
      platformDetails,
    );
  }
}
