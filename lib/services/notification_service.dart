// Letak file: mobile/lib/services/notification_service.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/dio_client.dart';
import '../core/secure_storage.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp();
    } catch (error) {
      debugPrint('[FCM Background] Firebase initialization failed: $error');
      return;
    }
  }
  final service = NotificationService();
  await service.initialize();
  if (message.notification == null) {
    await service.showInstantNotification(
      id: message.hashCode,
      title: message.data['title']?.toString() ?? 'AsuhKita',
      body: message.data['body']?.toString() ?? '',
      payload: message.data['payload']?.toString(),
    );
  }
  debugPrint('[FCM Background] Pesan diterima: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _fcmListenersInitialized = false;
  bool _tokenRefreshListenerRegistered = false;

  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      debugPrint(
        '[NotificationService] Web environment - skipping local setup.',
      );
      return;
    }

    tz_data.initializeTimeZones();

    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: initAndroid,
      iOS: initIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      try {
        await androidPlugin?.requestExactAlarmsPermission();
      } catch (error) {
        debugPrint(
          '[NotificationService] Exact alarm permission request failed: $error',
        );
      }
    }

    _initialized = true;
    debugPrint('[NotificationService] Initialized successfully.');
  }

  Future<void> initFCM() async {
    if (kIsWeb) {
      debugPrint('[FCM] Web environment - skipping FCM setup.');
      return;
    }
    if (Firebase.apps.isEmpty) {
      debugPrint('[FCM] Firebase is not configured; skipping FCM setup.');
      return;
    }

    if (_fcmListenersInitialized) return;

    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('[FCM Foreground] Pesan diterima: ${message.messageId}');
        await showInstantNotification(
          id: message.hashCode,
          title: message.notification?.title ?? 'AsuhKita',
          body: message.notification?.body ?? '',
          payload: message.data['payload']?.toString(),
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] Notif di-tap dari background: ${message.data}');
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          '[FCM] App dibuka via notif (killed): ${initialMessage.data}',
        );
      }

      _fcmListenersInitialized = true;
      debugPrint('[FCM] FCM initialized successfully.');
    } catch (e) {
      debugPrint('[FCM] Error initializing FCM: $e');
    }
  }

  Future<void> registerDeviceToken() async {
    if (kIsWeb || Firebase.apps.isEmpty) {
      debugPrint('[FCM] Device registration skipped: Firebase is unavailable.');
      return;
    }

    try {
      final accessToken = await SecureStorageService().getAccessToken();
      if (accessToken == null ||
          accessToken.isEmpty ||
          accessToken.startsWith('token_local_') ||
          accessToken.startsWith('token_bio_') ||
          accessToken.startsWith('token_demo_') ||
          accessToken.startsWith('demo_') ||
          accessToken.startsWith('dummy_')) {
        debugPrint('[FCM] Device registration skipped: no server session.');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Device registration skipped: FCM token unavailable.');
        return;
      }

      await DioClient().dio.post(
        '/notifications/devices',
        data: {'token': token},
      );

      if (!_tokenRefreshListenerRegistered) {
        FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
          await registerDeviceToken();
        });
        _tokenRefreshListenerRegistered = true;
      }
      debugPrint('[FCM] Device token registered with backend.');
    } catch (error) {
      debugPrint('[FCM] Failed to register device token: $error');
    }
  }

  Future<void> unregisterDeviceToken() async {
    if (kIsWeb || Firebase.apps.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await DioClient().dio.delete(
        '/notifications/devices',
        data: {'token': token},
      );
    } catch (error) {
      debugPrint('[FCM] Failed to unregister device token: $error');
    }
  }

  void initFcmStub() {
    debugPrint(
      '[NotificationService] FCM Stub - gunakan initFCM() untuk produksi.',
    );
  }

  Future<AndroidScheduleMode> _getScheduleMode() async {
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
      '[NotificationService] Notification tapped: ${response.payload}',
    );
  }

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        'asuhkita_channel',
        'AsuhKita Pengingat',
        channelDescription: 'Pengingat donasi dan jadwal video call AsuhKita',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

  static const NotificationDetails _notifDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) {
      debugPrint('[NotificationService] (Web stub) Notif: $title - $body');
      return;
    }
    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _notifDetails,
      payload: payload,
    );
    debugPrint('[NotificationService] Instant notif shown: $title');
  }

  Future<void> scheduleVideoCallReminder({
    required int id,
    required String childAlias,
    required DateTime scheduledDateTime,
  }) async {
    if (kIsWeb) return;

    if (!scheduledDateTime.isAfter(DateTime.now())) {
      throw ArgumentError('Waktu pengingat harus berada di masa depan.');
    }

    final tz.TZDateTime scheduledTz = tz.TZDateTime.from(
      scheduledDateTime,
      tz.local,
    );
    final mode = await _getScheduleMode();

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: '📞 Pengingat Video Call AsuhKita',
      body:
          'Sesi video call bersama $childAlias akan segera dimulai! Silakan buka aplikasi.',
      scheduledDate: scheduledTz,
      notificationDetails: _notifDetails,
      androidScheduleMode: mode,
      payload: 'video_call_$id',
    );
    debugPrint(
      '[NotificationService] Video call reminder scheduled for $scheduledTz',
    );
  }

  Future<void> scheduleFinanceReportReminder({
    required int id,
    required String reportCategory,
    required String target,
    required DateTime scheduledDateTime,
  }) async {
    if (kIsWeb) return;

    if (!scheduledDateTime.isAfter(DateTime.now())) {
      throw ArgumentError('Waktu pengingat harus berada di masa depan.');
    }

    final tz.TZDateTime scheduledTz = tz.TZDateTime.from(
      scheduledDateTime,
      tz.local,
    );
    final mode = await _getScheduleMode();

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: '📊 Pengingat Tenggat Laporan Keuangan',
      body:
          'Waktunya menyelesaikan $reportCategory ($target). Mohon rekonsiliasi data kas!',
      scheduledDate: scheduledTz,
      notificationDetails: _notifDetails,
      androidScheduleMode: mode,
      payload: 'finance_report_$id',
    );
    debugPrint(
      '[NotificationService] Finance report reminder scheduled for $scheduledTz',
    );
  }

  Future<void> scheduleMonthlyDonationReminder({
    required String donatorName,
  }) async {
    if (kIsWeb) return;
    const int notifId = 1001;

    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1, 8, 0);
    final scheduledTz = tz.TZDateTime.from(nextMonth, tz.local);
    final mode = await _getScheduleMode();

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: notifId,
      title: 'Waktunya Donasi Bulanan! ❤️',
      body:
          'Halo $donatorName! Donasi bulanan Anda untuk anak asuh belum dilakukan bulan ini.',
      scheduledDate: scheduledTz,
      notificationDetails: _notifDetails,
      androidScheduleMode: mode,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      payload: 'monthly_donation_reminder',
    );
    debugPrint(
      '[NotificationService] Monthly donation reminder scheduled: $scheduledTz',
    );
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('[NotificationService] All notifications cancelled.');
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _flutterLocalNotificationsPlugin.cancel(id: id);
  }
}
