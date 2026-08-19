import 'dart:convert';
import 'dart:typed_data';

import 'package:blood_donation/services/auto_lock_policy.dart';
import 'package:blood_donation/services/donation_storage.dart';
import 'package:blood_donation/services/encrypted_store.dart';
import 'package:blood_donation/services/export_crypto.dart';
import 'package:blood_donation/services/key_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ExportCrypto', () {
    test('encrypt / decrypt round-trip', () {
      const plaintext = '{"schema_version":5,"donor_number":"SECRET"}';
      final envelope = ExportCrypto.encryptExport(
        plaintextJson: plaintext,
        passphrase: '2468',
      );

      expect(envelope['format'], ExportCrypto.formatId);
      expect(envelope['kdf'], ExportCrypto.kdfId);
      expect(envelope['ciphertext'], isA<String>());
      expect(jsonEncode(envelope), isNot(contains('SECRET')));
      expect(jsonEncode(envelope), isNot(contains('donor_number')));

      final decrypted = ExportCrypto.decryptExport(
        envelope: envelope,
        passphrase: '2468',
      );
      expect(decrypted, plaintext);
    });

    test('wrong passphrase fails without revealing payload', () {
      final envelope = ExportCrypto.encryptExport(
        plaintextJson: '{"schema_version":5,"donations":["2024-01-01T00:00:00.000"]}',
        passphrase: 'correct-pin',
      );

      expect(
        () => ExportCrypto.decryptExport(
          envelope: envelope,
          passphrase: 'wrong-pin',
        ),
        throwsA(
          isA<ExportCryptoException>().having(
            (e) => e.message,
            'message',
            contains('Incorrect PIN'),
          ),
        ),
      );
    });

    test('isEncryptedExport detects wrapper', () {
      expect(
        ExportCrypto.isEncryptedExport({'format': 'enc_export_v1'}),
        isTrue,
      );
      expect(
        ExportCrypto.isEncryptedExport({'schema_version': 5}),
        isFalse,
      );
    });

    test('deriveKey is deterministic', () {
      final salt = Uint8List.fromList(List<int>.filled(16, 7));
      final a = ExportCrypto.deriveKey(
        passphrase: 'test',
        salt: salt,
        iterations: 10000,
      );
      final b = ExportCrypto.deriveKey(
        passphrase: 'test',
        salt: salt,
        iterations: 10000,
      );
      expect(a, b);
      expect(a.length, 32);
    });
  });

  group('encrypted export import path', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = EncryptedStore(
        keyVault: InMemoryKeyVault(),
        prefs: prefs,
      );
      EncryptedStore.resetInstanceForTest(store);
      await store.ensureInitialized();
    });

    tearDown(() {
      EncryptedStore.resetInstanceForTest();
    });

    test('parseImportMap flags encrypted envelope', () {
      final envelope = ExportCrypto.encryptExport(
        plaintextJson: jsonEncode({
          'schema_version': 5,
          'donations': ['2024-06-01T00:00:00.000'],
          'countdown_days': 56,
        }),
        passphrase: '9999',
      );

      final picked = DonationStorage.parseImportMap(envelope);
      expect(picked.needsPassphrase, isTrue);
      expect(picked.success, isFalse);
      expect(picked.encryptedEnvelope, isNotNull);

      final unlocked = DonationStorage.decryptAndValidateImport(
        encryptedEnvelope: picked.encryptedEnvelope!,
        passphrase: '9999',
      );
      expect(unlocked.success, isTrue);
      expect(unlocked.data!['donations'], ['2024-06-01T00:00:00.000']);
      expect(unlocked.data!['countdown_days'], 56);
    });

    test('wrong PIN on import fails and leaves store untouched', () async {
      await EncryptedStore.instance.setString('donor_number', 'KEEP-ME');

      final envelope = ExportCrypto.encryptExport(
        plaintextJson: jsonEncode({
          'schema_version': 5,
          'donations': ['2024-01-01T00:00:00.000'],
          'donor_number': 'SHOULD-NOT-APPLY',
        }),
        passphrase: '1111',
      );

      final result = DonationStorage.decryptAndValidateImport(
        encryptedEnvelope: envelope,
        passphrase: '0000',
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Incorrect PIN'));
      expect(await EncryptedStore.instance.getString('donor_number'), 'KEEP-ME');
    });

    test('plaintext import still works', () {
      final result = DonationStorage.parseImportMap({
        'schema_version': 5,
        'donations': ['2024-03-01T00:00:00.000'],
        'countdown_days': 56,
      });
      expect(result.success, isTrue);
      expect(result.needsPassphrase, isFalse);
    });
  });

  group('AutoLockPolicy', () {
    test('normalizeTimeout falls back for unknown values', () {
      expect(AutoLockPolicy.normalizeTimeout(null), 0);
      expect(AutoLockPolicy.normalizeTimeout(12), 0);
      expect(AutoLockPolicy.normalizeTimeout(30), 30);
      expect(AutoLockPolicy.normalizeTimeout(300), 300);
    });

    test('lockImmediatelyOnPause only for zero timeout', () {
      expect(AutoLockPolicy.lockImmediatelyOnPause(0), isTrue);
      expect(AutoLockPolicy.lockImmediatelyOnPause(30), isFalse);
      expect(AutoLockPolicy.lockImmediatelyOnPause(60), isFalse);
    });

    test('shouldLockOnResume respects elapsed time', () {
      final pausedAt = DateTime(2026, 1, 1, 12, 0, 0);

      expect(
        AutoLockPolicy.shouldLockOnResume(
          timeoutSeconds: 60,
          pausedAt: pausedAt,
          now: pausedAt.add(const Duration(seconds: 59)),
        ),
        isFalse,
      );
      expect(
        AutoLockPolicy.shouldLockOnResume(
          timeoutSeconds: 60,
          pausedAt: pausedAt,
          now: pausedAt.add(const Duration(seconds: 60)),
        ),
        isTrue,
      );
      expect(
        AutoLockPolicy.shouldLockOnResume(
          timeoutSeconds: 0,
          pausedAt: pausedAt,
          now: pausedAt.add(const Duration(minutes: 5)),
        ),
        isFalse,
      );
      expect(
        AutoLockPolicy.shouldLockOnResume(
          timeoutSeconds: 30,
          pausedAt: null,
          now: pausedAt,
        ),
        isFalse,
      );
    });

    test('labels cover all allowed values', () {
      for (final seconds in AutoLockPolicy.allowedTimeoutSeconds) {
        expect(AutoLockPolicy.labelForTimeout(seconds), isNotEmpty);
      }
    });
  });

  group('auto-lock preference persistence', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      EncryptedStore.resetInstanceForTest(
        EncryptedStore(keyVault: InMemoryKeyVault(), prefs: prefs),
      );
      await EncryptedStore.instance.ensureInitialized();
    });

    tearDown(() {
      EncryptedStore.resetInstanceForTest();
    });

    test('get defaults to immediate; set persists allowed values', () async {
      expect(await DonationStorage.getAutoLockTimeoutSeconds(), 0);
      await DonationStorage.setAutoLockTimeoutSeconds(300);
      expect(await DonationStorage.getAutoLockTimeoutSeconds(), 300);
      await DonationStorage.setAutoLockTimeoutSeconds(99); // invalid → 0
      expect(await DonationStorage.getAutoLockTimeoutSeconds(), 0);
    });
  });
}
