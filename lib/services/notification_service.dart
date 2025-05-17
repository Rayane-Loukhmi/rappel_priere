import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzData;

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzData.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Créer les canaux de notification
    const AndroidNotificationChannel mainChannel = AndroidNotificationChannel(
      'main_channel',
      'Main Channel',
      description: 'Channel for prayer reminders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel scheduledChannel = AndroidNotificationChannel(
      'scheduled_channel',
      'Scheduled Channel',
      description: 'Channel for scheduled prayer reminders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(mainChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(scheduledChannel);

    // Request notification permission for Android 13+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
            
    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      print('Notification permission granted: $granted');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'main_channel',
      'Main Channel',
      channelDescription: 'Channel for prayer reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
    );
  }

  Future<void> schedulePrayerNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    print('Scheduling notification for $title at $scheduledTime');
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_channel',
          'Scheduled Channel',
          channelDescription: 'Channel for scheduled prayer reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    print('Notification scheduled successfully.');
  }
}
