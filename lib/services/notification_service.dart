import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

/// 通知服务
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_initialized) return;

    // 初始化时区数据
    tz.initializeTimeZones();
    // 设置本地时区为中国
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    // iOS 设置
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Android 设置
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      iOS: iosSettings,
      android: androidSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// 请求通知权限
  Future<bool> requestPermissions() async {
    if (!_initialized) {
      await initialize();
    }

    // iOS 请求权限
    final iosPermission = await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Android 请求权限
    final androidPermission = await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    return iosPermission ?? androidPermission ?? false;
  }

  /// 点击通知回调
  void _onNotificationTapped(NotificationResponse response) {
    // TODO: 根据 payload 处理不同的跳转逻辑
  }

  /// 显示即时通知（用于测试）
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'instant_channel',
      '即时通知',
      channelDescription: '即时显示的通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000, // 使用时间戳作为 ID
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// 设置每日复习提醒
  Future<void> scheduleReviewReminder({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    const notificationId = 1001; // 复习提醒的固定 ID

    // 如果禁用，取消通知
    if (!enabled) {
      await cancelNotification(notificationId);
      await _saveReminderPreference('review_reminder', false, null);
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    // 请求权限
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      throw Exception('通知权限未授予');
    }

    // 设置通知时间
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // 如果今天的时间已过，设置为明天
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'review_reminder_channel',
      '复习提醒',
      channelDescription: '每日复习提醒',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      notificationId,
      '📚 复习时间到了',
      '别忘了复习今天的错题哦，坚持就是胜利！',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 每天重复
    );

    // 保存提醒偏好
    await _saveReminderPreference(
      'review_reminder',
      true,
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
    );
  }

  /// 设置每日任务提醒
  Future<void> scheduleDailyTaskReminder({
    required bool enabled,
    TimeOfDay? time,
  }) async {
    const notificationId = 1002; // 每日任务提醒的固定 ID

    if (!enabled) {
      await cancelNotification(notificationId);
      await _saveReminderPreference('daily_task_reminder', false, null);
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      throw Exception('通知权限未授予');
    }

    // 默认时间：上午 9:00
    final reminderTime = time ?? const TimeOfDay(hour: 9, minute: 0);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminderTime.hour,
      reminderTime.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_task_reminder_channel',
      '每日任务提醒',
      channelDescription: '每日学习任务提醒',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      notificationId,
      '🎯 今日学习任务',
      '今天的学习任务已为你准备好，快来完成吧！',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await _saveReminderPreference(
      'daily_task_reminder',
      true,
      '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}',
    );
  }

  /// 取消特定通知
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// 获取所有待处理的通知
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
  

  /// 保存提醒偏好到本地
  Future<void> _saveReminderPreference(
    String key,
    bool enabled,
    String? time,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${key}_enabled', enabled);
    if (time != null) {
      await prefs.setString('${key}_time', time);
    } else {
      await prefs.remove('${key}_time');
    }
  }

  /// 读取提醒偏好
  Future<Map<String, dynamic>> getReminderPreference(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('${key}_enabled') ?? false;
    final time = prefs.getString('${key}_time');
    return {'enabled': enabled, 'time': time};
  }
}

/// 时间选择辅助类
class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});

  @override
  String toString() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// 从字符串解析（格式：HH:mm）
  static TimeOfDay? fromString(String? timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

