import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationsService {
  NotificationsService._();

  static final NotificationsService instance = NotificationsService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    _ready = true;
  }

  Future<void> scheduleReminder({
    required String noteUid,
    required DateTime when,
    required String title,
  }) async {
    await init();

    final id = _notificationId(noteUid);
    final scheduled = tz.TZDateTime.from(when, tz.local);

    await _plugin.zonedSchedule(
      id,
      title.isEmpty ? 'Reminder' : title,
      'Tap to open note',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mexy_note_reminders',
          'Reminders',
          channelDescription: 'Note reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(String noteUid) async {
    await init();
    await _plugin.cancel(_notificationId(noteUid));
  }

  int _notificationId(String uid) {
    // Stable 31-bit id derived from uid.
    var h = 0;
    for (final c in uid.codeUnits) {
      h = 0x1fffffff & (h + c);
      h = 0x1fffffff & (h + ((0x0007ffff & h) << 10));
      h ^= (h >> 6);
    }
    h = 0x1fffffff & (h + ((0x03ffffff & h) << 3));
    h ^= (h >> 11);
    h = 0x1fffffff & (h + ((0x00003fff & h) << 15));
    return h;
  }
}

