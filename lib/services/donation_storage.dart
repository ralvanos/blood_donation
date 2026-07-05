import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/export_schema.dart';

class ImportResult {
  const ImportResult.success(this.data)
      : success = true,
        errorMessage = null;

  const ImportResult.failure(this.errorMessage)
      : success = false,
        data = null;

  final bool success;
  final String? errorMessage;
  final Map<String, dynamic>? data;
}

enum ExportResult { success, cancelled, failure }

class DonationStorage {
  static const keyDonations = 'donations';
  static const keyCountdownDays = 'countdown_days';
  static const keyReminderEnabled = 'reminder_enabled';
  static const keyReminderDaysBefore = 'reminder_days_before';
  static const keyLastCatchUpEligibleDate = 'last_catchup_eligible_date';

  static const _notificationIdEligible = 1;
  static const _notificationIdReminder = 2;
  static const _notificationIdCatchUp = 3;

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool? _notificationsPermissionGranted;

  /// Whether notification permission was granted on the last check (Android 13+).
  static bool get notificationsPermissionGranted =>
      _notificationsPermissionGranted ?? true;

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @visibleForTesting
  static List<DateTime> dedupeDonationDates(List<DateTime> dates) {
    final seen = <DateTime>{};
    final deduped = <DateTime>[];
    for (final date in dates) {
      final normalized = dateOnly(date);
      if (seen.add(normalized)) {
        deduped.add(normalized);
      }
    }
    deduped.sort((a, b) => b.compareTo(a));
    return deduped;
  }

  @visibleForTesting
  static List<String> dedupeDonationStrings(List<String> isoStrings) {
    final dates = isoStrings
        .map((entry) {
          try {
            return dateOnly(DateTime.parse(entry));
          } catch (_) {
            return null;
          }
        })
        .whereType<DateTime>()
        .toList();
    return dedupeDonationDates(dates)
        .map((date) => date.toIso8601String())
        .toList();
  }

  /// Whether the user is eligible now or missed a scheduled reminder window.
  static EligibilityCatchUp computeCatchUp({
    required List<DateTime> donations,
    required int countdownDays,
    required bool reminderEnabled,
    required int reminderDaysBefore,
    required DateTime now,
  }) {
    if (!reminderEnabled || donations.isEmpty) {
      return const EligibilityCatchUp(kind: EligibilityCatchUpKind.none);
    }

    final lastDonation = dateOnly(donations.first);
    final eligibleDate = lastDonation.add(Duration(days: countdownDays));
    final today = dateOnly(now);

    if (!today.isBefore(eligibleDate)) {
      return EligibilityCatchUp(
        kind: EligibilityCatchUpKind.eligibleNow,
        eligibleDate: eligibleDate,
      );
    }

    if (reminderDaysBefore > 0) {
      final reminderDate =
          eligibleDate.subtract(Duration(days: reminderDaysBefore));
      if (!today.isBefore(reminderDate)) {
        return EligibilityCatchUp(
          kind: EligibilityCatchUpKind.missedAdvanceReminder,
          eligibleDate: eligibleDate,
          reminderDate: reminderDate,
        );
      }
    }

    return const EligibilityCatchUp(kind: EligibilityCatchUpKind.none);
  }

  /// Shows a one-time catch-up notification per eligibility cycle when the app
  /// opens after a missed scheduled reminder.
  static Future<EligibilityCatchUp> handleMissedReminderCatchUp({
    SharedPreferences? prefs,
  }) async {
    final storage = prefs ?? await SharedPreferences.getInstance();
    final donations = await getDonations();
    final catchUp = computeCatchUp(
      donations: donations,
      countdownDays: storage.getInt(keyCountdownDays) ?? 56,
      reminderEnabled: storage.getBool(keyReminderEnabled) ?? false,
      reminderDaysBefore: storage.getInt(keyReminderDaysBefore) ?? 1,
      now: DateTime.now(),
    );

    if (catchUp.kind == EligibilityCatchUpKind.none) {
      return catchUp;
    }

    if (catchUp.kind == EligibilityCatchUpKind.eligibleNow) {
      final eligibleKey = catchUp.eligibleDate!.toIso8601String();
      final lastShown = storage.getString(keyLastCatchUpEligibleDate);
      if (lastShown != eligibleKey) {
        await _showImmediateNotification(
          id: _notificationIdCatchUp,
          title: 'You can donate again',
          body: 'You are eligible to donate again today.',
        );
        await storage.setString(keyLastCatchUpEligibleDate, eligibleKey);
      }
      return catchUp;
    }

    // Advance reminder window passed but not yet eligible — show once per cycle.
    final reminderKey = catchUp.reminderDate!.toIso8601String();
    final lastShown = storage.getString(keyLastCatchUpEligibleDate);
    if (lastShown != 'reminder:$reminderKey') {
      final daysUntil = catchUp.eligibleDate!.difference(dateOnly(DateTime.now())).inDays;
      await _showImmediateNotification(
        id: _notificationIdCatchUp,
        title: 'Donation window is coming up',
        body: daysUntil <= 0
            ? 'You are eligible to donate again today.'
            : "You're $daysUntil day${daysUntil == 1 ? '' : 's'} away from your next donation.",
      );
      await storage.setString(keyLastCatchUpEligibleDate, 'reminder:$reminderKey');
    }

    return catchUp;
  }

  static Future<List<DateTime>> getDonations() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(keyDonations);
    if (list == null) return [];

    final dedupedStrings = dedupeDonationStrings(list);
    if (dedupedStrings.length != list.length) {
      await prefs.setStringList(keyDonations, dedupedStrings);
    }

    return dedupeDonationDates(
      dedupedStrings.map((entry) => dateOnly(DateTime.parse(entry))).toList(),
    );
  }

  static Future<void> addDonation(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(keyDonations) ?? [];
    final normalized = dateOnly(date);
    final alreadyExists = list.any((entry) {
      try {
        return dateOnly(DateTime.parse(entry)) == normalized;
      } catch (_) {
        return false;
      }
    });
    if (alreadyExists) return;

    list.add(normalized.toIso8601String());
    await prefs.setStringList(keyDonations, list);
    await _rescheduleNotificationsFromPrefs(prefs);
  }

  static Future<int> getCountdownDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyCountdownDays) ?? 56;
  }

  static Future<void> setCountdownDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyCountdownDays, days);
    await _rescheduleNotificationsFromPrefs(prefs);
  }

  static Future<bool> getReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyReminderEnabled) ?? false;
  }

  static Future<void> setReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyReminderEnabled, enabled);
    await _rescheduleNotificationsFromPrefs(prefs);
  }

  static Future<int> getReminderDaysBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyReminderDaysBefore) ?? 1;
  }

  static Future<void> setReminderDaysBefore(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyReminderDaysBefore, days);
    await _rescheduleNotificationsFromPrefs(prefs);
  }

  static Future<void> removeDonation(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(keyDonations) ?? [];
    final normalized = dateOnly(date);
    final index = list.indexWhere((entry) {
      try {
        return dateOnly(DateTime.parse(entry)) == normalized;
      } catch (_) {
        return false;
      }
    });
    if (index >= 0) {
      list.removeAt(index);
      await prefs.setStringList(keyDonations, list);
      await _rescheduleNotificationsFromPrefs(prefs);
    }
  }

  static Future<void> initNotifications() async {
    tz_data.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings: initSettings);

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'donation_reminders',
        'Donation Reminders',
        description: 'Scheduled reminders for blood donation eligibility',
        importance: Importance.high,
      ),
    );

    final permissionGranted =
        await androidPlugin?.requestNotificationsPermission();
    _notificationsPermissionGranted = permissionGranted ?? true;

    final prefs = await SharedPreferences.getInstance();
    await _rescheduleNotificationsFromPrefs(prefs);
    await handleMissedReminderCatchUp(prefs: prefs);
  }

  static Future<void> _rescheduleNotificationsFromPrefs(
      SharedPreferences prefs) async {
    final donations = await getDonations();
    await scheduleReminders(
      donations: donations,
      countdownDays: prefs.getInt(keyCountdownDays) ?? 56,
      reminderEnabled: prefs.getBool(keyReminderEnabled) ?? false,
      reminderDaysBefore: prefs.getInt(keyReminderDaysBefore) ?? 1,
    );
  }

  static Future<void> scheduleReminders({
    required List<DateTime> donations,
    required int countdownDays,
    required bool reminderEnabled,
    required int reminderDaysBefore,
  }) async {
    await _notificationsPlugin.cancel(id: _notificationIdEligible);
    await _notificationsPlugin.cancel(id: _notificationIdReminder);

    if (!reminderEnabled || donations.isEmpty) return;

    final lastDonation = dateOnly(donations.first);
    final eligibleDate = lastDonation.add(Duration(days: countdownDays));
    final now = tz.TZDateTime.now(tz.local);

    final eligibleScheduled = _atNineAm(eligibleDate);
    if (!eligibleScheduled.isBefore(now)) {
      await _scheduleNotification(
        id: _notificationIdEligible,
        scheduledDate: eligibleScheduled,
        title: 'You can donate again',
        body: 'You are eligible to donate again today.',
      );
    }

    if (reminderDaysBefore > 0) {
      final reminderDate = eligibleDate.subtract(Duration(days: reminderDaysBefore));
      final reminderScheduled = _atNineAm(reminderDate);
      if (!reminderScheduled.isBefore(now)) {
        await _scheduleNotification(
          id: _notificationIdReminder,
          scheduledDate: reminderScheduled,
          title: 'Donation window is coming up',
          body:
              "You're $reminderDaysBefore day${reminderDaysBefore == 1 ? '' : 's'} away from your next donation.",
        );
      }
    }
  }

  static tz.TZDateTime _atNineAm(DateTime date) {
    final day = dateOnly(date);
    return tz.TZDateTime(tz.local, day.year, day.month, day.day, 9);
  }

  static Future<void> _scheduleNotification({
    required int id,
    required tz.TZDateTime scheduledDate,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'donation_reminders',
      'Donation Reminders',
      channelDescription:
          'Scheduled reminders for blood donation eligibility',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> _showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!notificationsPermissionGranted) return;

    const androidDetails = AndroidNotificationDetails(
      'donation_reminders',
      'Donation Reminders',
      channelDescription:
          'Scheduled reminders for blood donation eligibility',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  static Future<ExportResult> exportData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final donations = dedupeDonationStrings(
        prefs.getStringList(keyDonations) ?? [],
      );
      final data = {
        'schema_version': kExportSchemaVersion,
        'exported_at': DateTime.now().toIso8601String(),
        keyDonations: donations,
        keyCountdownDays: prefs.getInt(keyCountdownDays) ?? 56,
        keyReminderEnabled: prefs.getBool(keyReminderEnabled) ?? false,
        keyReminderDaysBefore: prefs.getInt(keyReminderDaysBefore) ?? 1,
      };

      final jsonString = jsonEncode(data);
      final bytes = utf8.encode(jsonString);

      final path = await FilePicker.saveFile(
        dialogTitle: 'Save donation data',
        fileName: 'blood_donation_data.json',
        bytes: Uint8List.fromList(bytes),
      );

      if (path == null) return ExportResult.cancelled;
      return ExportResult.success;
    } catch (e) {
      debugPrint('Export error: $e');
      return ExportResult.failure;
    }
  }

  static Future<ImportResult> pickAndParseImport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null) {
      return const ImportResult.failure('No file selected.');
    }

    try {
      final bytes = result.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        return const ImportResult.failure('The selected file is empty.');
      }

      final jsonString = utf8.decode(bytes);
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return const ImportResult.failure('Invalid backup file: expected a JSON object.');
      }

      return _validateImportMap(decoded);
    } on FormatException {
      return const ImportResult.failure('Invalid backup file: malformed JSON.');
    } catch (e) {
      debugPrint('Import parse error: $e');
      return const ImportResult.failure('Could not read the selected file.');
    }
  }

  @visibleForTesting
  static ImportResult validateImportMap(Map<String, dynamic> data) =>
      _validateImportMap(data);

  static ImportResult _validateImportMap(Map<String, dynamic> data) {
    final validated = <String, dynamic>{};

    if (data.containsKey('schema_version')) {
      final version = data['schema_version'];
      if (version is! int) {
        return const ImportResult.failure('Invalid backup file: schema_version must be a number.');
      }
      if (version > kExportSchemaVersion) {
        return const ImportResult.failure(
          'This backup was created by a newer app version. Please update the app and try again.',
        );
      }
    }

    if (data.containsKey(keyDonations)) {
      final rawDonations = data[keyDonations];
      if (rawDonations is! List) {
        return const ImportResult.failure('Invalid backup file: donations must be a list.');
      }
      final donations = <String>[];
      for (final entry in rawDonations) {
        if (entry is! String) continue;
        try {
          donations.add(dateOnly(DateTime.parse(entry)).toIso8601String());
        } catch (_) {
          // Skip invalid donation dates.
        }
      }
      validated[keyDonations] = dedupeDonationStrings(donations);
    }

    if (data.containsKey(keyCountdownDays)) {
      final days = data[keyCountdownDays];
      if (days is! int || days < 1 || days > 365) {
        return const ImportResult.failure('Invalid backup file: countdown_days must be between 1 and 365.');
      }
      validated[keyCountdownDays] = days;
    }

    if (data.containsKey(keyReminderEnabled)) {
      final enabled = data[keyReminderEnabled];
      if (enabled is! bool) {
        return const ImportResult.failure('Invalid backup file: reminder_enabled must be true or false.');
      }
      validated[keyReminderEnabled] = enabled;
    }

    if (data.containsKey(keyReminderDaysBefore)) {
      final days = data[keyReminderDaysBefore];
      if (days is! int || days < 0 || days > 30) {
        return const ImportResult.failure(
          'Invalid backup file: reminder_days_before must be between 0 and 30.',
        );
      }
      validated[keyReminderDaysBefore] = days;
    }

    if (validated.isEmpty) {
      return const ImportResult.failure('No recognizable data found in this backup file.');
    }

    return ImportResult.success(validated);
  }

  static Future<void> applyImport(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    if (data.containsKey(keyDonations)) {
      final deduped = dedupeDonationStrings(
        List<String>.from(data[keyDonations] as List),
      );
      await prefs.setStringList(keyDonations, deduped);
    }
    if (data.containsKey(keyCountdownDays)) {
      await prefs.setInt(keyCountdownDays, data[keyCountdownDays] as int);
    }
    if (data.containsKey(keyReminderEnabled)) {
      await prefs.setBool(keyReminderEnabled, data[keyReminderEnabled] as bool);
    }
    if (data.containsKey(keyReminderDaysBefore)) {
      await prefs.setInt(keyReminderDaysBefore, data[keyReminderDaysBefore] as int);
    }

    await _rescheduleNotificationsFromPrefs(prefs);
  }
}

enum EligibilityCatchUpKind {
  none,
  eligibleNow,
  missedAdvanceReminder,
}

class EligibilityCatchUp {
  const EligibilityCatchUp({
    required this.kind,
    this.eligibleDate,
    this.reminderDate,
  });

  final EligibilityCatchUpKind kind;
  final DateTime? eligibleDate;
  final DateTime? reminderDate;
}
