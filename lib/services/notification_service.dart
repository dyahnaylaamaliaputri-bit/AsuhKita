// Letak file: mobile/lib/services/notification_service.dart
// Fungsi: Layanan Notifikasi Lokal (flutter_local_notifications) + Stub FCM Push
//         - scheduleMonthlyReminder  : Pengingat Donasi Bulanan Otomatis (PBI-055, FR-40)
//         - scheduleVideoCallReminder: Pengingat Jadwal Video Call (PBI-055, FR-41)
//         - showInstantNotification  : Notifikasi instan lokal
//         - initFcmStub              : Stub penerimaan Push Notification FCM (PBI-056, FR-42)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // -----------------------------------------------------------------
  // Inisialisasi plugin (panggil sekali di main.dart)
  // -----------------------------------------------------------------
  Future<void> initialize() async {
    if (_initialized) return;

    // Inisialisasi timezone
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

    // Minta izin notifikasi di Android 13+
    if (Platform.isAndroid) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
    debugPrint('[NotificationService] Initialized successfully.');
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationService] Notification tapped: ${response.payload}');
    // Navigasi tambahan bisa dihandle lewat payload di sini
  }

  // Detail channel Android
  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'asuhkita_channel',          // channel ID
    'AsuhKita Pengingat',        // channel name
    channelDescription: 'Pengingat donasi dan jadwal video call AsuhKita',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
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

  // -----------------------------------------------------------------
  // FR-40 | PBI-055 - Notifikasi Instan (Langsung Muncul)
  // -----------------------------------------------------------------
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _notifDetails,
      payload: payload,
    );
    debugPrint('[NotificationService] Instant notif shown: $title');
  }

  // -----------------------------------------------------------------
  // FR-41 | PBI-055 - Pengingat Jadwal Video Call (Scheduled)
  // Dipicu H-1 dan H-0 (30 menit sebelum panggilan)
  // -----------------------------------------------------------------
  Future<void> scheduleVideoCallReminder({
    required int id,
    required String childAlias,
    required DateTime scheduledDateTime,
  }) async {
    final tz.TZDateTime scheduledTz = tz.TZDateTime.from(
      scheduledDateTime.subtract(const Duration(minutes: 30)),
      tz.local,
    );

    if (scheduledTz.isBefore(tz.TZDateTime.now(tz.local))) {
      debugPrint('[NotificationService] scheduledTz sudah lewat, skip.');
      return;
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: 'Pengingat Video Call AsuhKita',
      body: '30 menit lagi: sesi video call dengan $childAlias akan dimulai!',
      scheduledDate: scheduledTz,
      notificationDetails: _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'video_call_$id',
    );
    debugPrint(
        '[NotificationService] Video call reminder scheduled: $scheduledTz');
  }

  // -----------------------------------------------------------------
  // FR-40 | PBI-055 - Pengingat Donasi Bulanan (Berulang setiap bulan)
  // Jadwal: Tanggal 1 setiap bulan pukul 08:00 WIB
  // -----------------------------------------------------------------
  Future<void> scheduleMonthlyDonationReminder({
    required String donatorName,
  }) async {
    const int notifId = 1001;

    // Hitung tanggal 1 bulan depan pukul 08:00
    final now = DateTime.now();
    var nextMonth = DateTime(now.year, now.month + 1, 1, 8, 0);
    final scheduledTz = tz.TZDateTime.from(nextMonth, tz.local);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: notifId,
      title: 'Waktunya Donasi Bulanan! ❤️',
      body: 'Halo $donatorName! Donasi bulanan Anda untuk anak asuh belum dilakukan bulan ini.',
      scheduledDate: scheduledTz,
      notificationDetails: _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      payload: 'monthly_donation_reminder',
    );
    debugPrint(
        '[NotificationService] Monthly donation reminder scheduled: $scheduledTz');
  }

  // -----------------------------------------------------------------
  // FR-42 | PBI-056 - Stub Penerimaan Push Notification FCM
  // Pada produksi: integrasikan firebase_messaging + backend trigger
  // -----------------------------------------------------------------
  void initFcmStub() {
    // Stub: Simulasi menerima push dari server backend AsuhKita
    // Di produksi ganti dengan:
    //   FirebaseMessaging.onMessage.listen((RemoteMessage msg) { ... });
    //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) { ... });
    debugPrint('[NotificationService] FCM Stub initialized. '
        'Integrasikan firebase_messaging untuk push nyata (PBI-056, FR-42).');
  }

  // -----------------------------------------------------------------
  // Batalkan semua notifikasi yang dijadwalkan
  // -----------------------------------------------------------------
  Future<void> cancelAll() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('[NotificationService] All notifications cancelled.');
  }

  // Batalkan notifikasi berdasarkan ID
  Future<void> cancel(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id: id);
  }
}
