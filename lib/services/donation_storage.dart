import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/donation_arm.dart';
import '../models/donation_type.dart';
import '../models/eligibility_matrix.dart';
import '../models/export_schema.dart';
import '../models/typed_donation.dart';
import 'auto_lock_policy.dart';
import 'encrypted_store.dart';
import 'export_crypto.dart';

class ImportResult {
  const ImportResult.success(this.data)
      : success = true,
        needsPassphrase = false,
        encryptedEnvelope = null,
        errorMessage = null;

  const ImportResult.needsPassphrase(this.encryptedEnvelope)
      : success = false,
        needsPassphrase = true,
        data = null,
        errorMessage = null;

  const ImportResult.failure(this.errorMessage)
      : success = false,
        needsPassphrase = false,
        encryptedEnvelope = null,
        data = null;

  final bool success;
  final bool needsPassphrase;
  final String? errorMessage;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? encryptedEnvelope;
}

enum ExportResult { success, cancelled, failure }

/// Snapshot used when scheduling reminders across types.
class _EligibilityCandidate {
  const _EligibilityCandidate({
    required this.type,
    required this.eligibleDate,
    required this.countdownDays,
  });

  final DonationType type;
  final DateTime eligibleDate;
  final int countdownDays;
}

class DonationStorage {
  static const keyDonations = 'donations';
  static const keyDonationsPlasma = 'donations_plasma';
  static const keyDonationsPlatelet = 'donations_platelet';
  static const keyDonationsDoubleRed = 'donations_double_red';
  static const keyCountdownDays = 'countdown_days';
  static const keyCountdownDaysPlasma = 'countdown_days_plasma';
  static const keyCountdownDaysPlatelet = 'countdown_days_platelet';
  static const keyCountdownDaysDoubleRed = 'countdown_days_double_red';
  static const keyActiveDonationType = DonationType.prefsKeyActive;
  static const keyReminderEnabled = 'reminder_enabled';
  static const keyReminderDaysBefore = 'reminder_days_before';
  static const keyLastCatchUpEligibleDate = 'last_catchup_eligible_date';
  static const keyDonorNumber = 'donor_number';
  static const keyJourneyHintDoubleRedDismissed =
      'journey_hint_double_red_dismissed';
  static const keyAutoLockTimeoutSeconds = 'auto_lock_timeout_seconds';

  static const _notificationIdEligible = 1;
  static const _notificationIdReminder = 2;
  static const _notificationIdCatchUp = 3;

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool? _notificationsPermissionGranted;

  static EncryptedStore get _store => EncryptedStore.instance;

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

  /// Parses an on-device string or an export value (ISO string, JSON string, or map).
  @visibleForTesting
  static DonationEntry? tryParseDonationValue(dynamic raw) {
    if (raw is Map) {
      final dateRaw = raw['date'];
      if (dateRaw is! String) return null;
      try {
        return DonationEntry(
          date: dateOnly(DateTime.parse(dateRaw)),
          arm: DonationArm.tryFromId(raw['arm']),
        );
      } catch (_) {
        return null;
      }
    }
    if (raw is! String) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('{')) {
      try {
        return tryParseDonationValue(jsonDecode(trimmed));
      } catch (_) {
        return null;
      }
    }
    try {
      return DonationEntry(date: dateOnly(DateTime.parse(trimmed)));
    } catch (_) {
      return null;
    }
  }

  /// On-device list value: ISO date when untagged, JSON object when an arm is set.
  @visibleForTesting
  static String encodeDonationEntry(DonationEntry entry) {
    final iso = dateOnly(entry.date).toIso8601String();
    final arm = entry.arm;
    if (arm == null) return iso;
    return jsonEncode({'date': iso, 'arm': arm.id});
  }

  /// Export list value: ISO string when untagged, map when an arm is set.
  @visibleForTesting
  static dynamic toExportDonationValue(DonationEntry entry) {
    final iso = dateOnly(entry.date).toIso8601String();
    final arm = entry.arm;
    if (arm == null) return iso;
    return {'date': iso, 'arm': arm.id};
  }

  @visibleForTesting
  static List<DonationEntry> parseAndDedupeEntries(Iterable<dynamic> raw) {
    final byDate = <DateTime, DonationEntry>{};
    for (final value in raw) {
      final entry = tryParseDonationValue(value);
      if (entry == null) continue;
      final existing = byDate[entry.date];
      if (existing == null || (existing.arm == null && entry.arm != null)) {
        byDate[entry.date] = entry;
      }
    }
    final entries = byDate.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  @visibleForTesting
  static List<String> dedupeDonationStrings(List<String> isoStrings) {
    return parseAndDedupeEntries(isoStrings).map(encodeDonationEntry).toList();
  }

  static Future<DonationType> getActiveDonationType() async {
    return DonationType.fromId(await _store.getString(keyActiveDonationType));
  }

  static Future<void> setActiveDonationType(DonationType type) async {
    await _store.setString(keyActiveDonationType, type.id);
  }

  /// Whether the user is eligible now or missed a scheduled reminder window.
  ///
  /// Reminders use the **soonest** eligibility across all types that have at
  /// least one donation (shared reminder_enabled / reminder_days_before).
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
  ///
  /// Uses soonest eligibility across types so existing reminder flow stays intact.
  static Future<EligibilityCatchUp> handleMissedReminderCatchUp() async {
    final reminderEnabled = await _store.getBool(keyReminderEnabled) ?? false;
    if (!reminderEnabled) {
      return const EligibilityCatchUp(kind: EligibilityCatchUpKind.none);
    }

    final candidate = await _soonestEligibilityCandidate();
    if (candidate == null) {
      return const EligibilityCatchUp(kind: EligibilityCatchUpKind.none);
    }

    final catchUp = computeCatchUp(
      donations: [
        candidate.eligibleDate
            .subtract(Duration(days: candidate.countdownDays)),
      ],
      countdownDays: candidate.countdownDays,
      reminderEnabled: true,
      reminderDaysBefore: await _store.getInt(keyReminderDaysBefore) ?? 1,
      now: DateTime.now(),
    ).copyWith(type: candidate.type);

    if (catchUp.kind == EligibilityCatchUpKind.none) {
      return catchUp;
    }

    final typeLabel = candidate.type.displayName;

    if (catchUp.kind == EligibilityCatchUpKind.eligibleNow) {
      final eligibleKey =
          '${candidate.type.id}:${catchUp.eligibleDate!.toIso8601String()}';
      final lastShown = await _store.getString(keyLastCatchUpEligibleDate);
      if (lastShown != eligibleKey) {
        await _showImmediateNotification(
          id: _notificationIdCatchUp,
          title: '$typeLabel: you\'re eligible again',
          body: 'You are eligible to donate $typeLabel again today.',
        );
        await _store.setString(keyLastCatchUpEligibleDate, eligibleKey);
      }
      return catchUp;
    }

    // Advance reminder window passed but not yet eligible — show once per cycle.
    final reminderKey =
        '${candidate.type.id}:reminder:${catchUp.reminderDate!.toIso8601String()}';
    final lastShown = await _store.getString(keyLastCatchUpEligibleDate);
    if (lastShown != reminderKey) {
      final daysUntil =
          catchUp.eligibleDate!.difference(dateOnly(DateTime.now())).inDays;
      await _showImmediateNotification(
        id: _notificationIdCatchUp,
        title: daysUntil <= 0
            ? '$typeLabel: you\'re eligible again'
            : '$typeLabel: donation window coming up',
        body: daysUntil <= 0
            ? 'You are eligible to donate $typeLabel again today.'
            : "You're $daysUntil day${daysUntil == 1 ? '' : 's'} away from your next $typeLabel donation.",
      );
      await _store.setString(keyLastCatchUpEligibleDate, reminderKey);
    }

    return catchUp;
  }

  static Future<_EligibilityCandidate?> _soonestEligibilityCandidate() async {
    final snapshot = await getEligibilitySnapshot();
    if (!snapshot.hasHistory || snapshot.soonestType == null) return null;
    final row = snapshot.row(snapshot.soonestType!);
    return _EligibilityCandidate(
      type: row.type,
      eligibleDate: row.nextEligible!,
      countdownDays: row.appliedWaitDays,
    );
  }

  static Future<List<DateTime>> getDonations([DonationType? type]) async {
    final records = await getDonationRecords(type);
    return records.map((e) => e.date).toList();
  }

  /// Donations for [type] with optional arm tags, newest first.
  static Future<List<DonationEntry>> getDonationRecords([
    DonationType? type,
  ]) async {
    final resolved = type ?? await getActiveDonationType();
    final list = await _store.getStringList(resolved.donationsPrefsKey);
    if (list == null) return [];

    final entries = parseAndDedupeEntries(list);
    final encoded = entries.map(encodeDonationEntry).toList();
    if (encoded.length != list.length) {
      await _store.setStringList(resolved.donationsPrefsKey, encoded);
    }

    return entries;
  }

  /// Most recent L or R tag for [type] (skips dual-needle "Both").
  static Future<DonationArm?> lastTaggedSingleArm([DonationType? type]) async {
    final records = await getDonationRecords(type);
    for (final record in records) {
      final arm = record.arm;
      if (arm != null && arm.isSingleNeedle) return arm;
    }
    return null;
  }

  static Future<void> addDonation(
    DateTime date, {
    DonationType? type,
    DonationArm? arm,
  }) async {
    final resolved = type ?? await getActiveDonationType();
    final list = await _store.getStringList(resolved.donationsPrefsKey) ?? [];
    final entries = parseAndDedupeEntries(list);
    final normalized = dateOnly(date);
    if (entries.any((entry) => entry.date == normalized)) return;

    entries.add(DonationEntry(date: normalized, arm: arm));
    entries.sort((a, b) => b.date.compareTo(a.date));
    await _store.setStringList(
      resolved.donationsPrefsKey,
      entries.map(encodeDonationEntry).toList(),
    );
    await _rescheduleNotifications();
  }

  /// Sets or clears the arm tag on an existing donation (same calendar day).
  static Future<void> updateDonationArm({
    required DateTime date,
    required DonationType type,
    DonationArm? arm,
  }) async {
    final list = await _store.getStringList(type.donationsPrefsKey) ?? [];
    final entries = parseAndDedupeEntries(list);
    final normalized = dateOnly(date);
    final index = entries.indexWhere((entry) => entry.date == normalized);
    if (index < 0) return;

    entries[index] = DonationEntry(date: normalized, arm: arm);
    await _store.setStringList(
      type.donationsPrefsKey,
      entries.map(encodeDonationEntry).toList(),
    );
  }

  /// Stored per-type days for backup round-trip only. Eligibility uses the
  /// fixed wait matrix and ignores these values.
  static Future<int> getCountdownDays([DonationType? type]) async {
    final resolved = type ?? await getActiveDonationType();
    return await _store.getInt(resolved.countdownPrefsKey) ??
        resolved.defaultCountdownDays;
  }

  static Future<void> setCountdownDays(int days, [DonationType? type]) async {
    final resolved = type ?? await getActiveDonationType();
    await _store.setInt(resolved.countdownPrefsKey, days);
    await _rescheduleNotifications();
  }

  static Future<bool> getReminderEnabled() async {
    return await _store.getBool(keyReminderEnabled) ?? false;
  }

  static Future<void> setReminderEnabled(bool enabled) async {
    await _store.setBool(keyReminderEnabled, enabled);
    await _rescheduleNotifications();
  }

  static Future<int> getReminderDaysBefore() async {
    return await _store.getInt(keyReminderDaysBefore) ?? 1;
  }

  static Future<void> setReminderDaysBefore(int days) async {
    await _store.setInt(keyReminderDaysBefore, days);
    await _rescheduleNotifications();
  }

  static Future<void> removeDonation(DateTime date,
      [DonationType? type]) async {
    final resolved = type ?? await getActiveDonationType();
    final list = await _store.getStringList(resolved.donationsPrefsKey) ?? [];
    final normalized = dateOnly(date);
    final entries = parseAndDedupeEntries(list);
    final next = entries.where((entry) => entry.date != normalized).toList();
    if (next.length == entries.length) return;

    await _store.setStringList(
      resolved.donationsPrefsKey,
      next.map(encodeDonationEntry).toList(),
    );
    await _rescheduleNotifications();
  }

  /// Optional donor ID / donor number. Empty string clears the value.
  static Future<String> getDonorNumber() async {
    return await _store.getString(keyDonorNumber) ?? '';
  }

  static Future<void> setDonorNumber(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _store.remove(keyDonorNumber);
    } else {
      await _store.setString(keyDonorNumber, trimmed);
    }
  }

  static Future<bool> getJourneyHintDoubleRedDismissed() async {
    return await _store.getBool(keyJourneyHintDoubleRedDismissed) ?? false;
  }

  static Future<void> setJourneyHintDoubleRedDismissed(bool dismissed) async {
    await _store.setBool(keyJourneyHintDoubleRedDismissed, dismissed);
  }

  /// Auto-lock delay when PIN is enabled. `0` = lock immediately on pause.
  static Future<int> getAutoLockTimeoutSeconds() async {
    final raw = await _store.getInt(keyAutoLockTimeoutSeconds);
    return AutoLockPolicy.normalizeTimeout(raw);
  }

  static Future<void> setAutoLockTimeoutSeconds(int seconds) async {
    final normalized = AutoLockPolicy.normalizeTimeout(seconds);
    await _store.setInt(keyAutoLockTimeoutSeconds, normalized);
  }

  /// Soft guidance: after 1–2 whole blood donations, hint Double Red as advanced.
  /// Never blocks access — advisory only.
  static Future<bool> shouldShowDoubleRedJourneyHint() async {
    final dismissed = await getJourneyHintDoubleRedDismissed();
    if (dismissed) return false;
    final wb = await getDonations(DonationType.wholeBlood);
    return wb.isNotEmpty && wb.length <= 2;
  }

  /// All donations across types, newest first. Same calendar day may appear
  /// once per type.
  static Future<List<TypedDonation>> getCombinedDonations() async {
    final combined = <TypedDonation>[];
    for (final type in DonationType.values) {
      final records = await getDonationRecords(type);
      for (final record in records) {
        combined.add(TypedDonation(
          type: type,
          date: record.date,
          arm: record.arm,
        ));
      }
    }
    combined.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return a.type.index.compareTo(b.type.index);
    });
    return combined;
  }

  static Future<EligibilitySnapshot> getEligibilitySnapshot({
    DateTime? now,
  }) async {
    final donations = await getCombinedDonations();
    return EligibilityMatrix.evaluate(
      donations: donations,
      now: now,
    );
  }

  /// Eligibility for every type using the cross-product wait matrix.
  static Future<List<TypeEligibility>> getEligibilityOverview({
    DateTime? now,
  }) async {
    final snapshot = await getEligibilitySnapshot(now: now);
    return snapshot.rows;
  }

  static Future<void> initNotifications() async {
    await EncryptedStore.instance.ensureInitialized();

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

    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
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

    await _rescheduleNotifications();
    await handleMissedReminderCatchUp();
  }

  /// Schedules from the soonest eligibility date across all types that have
  /// donations. Shared reminder flags keep the existing notification IDs/flow.
  static Future<void> _rescheduleNotifications() async {
    try {
      final reminderEnabled = await _store.getBool(keyReminderEnabled) ?? false;
      final reminderDaysBefore =
          await _store.getInt(keyReminderDaysBefore) ?? 1;
      final candidate = await _soonestEligibilityCandidate();

      if (!reminderEnabled || candidate == null) {
        await _notificationsPlugin.cancel(id: _notificationIdEligible);
        await _notificationsPlugin.cancel(id: _notificationIdReminder);
        return;
      }

      await scheduleReminders(
        donations: [
          candidate.eligibleDate
              .subtract(Duration(days: candidate.countdownDays)),
        ],
        countdownDays: candidate.countdownDays,
        reminderEnabled: true,
        reminderDaysBefore: reminderDaysBefore,
        typeLabel: candidate.type.displayName,
      );
    } catch (e) {
      // Plugin may be uninitialized in unit tests / early startup.
      debugPrint('Reminder reschedule skipped: $e');
    }
  }

  static Future<void> scheduleReminders({
    required List<DateTime> donations,
    required int countdownDays,
    required bool reminderEnabled,
    required int reminderDaysBefore,
    String typeLabel = 'donation',
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
        title: '$typeLabel: you\'re eligible again',
        body: 'You are eligible to donate $typeLabel again today.',
      );
    }

    if (reminderDaysBefore > 0) {
      final reminderDate =
          eligibleDate.subtract(Duration(days: reminderDaysBefore));
      final reminderScheduled = _atNineAm(reminderDate);
      if (!reminderScheduled.isBefore(now)) {
        await _scheduleNotification(
          id: _notificationIdReminder,
          scheduledDate: reminderScheduled,
          title: '$typeLabel: donation window coming up',
          body:
              "You're $reminderDaysBefore day${reminderDaysBefore == 1 ? '' : 's'} away from your next $typeLabel donation.",
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
      channelDescription: 'Scheduled reminders for blood donation eligibility',
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
      channelDescription: 'Scheduled reminders for blood donation eligibility',
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

  /// Builds the plaintext export map (schema v6) without writing a file.
  @visibleForTesting
  static Future<Map<String, dynamic>> buildExportMap() async {
    final snapshot = await _store.exportSnapshot();
    final data = <String, dynamic>{
      'schema_version': kExportSchemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'export_note':
          'Plaintext backup. Prefer PIN-protected export if you store this file elsewhere.',
      keyActiveDonationType: DonationType.fromId(
        snapshot[keyActiveDonationType] as String?,
      ).id,
      keyReminderEnabled: snapshot[keyReminderEnabled] as bool? ?? false,
      keyReminderDaysBefore: snapshot[keyReminderDaysBefore] as int? ?? 1,
      keyDonorNumber: snapshot[keyDonorNumber] as String? ?? '',
    };

    for (final type in DonationType.values) {
      final raw = snapshot[type.donationsPrefsKey];
      final entries =
          raw is List ? parseAndDedupeEntries(raw) : <DonationEntry>[];
      data[type.donationsPrefsKey] = [
        for (final entry in entries) toExportDonationValue(entry),
      ];
      final countdown = snapshot[type.countdownPrefsKey];
      data[type.countdownPrefsKey] =
          countdown is int ? countdown : type.defaultCountdownDays;
    }
    return data;
  }

  /// Export backup. Pass [passphrase] for PIN-protected (`enc_export_v1`) export;
  /// omit for plaintext JSON (schema v6).
  static Future<ExportResult> exportData({String? passphrase}) async {
    try {
      final data = await buildExportMap();
      final String jsonString;
      final String fileName;

      if (passphrase != null) {
        final envelope = ExportCrypto.encryptExport(
          plaintextJson: jsonEncode(data),
          passphrase: passphrase,
        );
        jsonString = jsonEncode(envelope);
        fileName = 'blood_donation_data.enc.json';
      } else {
        jsonString = jsonEncode(data);
        fileName = 'blood_donation_data.json';
      }

      final bytes = utf8.encode(jsonString);

      final path = await FilePicker.saveFile(
        dialogTitle: passphrase != null
            ? 'Save PIN-protected backup'
            : 'Save donation data',
        fileName: fileName,
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

      return parseImportBytes(bytes);
    } on FormatException {
      return const ImportResult.failure('Invalid backup file: malformed JSON.');
    } catch (e) {
      debugPrint('Import parse error: $e');
      return const ImportResult.failure('Could not read the selected file.');
    }
  }

  @visibleForTesting
  static ImportResult parseImportBytes(List<int> bytes) {
    try {
      final jsonString = utf8.decode(bytes);
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return const ImportResult.failure(
            'Invalid backup file: expected a JSON object.');
      }
      return parseImportMap(decoded);
    } on FormatException {
      return const ImportResult.failure('Invalid backup file: malformed JSON.');
    } catch (e) {
      debugPrint('Import parse error: $e');
      return const ImportResult.failure('Could not read the selected file.');
    }
  }

  @visibleForTesting
  static ImportResult parseImportMap(Map<String, dynamic> decoded) {
    if (ExportCrypto.isEncryptedExport(decoded)) {
      return ImportResult.needsPassphrase(decoded);
    }
    return _validateImportMap(decoded);
  }

  /// Decrypt a PIN-protected envelope and run the same v1–v6 validation.
  /// Wrong passphrase returns a failure — never wipes on-device data.
  static ImportResult decryptAndValidateImport({
    required Map<String, dynamic> encryptedEnvelope,
    required String passphrase,
  }) {
    try {
      final plaintext = ExportCrypto.decryptExport(
        envelope: encryptedEnvelope,
        passphrase: passphrase,
      );
      final dynamic decoded = jsonDecode(plaintext);
      if (decoded is! Map<String, dynamic>) {
        return const ImportResult.failure(
          'Decrypted backup is invalid: expected a JSON object.',
        );
      }
      return _validateImportMap(decoded);
    } on ExportCryptoException catch (e) {
      return ImportResult.failure(e.message);
    } on FormatException {
      return const ImportResult.failure(
        'Incorrect PIN or passphrase. Your data was not changed.',
      );
    } catch (e) {
      debugPrint('Encrypted import error: $e');
      return const ImportResult.failure(
        'Incorrect PIN or passphrase. Your data was not changed.',
      );
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
        return const ImportResult.failure(
            'Invalid backup file: schema_version must be a number.');
      }
      if (version > kExportSchemaVersion) {
        return const ImportResult.failure(
          'This backup was created by a newer app version. Please update the app and try again.',
        );
      }
      validated['schema_version'] = version;
    }

    for (final type in DonationType.values) {
      final key = type.donationsPrefsKey;
      if (data.containsKey(key)) {
        final rawDonations = data[key];
        if (rawDonations is! List) {
          return ImportResult.failure(
              'Invalid backup file: $key must be a list.');
        }
        final donations = <String>[];
        for (final entry in rawDonations) {
          final parsed = tryParseDonationValue(entry);
          if (parsed == null) continue;
          donations.add(encodeDonationEntry(parsed));
        }
        validated[key] =
            parseAndDedupeEntries(donations).map(encodeDonationEntry).toList();
      }

      final countdownKey = type.countdownPrefsKey;
      if (data.containsKey(countdownKey)) {
        final days = data[countdownKey];
        if (days is! int || days < 1 || days > 365) {
          return ImportResult.failure(
              'Invalid backup file: $countdownKey must be between 1 and 365.');
        }
        validated[countdownKey] = days;
      }
    }

    if (data.containsKey(keyActiveDonationType)) {
      final raw = data[keyActiveDonationType];
      if (raw is! String) {
        return const ImportResult.failure(
            'Invalid backup file: active_donation_type must be a string.');
      }
      validated[keyActiveDonationType] = DonationType.fromId(raw).id;
    }

    if (data.containsKey(keyReminderEnabled)) {
      final enabled = data[keyReminderEnabled];
      if (enabled is! bool) {
        return const ImportResult.failure(
            'Invalid backup file: reminder_enabled must be true or false.');
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

    if (data.containsKey(keyDonorNumber)) {
      final raw = data[keyDonorNumber];
      if (raw is! String) {
        return const ImportResult.failure(
            'Invalid backup file: donor_number must be a string.');
      }
      // Allow empty — optional field. Cap length for sanity.
      final trimmed = raw.trim();
      if (trimmed.length > 64) {
        return const ImportResult.failure(
            'Invalid backup file: donor_number is too long.');
      }
      validated[keyDonorNumber] = trimmed;
    }

    final recognizable =
        validated.keys.where((k) => k != 'schema_version').isNotEmpty;
    if (!recognizable) {
      return const ImportResult.failure(
          'No recognizable data found in this backup file.');
    }

    return ImportResult.success(validated);
  }

  /// Replace-all for donation series when any donation key is present so
  /// backups stay coherent (v1 maps `donations` → whole blood; other series empty).
  static Future<void> applyImport(Map<String, dynamic> data) async {
    final updates = <String, dynamic>{};

    final hasDonationData = DonationType.values
        .any((type) => data.containsKey(type.donationsPrefsKey));
    if (hasDonationData) {
      for (final type in DonationType.values) {
        final raw = data[type.donationsPrefsKey];
        final list = raw is List
            ? parseAndDedupeEntries(raw).map(encodeDonationEntry).toList()
            : <String>[];
        updates[type.donationsPrefsKey] = list;
      }
    }

    for (final type in DonationType.values) {
      if (data.containsKey(type.countdownPrefsKey)) {
        updates[type.countdownPrefsKey] = data[type.countdownPrefsKey] as int;
      }
    }

    if (data.containsKey(keyActiveDonationType)) {
      updates[keyActiveDonationType] = data[keyActiveDonationType] as String;
    }

    if (data.containsKey(keyReminderEnabled)) {
      updates[keyReminderEnabled] = data[keyReminderEnabled] as bool;
    }
    if (data.containsKey(keyReminderDaysBefore)) {
      updates[keyReminderDaysBefore] = data[keyReminderDaysBefore] as int;
    }

    if (data.containsKey(keyDonorNumber)) {
      final donor = (data[keyDonorNumber] as String).trim();
      if (donor.isEmpty) {
        await _store.remove(keyDonorNumber);
      } else {
        updates[keyDonorNumber] = donor;
      }
    }

    if (updates.isNotEmpty) {
      await _store.applyMap(updates);
    }

    await _rescheduleNotifications();
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
    this.type,
  });

  final EligibilityCatchUpKind kind;
  final DateTime? eligibleDate;
  final DateTime? reminderDate;
  final DonationType? type;

  EligibilityCatchUp copyWith({
    EligibilityCatchUpKind? kind,
    DateTime? eligibleDate,
    DateTime? reminderDate,
    DonationType? type,
  }) {
    return EligibilityCatchUp(
      kind: kind ?? this.kind,
      eligibleDate: eligibleDate ?? this.eligibleDate,
      reminderDate: reminderDate ?? this.reminderDate,
      type: type ?? this.type,
    );
  }
}
