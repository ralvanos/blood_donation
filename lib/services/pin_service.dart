import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'key_vault.dart';

/// Optional PIN app-lock. PIN is never stored in plaintext — only a salted hash.
class PinService {
  PinService({KeyVault? keyVault}) : _vault = keyVault ?? SecureKeyVault();

  static PinService? _instance;

  static PinService get instance => _instance ??= PinService();

  @visibleForTesting
  static void resetInstanceForTest([PinService? service]) {
    _instance = service;
  }

  static const String vaultEnabledKey = 'pin_lock_enabled';
  static const String vaultSaltKey = 'pin_salt_v1';
  static const String vaultHashKey = 'pin_hash_v1';

  static const int minPinLength = 4;
  static const int maxPinLength = 6;
  static const int failThrottleAfter = 5;
  static const Duration failThrottleDuration = Duration(seconds: 30);

  final KeyVault _vault;

  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  /// Pure salted SHA-256 hash (hex). Exposed for tests.
  @visibleForTesting
  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  static bool isValidPinFormat(String pin) {
    if (pin.length < minPinLength || pin.length > maxPinLength) return false;
    return RegExp(r'^\d+$').hasMatch(pin);
  }

  Future<bool> isEnabled() async {
    final raw = await _vault.read(vaultEnabledKey);
    return raw == 'true';
  }

  /// Remaining throttle wait, or null if unlock attempts are allowed.
  Duration? throttleRemaining({DateTime? now}) {
    final until = _lockedUntil;
    if (until == null) return null;
    final remaining = until.difference(now ?? DateTime.now());
    if (remaining.isNegative) {
      _lockedUntil = null;
      return null;
    }
    return remaining;
  }

  int get failedAttempts => _failedAttempts;

  Future<bool> verifyPin(String pin) async {
    final throttle = throttleRemaining();
    if (throttle != null) return false;

    final salt = await _vault.read(vaultSaltKey);
    final expected = await _vault.read(vaultHashKey);
    if (salt == null || expected == null) return false;

    final ok = hashPin(pin, salt) == expected;
    if (ok) {
      _failedAttempts = 0;
      _lockedUntil = null;
      return true;
    }

    _failedAttempts++;
    if (_failedAttempts >= failThrottleAfter) {
      _lockedUntil = DateTime.now().add(failThrottleDuration);
      _failedAttempts = 0;
    }
    return false;
  }

  /// Enable or replace PIN. [pin] must be 4–6 digits.
  Future<void> setPin(String pin) async {
    if (!isValidPinFormat(pin)) {
      throw ArgumentError(
        'PIN must be $minPinLength–$maxPinLength digits',
      );
    }
    final salt = _randomSalt();
    final hash = hashPin(pin, salt);
    await _vault.write(vaultSaltKey, salt);
    await _vault.write(vaultHashKey, hash);
    await _vault.write(vaultEnabledKey, 'true');
    _failedAttempts = 0;
    _lockedUntil = null;
  }

  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final ok = await verifyPin(currentPin);
    if (!ok) {
      throw StateError('Current PIN is incorrect');
    }
    await setPin(newPin);
  }

  /// Disable PIN after confirming the current PIN.
  Future<void> disablePin(String currentPin) async {
    final ok = await verifyPin(currentPin);
    if (!ok) {
      throw StateError('Current PIN is incorrect');
    }
    await _vault.write(vaultEnabledKey, 'false');
    await _vault.delete(vaultSaltKey);
    await _vault.delete(vaultHashKey);
    _failedAttempts = 0;
    _lockedUntil = null;
  }

  static String _randomSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }
}
