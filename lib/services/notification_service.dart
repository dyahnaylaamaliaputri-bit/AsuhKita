// Letak file: mobile/lib/services/notification_service.dart
// Fungsi: Layanan Notifikasi Lokal (flutter_local_notifications) + Stub FCM Push
//         - scheduleMonthlyReminder  : Pengingat Donasi Bulanan Otomatis (PBI-055, FR-40)
//         - scheduleVideoCallReminder: Pengingat Jadwal Video Call (PBI-055, FR-41)
//         - showInstantNotification  : Notifikasi instan lokal
//         - initFcmStub              : Stub penerimaan Push Notification FCM (PBI-056, FR-42)

import 'dart:io';
import 'package:flutter/foundation.dart';
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

    if (kIsWeb) {
      _initialized = true;
      debugPrint('[NotificationService] Web environment detected - skipping local notification setup.');
      return;
    }

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

    // Minta izin notifikasi & exact alarms di Android
    if (Platform.isAndroid) {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      try {
        await androidPlugin?.requestExactAlarmsPermission();
      } catch (_) {}
    }

    _initialized = true;
    debugPrint('[NotificationService] Initialized successfully.');
  }

  Future<AndroidScheduleMode> _getScheduleMode() async {
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationService] Notification tapped: ${response.payload}');
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

  // -----------------------------------------------------------------
  // FR-40 | PBI-055 - Notifikasi Instan (Langsung Muncul)
  // -----------------------------------------------------------------
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

  // -----------------------------------------------------------------
  // FR-41 | PBI-055 - Pengingat Jadwal Video Call (Scheduled)
  // Berfungsi meskipun aplikasi ditutup / background
  // -----------------------------------------------------------------
  Future<void> scheduleVideoCallReminder({
    required int id,
    required String childAlias,
    required DateTime scheduledDateTime,
  }) async {
    if (kIsWeb) return;

    DateTime targetTime = scheduledDateTime;
    final now = DateTime.now();

    // Jika jadwal lebih dari 30 menit ke depan, ingatkan 30 menit sebelum acara.
    // Jika kurang dari 30 menit, ingatkan tepat pada jam yang dijadwalkan (atau 10 detik lagi jika sudah lewat).
    if (scheduledDateTime.difference(now).inMinutes >= 35) {
      targetTime = scheduledDateTime.subtract(const Duration(minutes: 30));
    } else if (scheduledDateTime.isBefore(now)) {
      targetTime = now.add(const Duration(seconds: 10));
    }

    final tz.TZDateTime scheduledTz = tz.TZDateTime.from(targetTime, tz.local);
    final mode = await _getScheduleMode();

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: '📞 Pengingat Video Call AsuhKita',
      body: 'Sesi video call bersama $childAlias akan segera dimulai! Silakan buka aplikasi.',
      scheduledDate: scheduledTz,
      notificationDetails: _notifDetails,
      androidScheduleMode: mode,
      payload: 'video_call_$id',
    );
    debugPrint('[NotificationService] Video call reminder scheduled for $scheduledTz (mode: $mode)');
  }

  // -----------------------------------------------------------------
  // PBI-055 - Pengingat Tenggat Laporan Keuangan (Admin)
  // Berfungsi meskipun aplikasi ditutup / background
  // -----------------------------------------------------------------
  Future<void> scheduleFinanceReportReminder({
    required int id,
    required String reportCategory,
    required String target,
    required DateTime scheduledDateTime,
  }) async {
    if (kIsWeb) return;

    DateTime targetTime = scheduledDateTime;
    final now = DateTime.now();
    if (scheduledDateTime.isBefore(now)) {
      targetTime = now.add(const Duration(seconds: 10));
    }

    final tz.TZDateTime scheduledTz = tz.TZDateTime.from(targetTime, tz.local);
    final mode = await _getScheduleMode();

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: '📊 Pengingat Tenggat Laporan Keuangan',
      body: 'Waktunya menyelesaikan $reportCategory ($target). Mohon rekonsiliasi data kas!',
      scheduledDate: scheduledTz,
      notificationDetails: _notifDetails,
      androidScheduleMode: mode,
      payload: 'finance_report_$id',
    );
    debugPrint('[NotificationService] Finance report reminder scheduled for $scheduledTz (mode: $mode)');
  }

  // -----------------------------------------------------------------
  // FR-40 | PBI-055 - Pengingat Donasi Bulanan (Berulang setiap bulan)
  // Jadwal: Tanggal 1 setiap bulan pukul 08:00 WIB
  // -----------------------------------------------------------------
  Future<void> scheduleMonthlyDonationReminder({
    required String donatorName,
  }) async {
    if (kIsWeb) return;
    const int notifId = 1001;

    // Hitung tanggal 1 bulan depan pukul 08:00
    final now = DateTime.now();
    var nextMonth = DateTime(now.year, now.month + 1, 1, 8, 0);
    final scheduledTz = tz.TZDateTime.from(nextMonth, tz.local);
    final mode = await _getScheduleMode();

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: notifId,
      title: 'Waktunya Donasi Bulanan! ❤️',
      body: 'Halo $donatorName! Donasi bulanan Anda untuk anak asuh belum dilakukan bulan ini.',
      scheduledDate: scheduledTz,
      notificationDetails: _notifDetails,
      androidScheduleMode: mode,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      payload: 'monthly_donation_reminder',
    );
    debugPrint('[NotificationService] Monthly donation reminder scheduled: $scheduledTz');
  }

  // -----------------------------------------------------------------
  // FR-42 | PBI-056 - Stub Penerimaan Push Notification FCM
  // Pada produksi: integrasikan firebase_messaging + backend trigger
  // -----------------------------------------------------------------
  void initFcmStub() {
    debugPrint('[NotificationService] FCM Stub initialized.');
  }

  // -----------------------------------------------------------------
  // Batalkan semua notifikasi yang dijadwalkan
  // -----------------------------------------------------------------
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('[NotificationService] All notifications cancelled.');
  }

  // Batalkan notifikasi berdasarkan ID
  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _flutterLocalNotificationsPlugin.cancel(id: id);
  }
}
