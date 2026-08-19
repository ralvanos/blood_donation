import 'package:blood_donation/services/encrypted_store.dart';
import 'package:blood_donation/services/key_vault.dart';
import 'package:blood_donation/services/pin_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PinService hash / verify', () {
    late PinService pin;

    setUp(() {
      pin = PinService(keyVault: InMemoryKeyVault());
      PinService.resetInstanceForTest(pin);
    });

    tearDown(() {
      PinService.resetInstanceForTest();
    });

    test('hashPin is deterministic for same salt', () {
      expect(
        PinService.hashPin('1234', 'salt-a'),
        PinService.hashPin('1234', 'salt-a'),
      );
      expect(
        PinService.hashPin('1234', 'salt-a'),
        isNot(PinService.hashPin('1234', 'salt-b')),
      );
      expect(
        PinService.hashPin('1234', 'salt-a'),
        isNot(PinService.hashPin('4321', 'salt-a')),
      );
    });

    test('isValidPinFormat accepts 4–6 digits only', () {
      expect(PinService.isValidPinFormat('1234'), isTrue);
      expect(PinService.isValidPinFormat('123456'), isTrue);
      expect(PinService.isValidPinFormat('123'), isFalse);
      expect(PinService.isValidPinFormat('1234567'), isFalse);
      expect(PinService.isValidPinFormat('12ab'), isFalse);
      expect(PinService.isValidPinFormat(''), isFalse);
    });

    test('setPin enables and verifyPin succeeds', () async {
      expect(await pin.isEnabled(), isFalse);
      await pin.setPin('2468');
      expect(await pin.isEnabled(), isTrue);
      expect(await pin.verifyPin('2468'), isTrue);
      expect(await pin.verifyPin('0000'), isFalse);
    });

    test('changePin requires current PIN', () async {
      await pin.setPin('1111');
      await pin.changePin(currentPin: '1111', newPin: '9999');
      expect(await pin.verifyPin('9999'), isTrue);
      expect(await pin.verifyPin('1111'), isFalse);
    });

    test('disablePin removes lock after confirm', () async {
      await pin.setPin('5555');
      await pin.disablePin('5555');
      expect(await pin.isEnabled(), isFalse);
      expect(await pin.verifyPin('5555'), isFalse);
    });

    test('throttle after repeated failures', () async {
      await pin.setPin('1234');
      for (var i = 0; i < PinService.failThrottleAfter; i++) {
        expect(await pin.verifyPin('0000'), isFalse);
      }
      final remaining = pin.throttleRemaining();
      expect(remaining, isNotNull);
      expect(remaining!.inSeconds, greaterThan(0));
      expect(await pin.verifyPin('1234'), isFalse);
    });
  });

  group('EncryptedStore round-trip and migration', () {
    tearDown(() {
      EncryptedStore.resetInstanceForTest();
    });

    test('encrypt / decrypt round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = EncryptedStore(
        keyVault: InMemoryKeyVault(),
        prefs: prefs,
      );
      await store.ensureInitialized();

      const plaintext =
          '{"donations":["2024-01-01T00:00:00.000"],"donor_number":"X"}';
      final blob = store.encryptForTest(plaintext);
      expect(blob, isNot(contains('donor_number')));
      expect(blob, isNot(contains('2024-01-01')));
      expect(store.decryptForTest(blob), plaintext);
    });

    test('setString / getString persists encrypted blob', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final vault = InMemoryKeyVault();
      final store = EncryptedStore(keyVault: vault, prefs: prefs);
      EncryptedStore.resetInstanceForTest(store);
      await store.ensureInitialized();

      await store.setString('donor_number', 'SECRET-77');
      await store.setStringList('donations', ['2024-06-01T00:00:00.000']);

      final blob = prefs.getString(EncryptedStore.blobPrefsKey);
      expect(blob, isNotNull);
      expect(blob!, isNot(contains('SECRET-77')));
      expect(blob, isNot(contains('2024-06-01')));

      // Reload with same vault + prefs simulates app restart.
      final reloaded = EncryptedStore(keyVault: vault, prefs: prefs);
      await reloaded.ensureInitialized();
      expect(await reloaded.getString('donor_number'), 'SECRET-77');
      expect(
        await reloaded.getStringList('donations'),
        ['2024-06-01T00:00:00.000'],
      );
    });

    test('migrates v4 plaintext data without loss', () async {
      final vault = InMemoryKeyVault();
      SharedPreferences.setMockInitialValues({
        'donations': ['2024-01-10T00:00:00.000'],
        'donations_plasma': <String>[],
        'donations_platelet': <String>['2024-02-15T00:00:00.000'],
        'donations_double_red': <String>[],
        'countdown_days': 56,
        'countdown_days_platelet': 7,
        'donor_number': 'V4-DONOR',
        'reminder_enabled': false,
        'active_donation_type': 'whole_blood',
        'journey_hint_double_red_dismissed': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = EncryptedStore(keyVault: vault, prefs: prefs);
      EncryptedStore.resetInstanceForTest(store);
      await store.ensureInitialized();

      expect(await store.getString('donor_number'), 'V4-DONOR');
      expect(
        await store.getStringList('donations'),
        ['2024-01-10T00:00:00.000'],
      );
      expect(
        await store.getStringList('donations_platelet'),
        ['2024-02-15T00:00:00.000'],
      );
      expect(await store.getInt('countdown_days'), 56);
      expect(await store.getInt('countdown_days_platelet'), 7);
      expect(await store.getBool('journey_hint_double_red_dismissed'), isTrue);
      expect(prefs.getBool(EncryptedStore.migrationDoneKey), isTrue);
      expect(prefs.containsKey('donations'), isFalse);
      expect(prefs.containsKey('donor_number'), isFalse);
      expect(prefs.getString(EncryptedStore.blobPrefsKey), isNotNull);
      expect(
        prefs.getString(EncryptedStore.blobPrefsKey)!,
        isNot(contains('V4-DONOR')),
      );
    });

    test('second launch skips migration', () async {
      final vault = InMemoryKeyVault();
      SharedPreferences.setMockInitialValues({
        'donations': ['2024-01-01T00:00:00.000'],
        'donor_number': 'ONCE',
      });
      final prefs = await SharedPreferences.getInstance();
      final first = EncryptedStore(keyVault: vault, prefs: prefs);
      await first.ensureInitialized();
      expect(await first.getString('donor_number'), 'ONCE');

      // Inject new plaintext that must NOT be migrated again.
      await prefs.setString('donor_number', 'SHOULD-NOT-MIGRATE');
      final second = EncryptedStore(keyVault: vault, prefs: prefs);
      await second.ensureInitialized();
      expect(await second.getString('donor_number'), 'ONCE');
    });
  });
}
