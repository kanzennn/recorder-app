import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kDefaultPassword = '12345678';

class PairedDevice {
  const PairedDevice({required this.ssid, this.lastUsed});

  final String ssid;
  final DateTime? lastUsed;

  PairedDevice copyWith({DateTime? lastUsed}) =>
      PairedDevice(ssid: ssid, lastUsed: lastUsed ?? this.lastUsed);

  Map<String, dynamic> toJson() => {
    'ssid': ssid,
    'lastUsed': lastUsed?.millisecondsSinceEpoch,
  };

  factory PairedDevice.fromJson(Map<String, dynamic> j) => PairedDevice(
    ssid: j['ssid'] as String,
    lastUsed: j['lastUsed'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(j['lastUsed'] as int),
  );
}

/// Penyimpanan password. Dipisah supaya bisa diganti fake di test.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureSecretStore implements SecretStore {
  SecureSecretStore([FlutterSecureStorage? storage])
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

/// Daftar alat yang sudah di-pair. Sumber kebenaran tunggal untuk layar Home & hub.
class DeviceStore extends ChangeNotifier {
  DeviceStore({required this.prefs, required this.secrets});

  static const _devicesKey = 'paired_devices';

  final SharedPreferences prefs;
  final SecretStore secrets;
  List<PairedDevice> _devices = [];

  List<PairedDevice> get devices => List.unmodifiable(_devices);

  String _pwKey(String ssid) => 'pw:$ssid';

  Future<void> load() async {
    final raw = prefs.getString(_devicesKey);
    if (raw == null) {
      _devices = [];
    } else {
      final list = jsonDecode(raw) as List;
      _devices = list
          .map((e) => PairedDevice.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await prefs.setString(
      _devicesKey,
      jsonEncode(_devices.map((d) => d.toJson()).toList()),
    );
  }

  /// Tambah alat (atau perbarui password kalau sudah ada).
  Future<void> add(String ssid, String password) async {
    await secrets.write(_pwKey(ssid), password);
    final idx = _devices.indexWhere((d) => d.ssid == ssid);
    if (idx == -1) {
      _devices = [
        ..._devices,
        PairedDevice(ssid: ssid, lastUsed: DateTime.now()),
      ];
    } else {
      _devices = [..._devices]
        ..[idx] = _devices[idx].copyWith(lastUsed: DateTime.now());
    }
    await _persist();
    notifyListeners();
  }

  Future<void> touch(String ssid) async {
    final idx = _devices.indexWhere((d) => d.ssid == ssid);
    if (idx == -1) return;
    _devices = [..._devices]
      ..[idx] = _devices[idx].copyWith(lastUsed: DateTime.now());
    await _persist();
    notifyListeners();
  }

  Future<String> passwordFor(String ssid) async =>
      (await secrets.read(_pwKey(ssid))) ?? kDefaultPassword;

  Future<void> remove(String ssid) async {
    await secrets.delete(_pwKey(ssid));
    _devices = _devices.where((d) => d.ssid != ssid).toList();
    await _persist();
    notifyListeners();
  }
}
