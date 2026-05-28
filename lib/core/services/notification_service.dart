// lib/core/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.handleBackgroundMessage(message);
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'daily_quiz_channel',
    'Daily Quiz Alerts',
    description: 'Notification for daily GK quiz',
    importance: Importance.high,
    playSound: true,
  );

  static const AndroidNotificationChannel _streakChannel =
      AndroidNotificationChannel(
    'streak_reminder_channel',
    'Streak Reminders',
    description: 'Reminders to maintain your streak',
    importance: Importance.high,
    playSound: true,
  );

  static const AndroidNotificationChannel _rewardChannel =
      AndroidNotificationChannel(
    'reward_channel',
    'Rewards & Achievements',
    description: 'Notifications for rewards and achievements',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> initialize(AuthService authService) async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings =
        await _fcm.requestPermission(alert: true, badge: true, sound: true);

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _setupLocalNotifications();
      await _subscribeToTopics();
      await _refreshAndSaveFcmToken(authService);
      _listenForeground();
    }
  }

  Future<void> _setupLocalNotifications() async {
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_streakChannel);
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_rewardChannel);

    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );
  }

  Future<void> _subscribeToTopics() async {
    await _fcm.subscribeToTopic('daily_quiz');
    await _fcm.subscribeToTopic('general');
    await _fcm.subscribeToTopic('wbpsc');
    await _fcm.subscribeToTopic('ssc');
    await _fcm.subscribeToTopic('upsc');
    await _fcm.subscribeToTopic('bank');
  }

  Future<void> _refreshAndSaveFcmToken(AuthService authService) async {
    final token = await _fcm.getToken();
    if (token != null) await authService.updateFcmToken(token);
    _fcm.onTokenRefresh.listen((newToken) async {
      await authService.updateFcmToken(newToken);
    });
  }

  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        await _localNotif.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(_channel.id, _channel.name,
                channelDescription: _channel.description,
                icon: android.smallIcon ?? '@mipmap/ic_launcher',
                importance: Importance.high,
                priority: Priority.high),
          ),
          payload: message.data['date'],
        );
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data['date']);
    });
  }

  void _handleNotificationTap(String? payload) {}

  @pragma('vm:entry-point')
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Background message: ${message.messageId}');
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _rewardChannel.id,
          _rewardChannel.name,
          channelDescription: _rewardChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: payload,
    );
  }

  Future<void> showAchievementNotification(String title, String body) async {
    await showInstantNotification(
        title: '🏆 $title', body: body, payload: 'achievement');
  }

  Future<void> showStreakMilestoneNotification(int streak) async {
    await showInstantNotification(
      title: '🔥 $streak Day Streak!',
      body: 'Amazing! Keep up the great work!',
      payload: 'streak',
    );
  }

  Future<void> showLevelUpNotification(int newLevel) async {
    await showInstantNotification(
      title: '⭐ Level Up!',
      body: 'Congratulations! You reached Level $newLevel!',
      payload: 'level',
    );
  }

  Future<void> showReferralNotification() async {
    await showInstantNotification(
      title: '🎁 Friend Joined!',
      body: 'Your friend used your referral code. You earned 100 coins!',
      payload: 'referral',
    );
  }

  Future<void> showDailyQuizReminder() async {
    await showInstantNotification(
      title: '📚 Daily Quiz Ready!',
      body: 'Your daily quiz is waiting. Come test your knowledge! 🎯',
      payload: 'daily_quiz',
    );
  }

  Future<void> showStreakReminder() async {
    await showInstantNotification(
      title: '🔥 Don\'t lose your streak!',
      body: 'Complete today\'s quiz to keep your streak going strong!',
      payload: 'streak_reminder',
    );
  }

  Future<void> scheduleDailyQuizReminder({
    required int hour,
    required int minute,
    String? examMode,
  }) async {
    tz.initializeTimeZones();
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _localNotif.zonedSchedule(
      100 + (minute % 10),
      '📚 Daily Quiz Ready!',
      'Your daily GK quiz is waiting. Come test your knowledge! 🎯',
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'scheduled_quiz_$examMode',
    );
  }

  Future<void> scheduleStreakReminder({
    required int hour,
    required int minute,
  }) async {
    tz.initializeTimeZones();
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _localNotif.zonedSchedule(
      200,
      '🔥 Keep Your Streak Alive!',
      "Don't forget to complete today's quiz to maintain your streak!",
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _streakChannel.id,
          _streakChannel.name,
          channelDescription: _streakChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'streak_reminder_scheduled',
    );
  }

  Future<void> scheduleRemindersFromConfig({
    required int quizStartHour,
    required int quizStartMinute,
  }) async {
    await cancelAllScheduledNotifications();

    final reminder15Before = quizStartMinute >= 15
        ? quizStartMinute - 15
        : 60 + quizStartMinute - 15;
    final reminder15Hour =
        quizStartMinute >= 15 ? quizStartHour : (quizStartHour - 1 + 24) % 24;

    await scheduleDailyQuizReminder(
      hour: reminder15Hour,
      minute: reminder15Before,
    );

    await scheduleDailyQuizReminder(
      hour: quizStartHour,
      minute: quizStartMinute,
    );

    final streakReminderHour = (quizStartHour - 2 + 24) % 24;
    await scheduleStreakReminder(
      hour: streakReminderHour,
      minute: 0,
    );
  }

  Future<void> cancelAllScheduledNotifications() async {
    await _localNotif.cancelAll();
  }
}
