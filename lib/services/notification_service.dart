import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  // ── Plugin ─────────────────────────────────────────────────────────────────
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Notification channel constants ─────────────────────────────────────────
  static const String _channelId = 'medicine_reminder_channel';
  static const String _channelName = 'Medicine Reminders';
  static const String _channelDesc =
      'Daily reminders to take your medicines on time';

  // Water reminder channel
  static const String _waterChannelId = 'water_reminder_channel';
  static const String _waterChannelName = 'Water Reminders';
  static const String _waterChannelDesc =
      'Reminders to drink water throughout the day';
  static const int _waterNotifBase = 200000;
  static const int _maxWaterSlots = 50;

  // Daily reminder channel (IDs: 300000 + reminderId*7 + daySlot)
  static const String _dailyChannelId = 'daily_reminder_channel';
  static const String _dailyChannelName = 'Daily Reminders';
  static const String _dailyChannelDesc = 'Your personal daily reminders';
  static const int _dailyNotifBase = 300000;

  // Max doses per medicine we track
  static const int _maxDosesPerMedicine = 10;

  // ── Initialise ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    try {
      // 1. Load tz database and set device local timezone.
      // Some physical devices report timezone IDs that may not resolve directly.
      tz.initializeTimeZones();
      await _configureLocalTimezone();

      // 2. Android – create high-importance channel explicitly
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // 3. iOS settings
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(settings: settings);

      // 4. Explicitly create Android notification channels
      await _createAndroidChannel();
      await _createWaterAndroidChannel();
      await _createDailyAndroidChannel();

      // 5. Request permissions (Android 13+ & exact alarms)
      await requestPermissions();
      _initialized = true;

      debugPrint('[Notifications] Service initialized successfully');
    } catch (e, st) {
      debugPrint('[Notifications] Init error: $e\n$st');
    }
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('[Notifications] Device timezone: $timeZoneName');
    } catch (e) {
      // Fallback keeps notification scheduling working even if the timezone ID
      // returned by a specific device cannot be mapped.
      tz.setLocalLocation(tz.UTC);
      debugPrint('[Notifications] Timezone lookup failed, fallback to UTC: $e');
    }
  }

  // ── Create Android channel ─────────────────────────────────────────────────
  Future<void> _createAndroidChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    debugPrint('[Notifications] Android channel created: $_channelId');
  }

  // ── Create Water Android channel ──────────────────────────────────────────
  Future<void> _createWaterAndroidChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _waterChannelId,
      _waterChannelName,
      description: _waterChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    debugPrint('[Notifications] Water channel created: $_waterChannelId');
  }

  // ── Water notification details ─────────────────────────────────────────────
  NotificationDetails get _waterNotificationDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          _waterChannelId,
          _waterChannelName,
          channelDescription: _waterChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          ticker: 'Water Reminder',
        ),
      );

  // ── Schedule Water Reminders ───────────────────────────────────────────────
  Future<void> scheduleWaterReminders({
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required int intervalHours,
    required double goalLiters,
    required bool everyday,
  }) async {
    try {
      if (!_initialized) await init();
      await cancelWaterReminders();

      // Build time slots within the window
      final slots = <TimeOfDay>[];
      int h = startTime.hour;
      int m = startTime.minute;
      final endMins = endTime.hour * 60 + endTime.minute;

      while (slots.length < _maxWaterSlots) {
        final slotMins = h * 60 + m;
        if (slotMins > endMins) break;
        slots.add(TimeOfDay(hour: h, minute: m));
        h += intervalHours;
        if (h > 23) break;
      }

      if (slots.isEmpty) return;
      final mlPerGlass = ((goalLiters * 1000) / slots.length).round();

      for (int i = 0; i < slots.length; i++) {
        final slot = slots[i];
        final scheduledDate = _nextDailyOccurrence(slot, 0);
        await _plugin.zonedSchedule(
          id: _waterNotifBase + i,
          title: '💧 Time to Drink Water!',
          body: 'Drink ${mlPerGlass}ml now · Stay hydrated! 🌊',
          scheduledDate: scheduledDate,
          notificationDetails: _waterNotificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents:
              everyday ? DateTimeComponents.time : null,
        );
        debugPrint('[Notifications] Water slot #$i at $slot (${everyday ? "daily" : "once"})');
      }
    } catch (e, st) {
      debugPrint('[Notifications] Water schedule error: $e\n$st');
    }
  }

  // ── Cancel Water Reminders ─────────────────────────────────────────────────
  Future<void> cancelWaterReminders() async {
    try {
      for (int i = 0; i < _maxWaterSlots; i++) {
        await _plugin.cancel(id: _waterNotifBase + i);
      }
      debugPrint('[Notifications] Cancelled all water reminders');
    } catch (e) {
      debugPrint('[Notifications] Cancel water error: $e');
    }
  }

  // ── Request permissions ────────────────────────────────────────────────────
  Future<bool> requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl == null) return false;

    // POST_NOTIFICATIONS (Android 13+)
    bool? notifGranted;
    try {
      notifGranted = await androidImpl.requestNotificationsPermission();
    } catch (e) {
      debugPrint('[Notifications] Notification permission request error: $e');
    }

    // SCHEDULE_EXACT_ALARM (Android 12+). If it fails, we still schedule using
    // inexact mode so reminders continue to work on real devices.
    bool? exactGranted;
    try {
      exactGranted = await androidImpl.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('[Notifications] Exact alarm permission request error: $e');
    }

    debugPrint(
        '[Notifications] Permissions – notifications: $notifGranted, exact: $exactGranted');

    // On older Android versions this can be null; treat null as not-blocking.
    return notifGranted != false;
  }

  // ── Build notification details ─────────────────────────────────────────────
  NotificationDetails get _notificationDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          ticker: 'Medicine Reminder',
        ),
      );

  // ── Schedule daily reminders for one medicine ──────────────────────────────
  Future<void> scheduleMedicineReminder({
    required int id,
    required String medicineName,
    required List<TimeOfDay> timings,
    required int reminderAdvanceMinutes,
  }) async {
    try {
      if (!_initialized) {
        await init();
      }
      // Always cancel old ones first to avoid duplicates
      await cancelMedicineReminders(id);

      for (int i = 0; i < timings.length; i++) {
        final TimeOfDay dose = timings[i];

        // Build target TZDateTime for the dose in local tz
        final tz.TZDateTime doseTime =
            _nextDailyOccurrence(dose, reminderAdvanceMinutes);

        final int notifId = _notifId(id, i);

        await _plugin.zonedSchedule(
          id: notifId,
          title: '💊 Medicine Reminder',
          body: reminderAdvanceMinutes == 0
              ? 'Time to take your $medicineName!'
              : 'Take $medicineName in $reminderAdvanceMinutes minute${reminderAdvanceMinutes == 1 ? '' : 's'}!',
          scheduledDate: doseTime,
          notificationDetails: _notificationDetails,
          // Use inexact while idle for better reliability across real devices
          // where exact-alarm special access may be denied.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time, // repeat daily
        );

        debugPrint(
            '[Notifications] Scheduled #$notifId for "$medicineName" at $doseTime');
      }
    } catch (e, st) {
      debugPrint('[Notifications] Schedule error: $e\n$st');
    }
  }

  // ── Cancel all reminders for a medicine ───────────────────────────────────
  Future<void> cancelMedicineReminders(int id) async {
    try {
      for (int i = 0; i < _maxDosesPerMedicine; i++) {
        await _plugin.cancel(id: _notifId(id, i));
      }
      debugPrint('[Notifications] Cancelled all reminders for medicine #$id');
    } catch (e) {
      debugPrint('[Notifications] Cancel error: $e');
    }
  }

  // ── Schedule Expiry Reminder for Items ─────────────────────────────────────
  Future<void> scheduleItemExpiryReminder({
    required int id,
    required String itemName,
    required DateTime expiryDate,
    required int advanceDays,
  }) async {
    try {
      if (!_initialized) {
        await init();
      }
      await cancelItemReminder(id);
      
      if (advanceDays < 0) return;

      // Schedule for 9:00 AM on the target date
      final targetDate = expiryDate.subtract(Duration(days: advanceDays));
      final tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local,
        targetDate.year,
        targetDate.month,
        targetDate.day,
        9, // 9 AM
        0,
      );

      // If scheduled date is in the past, don't schedule
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        debugPrint('[Notifications] Scheduled date is in the past, skipping item #$id');
        return;
      }

      // unique id for item reminders, offset by 100000 to avoid clash with medicines
      final notifId = 100000 + id;

      String body = advanceDays == 0 
          ? '$itemName expires today!' 
          : '$itemName expires in $advanceDays day${advanceDays == 1 ? '' : 's'}.';

      await _plugin.zonedSchedule(
        id: notifId,
        title: '🛒 Item Expiry Reminder',
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint('[Notifications] Scheduled expiry for $itemName on $scheduledDate (advance: $advanceDays days)');
    } catch (e) {
      debugPrint('[Notifications] Error scheduling expiry: $e');
    }
  }

  // ── Cancel Expiry Reminder for an item ────────────────────────────────────
  Future<void> cancelItemReminder(int id) async {
    try {
      await _plugin.cancel(id: 100000 + id);
      debugPrint('[Notifications] Cancelled expiry reminder for item #$id');
    } catch (e) {
      debugPrint('[Notifications] Cancel item reminder error: $e');
    }
  }

  // ── Cancel ALL scheduled notifications ────────────────────────────────────
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('[Notifications] All notifications cancelled');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns the next TZDateTime for a given [dose] time minus [advanceMinutes].
  tz.TZDateTime _nextDailyOccurrence(
      TimeOfDay dose, int advanceMinutes) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // Build candidate time for today
    tz.TZDateTime candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      dose.hour,
      dose.minute,
    ).subtract(Duration(minutes: advanceMinutes));

    // If already in the past, push to tomorrow
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  /// Unique notification ID per medicine+dose slot.
  int _notifId(int medicineId, int doseIndex) =>
      medicineId * _maxDosesPerMedicine + doseIndex;

  // ── Create Daily Reminder Android channel ────────────────────────────────
  Future<void> _createDailyAndroidChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _dailyChannelId,
      _dailyChannelName,
      description: _dailyChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    debugPrint('[Notifications] Daily channel created: $_dailyChannelId');
  }

  NotificationDetails get _dailyNotificationDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyChannelId,
          _dailyChannelName,
          channelDescription: _dailyChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          ticker: 'Daily Reminder',
        ),
      );

  // ── Schedule a daily reminder ────────────────────────────────────────────
  /// [weekdays]: 1=Mon … 7=Sun. Pass empty/all-7 for everyday.
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    required List<int> weekdays,
  }) async {
    try {
      if (!_initialized) await init();
      await cancelDailyReminder(id);

      final isEveryday = weekdays.isEmpty || weekdays.length == 7;
      final notifBody = body.trim().isEmpty ? title : body;

      if (isEveryday) {
        await _plugin.zonedSchedule(
          id: _dailyNotifBase + id * 7,
          title: '🔔 $title',
          body: notifBody,
          scheduledDate: _nextDailyOccurrence(time, 0),
          notificationDetails: _dailyNotificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        debugPrint('[Notifications] Daily reminder #$id scheduled (everyday) at $time');
      } else {
        for (final day in weekdays) {
          final scheduled = _nextWeekdayOccurrence(time, day);
          await _plugin.zonedSchedule(
            id: _dailyNotifBase + id * 7 + (day - 1),
            title: '🔔 $title',
            body: notifBody,
            scheduledDate: scheduled,
            notificationDetails: _dailyNotificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
        debugPrint('[Notifications] Daily reminder #$id scheduled for weekdays: $weekdays');
      }
    } catch (e, st) {
      debugPrint('[Notifications] Daily reminder schedule error: $e\n$st');
    }
  }

  // ── Cancel a daily reminder ─────────────────────────────────────────────
  Future<void> cancelDailyReminder(int id) async {
    try {
      for (int d = 0; d < 7; d++) {
        await _plugin.cancel(id: _dailyNotifBase + id * 7 + d);
      }
      debugPrint('[Notifications] Cancelled daily reminder #$id');
    } catch (e) {
      debugPrint('[Notifications] Cancel daily reminder error: $e');
    }
  }

  /// Returns the next [tz.TZDateTime] for a given [time] on [weekday] (1=Mon…7=Sun).
  tz.TZDateTime _nextWeekdayOccurrence(TimeOfDay time, int weekday) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime candidate = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, time.hour, time.minute,
    );
    // Advance until we land on the right weekday and the time is in the future.
    while (candidate.weekday != weekday || candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}
