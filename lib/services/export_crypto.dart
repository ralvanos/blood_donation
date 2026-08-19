import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';

/// AES-CBC encryption for optional PIN/passphrase-protected JSON backups.
///
/// Wrapper shape (`enc_export_v1`):
/// ```json
/// {
///   "format": "enc_export_v1",
///   "kdf": "pbkdf2_sha256",
///   "iterations": 120000,
///   "salt": "<base64>",
///   "iv": "<base64>",
///   "ciphertext": "<base64>"
/// }
/// ```
/// The ciphertext decrypts to the same plaintext export JSON (schema v1–v5).
class ExportCrypto {
  ExportCrypto._();

  static const String formatId = 'enc_export_v1';
  static const String kdfId = 'pbkdf2_sha256';
  static const int defaultIterations = 120000;
  static const int keyLengthBytes = 32;
  static const int saltLengthBytes = 16;
  static const int minPassphraseLength = 4;
  static const int maxPassphraseLength = 128;

  /// True when [map] is an encrypted export envelope (not plaintext backup).
  static bool isEncryptedExport(Map<String, dynamic> map) =>
      map['format'] == formatId;

  static bool isValidPassphrase(String passphrase) {
    final trimmed = passphrase.trim();
    return trimmed.length >= minPassphraseLength &&
        trimmed.length <= maxPassphraseLength;
  }

  /// Encrypt [plaintextJson] into an `enc_export_v1` envelope map.
  static Map<String, dynamic> encryptExport({
    required String plaintextJson,
    required String passphrase,
    int iterations = defaultIterations,
    @visibleForTesting Uint8List? saltOverride,
    @visibleForTesting Uint8List? ivOverride,
  }) {
    if (!isValidPassphrase(passphrase)) {
      throw ArgumentError(
        'Passphrase must be $minPassphraseLength–$maxPassphraseLength characters',
      );
    }
    if (iterations < 10000) {
      throw ArgumentError('iterations too low');
    }

    final salt = saltOverride ?? _randomBytes(saltLengthBytes);
    final ivBytes = ivOverride ?? _randomBytes(16);
    final key = deriveKey(
      passphrase: passphrase.trim(),
      salt: salt,
      iterations: iterations,
    );
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(key), mode: enc.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(plaintextJson, iv: iv);

    return <String, dynamic>{
      'format': formatId,
      'kdf': kdfId,
      'iterations': iterations,
      'salt': base64Encode(salt),
      'iv': iv.base64,
      'ciphertext': encrypted.base64,
    };
  }

  /// Decrypt an `enc_export_v1` envelope to plaintext JSON string.
  ///
  /// Throws [ExportCryptoException] for malformed envelopes or wrong passphrase.
  static String decryptExport({
    required Map<String, dynamic> envelope,
    required String passphrase,
  }) {
    if (!isEncryptedExport(envelope)) {
      throw const ExportCryptoException('Not an encrypted export file.');
    }
    if (!isValidPassphrase(passphrase)) {
      throw const ExportCryptoException(
        'Enter a valid PIN or passphrase (at least 4 characters).',
      );
    }

    final kdf = envelope['kdf'];
    if (kdf != null && kdf != kdfId) {
      throw const ExportCryptoException(
        'Unsupported encrypted backup (unknown key derivation).',
      );
    }

    final iterationsRaw = envelope['iterations'];
    if (iterationsRaw is! int || iterationsRaw < 10000) {
      throw const ExportCryptoException(
        'Invalid encrypted backup: bad iterations.',
      );
    }

    final saltB64 = envelope['salt'];
    final ivB64 = envelope['iv'];
    final cipherB64 = envelope['ciphertext'];
    if (saltB64 is! String || ivB64 is! String || cipherB64 is! String) {
      throw const ExportCryptoException(
        'Invalid encrypted backup: missing salt, iv, or ciphertext.',
      );
    }

    late final Uint8List salt;
    late final enc.IV iv;
    late final enc.Encrypted ciphertext;
    try {
      salt = Uint8List.fromList(base64Decode(saltB64));
      iv = enc.IV.fromBase64(ivB64);
      ciphertext = enc.Encrypted.fromBase64(cipherB64);
    } catch (_) {
      throw const ExportCryptoException(
        'Invalid encrypted backup: corrupt encoding.',
      );
    }

    final key = deriveKey(
      passphrase: passphrase.trim(),
      salt: salt,
      iterations: iterationsRaw,
    );

    try {
      final encrypter = enc.Encrypter(
        enc.AES(enc.Key(key), mode: enc.AESMode.cbc),
      );
      return encrypter.decrypt(ciphertext, iv: iv);
    } catch (_) {
      throw const ExportCryptoException(
        'Incorrect PIN or passphrase. Your data was not changed.',
      );
    }
  }

  /// PBKDF2-HMAC-SHA256 key derivation (pure Dart via [package:crypto]).
  @visibleForTesting
  static Uint8List deriveKey({
    required String passphrase,
    required List<int> salt,
    required int iterations,
    int length = keyLengthBytes,
  }) {
    final password = utf8.encode(passphrase);
    const digestLength = 32;
    final blocks = (length / digestLength).ceil();
    final out = BytesBuilder(copy: false);

    for (var block = 1; block <= blocks; block++) {
      final blockBytes = ByteData(4)..setUint32(0, block, Endian.big);
      var u = _hmacSha256(password, [...salt, ...blockBytes.buffer.asUint8List()]);
      var t = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = _hmacSha256(password, u);
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
    }

    return Uint8List.fromList(out.toBytes().sublist(0, length));
  }

  static List<int> _hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).bytes;
  }

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }
}

class ExportCryptoException implements Exception {
  const ExportCryptoException(this.message);

  final String message;

  @override
  String toString() => message;
}
