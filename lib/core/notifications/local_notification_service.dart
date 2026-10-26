import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  // Prevent initializing the plugin more than once.
  static bool _initialized = false;

  // ============================================================
  // INITIALIZE
  // ============================================================

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: settings,
    );

    _initialized = true;

    // Android 13+ notification permission.
    await requestPermission();
  }

  // ============================================================
  // ENSURE INITIALIZED
  // ============================================================

  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    await initialize();
  }

  // ============================================================
  // REQUEST PERMISSION
  // ============================================================

  static Future<void> requestPermission() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
  }

  // ============================================================
  // SHOW BUDGET ALERT
  // ============================================================

  static Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    // Safety: make sure the notification plugin is ready even when
    // this method is called before app startup initialization completes.
    await ensureInitialized();

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription:
      'Notifications when spending reaches your budget limits.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
    NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }
}
