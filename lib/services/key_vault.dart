import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction over Keystore-backed (or in-memory) secret storage.
abstract class KeyVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Production vault backed by [FlutterSecureStorage] (Android Keystore).
class SecureKeyVault implements KeyVault {
  SecureKeyVault({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// In-memory vault for unit tests.
class InMemoryKeyVault implements KeyVault {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async {
    _map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _map.remove(key);
  }
}
