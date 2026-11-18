import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recorder_app/api/esp32_api.dart';
import 'package:recorder_app/services/wifi_platform.dart';
import 'package:recorder_app/services/wifi_scan.dart';
import 'package:recorder_app/store/connection_controller.dart';
import 'package:recorder_app/store/device_store.dart';

class MemorySecrets implements SecretStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}

class FakeWifi extends WifiPlatform {
  FakeWifi({this.fail = false});

  final bool fail;
  String? lastSsid;
  String? lastPassword;

  @override
  Future<void> connect(String ssid, String password) async {
    lastSsid = ssid;
    lastPassword = password;
    if (fail) throw const WifiConnectException('ditolak');
  }

  @override
  Future<void> disconnect() async {}
}

class FakeApi extends Esp32Api {
  FakeApi({required this.reachable});

  bool reachable;

  @override
  Future<Status> getStatus() async {
    if (!reachable) throw const ApiException(null, 'tidak terjangkau');
    return Status.fromJson({
      'recording': false,
      'elapsed_sec': 0,
      'sdReady': true,
      'sdPresent': true,
      'targetSelected': false,
      'responden': -1,
      'huruf': -1,
      'variasi': -1,
      'nextTake': 1,
      'currentTake': 0,
    });
  }
}

void main() {
  test('filterEspSsids keeps only ESP32-*, removes duplicates, sorts', () {
    final out = filterEspSsids([
      'Rumah',
      'ESP32-4MIC',
      'ESP32-2',
      'ESP32-4MIC',
      'Kantor',
    ]);
    expect(out, ['ESP32-2', 'ESP32-4MIC']);
  });

  test('DeviceStore add, persist across instances, and remove', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final secrets = MemorySecrets();

    final store = DeviceStore(prefs: prefs, secrets: secrets);
    await store.load();
    expect(store.devices, isEmpty);

    await store.add('ESP32-4MIC', 'rahasia123');
    expect(store.devices.map((d) => d.ssid), ['ESP32-4MIC']);
    expect(await store.passwordFor('ESP32-4MIC'), 'rahasia123');

    // Instance baru dengan prefs yang sama harus memuat ulang daftar yang tersimpan.
    final reloaded = DeviceStore(prefs: prefs, secrets: secrets);
    await reloaded.load();
    expect(reloaded.devices.map((d) => d.ssid), ['ESP32-4MIC']);

    await reloaded.remove('ESP32-4MIC');
    expect(reloaded.devices, isEmpty);
    expect(await reloaded.passwordFor('ESP32-4MIC'), kDefaultPassword);
  });

  test('ConnectionController connects and marks device reachable', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DeviceStore(
      prefs: await SharedPreferences.getInstance(),
      secrets: MemorySecrets(),
    );
    await store.add('ESP32-4MIC', '12345678');
    final wifi = FakeWifi();
    final ctrl = ConnectionController(
      device: store.devices.first,
      store: store,
      api: FakeApi(reachable: true),
      wifi: wifi,
    );

    await ctrl.connect();

    expect(ctrl.connected, isTrue);
    expect(ctrl.error, isNull);
    expect(wifi.lastSsid, 'ESP32-4MIC');
    expect(wifi.lastPassword, '12345678');
  });

  test(
    'ConnectionController reports error when WiFi connect is refused',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = DeviceStore(
        prefs: await SharedPreferences.getInstance(),
        secrets: MemorySecrets(),
      );
      await store.add('ESP32-4MIC', '12345678');
      final ctrl = ConnectionController(
        device: store.devices.first,
        store: store,
        api: FakeApi(reachable: true),
        wifi: FakeWifi(fail: true),
      );

      await ctrl.connect();

      expect(ctrl.connected, isFalse);
      expect(ctrl.error, 'ditolak');
    },
  );

  test(
    'checkReachable flips connected state when the device goes away',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = DeviceStore(
        prefs: await SharedPreferences.getInstance(),
        secrets: MemorySecrets(),
      );
      await store.add('ESP32-4MIC', '12345678');
      final api = FakeApi(reachable: true);
      final ctrl = ConnectionController(
        device: store.devices.first,
        store: store,
        api: api,
        wifi: FakeWifi(),
      );

      await ctrl.connect();
      expect(ctrl.connected, isTrue);

      api.reachable = false;
      await ctrl.checkReachable();
      expect(ctrl.connected, isFalse);

      api.reachable = true;
      await ctrl.checkReachable();
      expect(ctrl.connected, isTrue);
    },
  );
}
