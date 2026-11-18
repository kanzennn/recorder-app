import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recorder_app/api/esp32_api.dart';
import 'package:recorder_app/data/huruf.dart';
import 'package:recorder_app/screens/browse_screen.dart';
import 'package:recorder_app/screens/device_hub_screen.dart';
import 'package:recorder_app/screens/home_screen.dart';
import 'package:recorder_app/screens/record_screen.dart';
import 'package:recorder_app/services/wifi_platform.dart';
import 'package:recorder_app/store/connection_controller.dart';
import 'package:recorder_app/store/device_store.dart';
import 'package:recorder_app/theme/app_theme.dart';

// Tes ini merender tiap layar di berbagai ukuran layar & skala teks. Overflow
// layout di Flutter dilaporkan sebagai exception, jadi tes gagal kalau ada
// teks/tombol yang kepotong atau meluap.

class FakeApi extends Esp32Api {
  FakeApi({this.recording = false}) : super(baseUrl: 'http://fake');

  final bool recording;

  @override
  Future<Status> getStatus() async => Status(
    recording: recording,
    elapsedSec: 75,
    sdReady: true,
    sdPresent: true,
    targetSelected: true,
    responden: 2,
    huruf: 5,
    variasi: 1,
    nextTake: 3,
    currentTake: 3,
  );

  @override
  Future<List<int>> getRespondents() async => [1, 2, 3, 4, 5, 6, 7, 8];

  @override
  Future<int> createRespondent() async => 9;

  @override
  Future<Set<int>> getHurufWithData(int responden) async =>
      {1, 2, 3, 5, 8, 13, 20, 28};

  @override
  Future<VariasiInfo> getVariasi(int responden, int huruf) async =>
      const VariasiInfo(variants: [1, 2, 3], nextNew: 4);

  @override
  Future<int> select(int responden, int huruf, int variasi) async => 3;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<List<Take>> getTakes(int responden, int huruf, int variasi) async => [
    for (var t = 1; t <= 4; t++)
      Take(
        take: t,
        done: t != 4,
        bytes: const [204800, 204800, 204800, 204800],
        responden: responden,
        huruf: huruf,
        variasi: variasi,
      ),
  ];
}

class FakeWifi extends WifiPlatform {
  @override
  Future<void> connect(String ssid, String password) async {}

  @override
  Future<void> disconnect() async {}
}

class FakeSecrets implements SecretStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

const _textScales = [1.0, 1.5];

Future<void> _pump(
  WidgetTester tester,
  Size size,
  double textScale,
  Widget home,
) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // addTearDown tetap jalan walau tes gagal, jadi Timer.periodic di State
  // (polling status) selalu ikut dibatalkan dan tidak bocor ke tes berikutnya.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
  // Biarkan future palsu (status, daftar responden, dst.) selesai dan UI settle.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Gagalkan tes dengan pesan lengkap (termasuk widget yang meluap) kalau ada exception layout.
void _expectClean(WidgetTester tester) {
  final ex = tester.takeException();
  expect(
    ex,
    isNull,
    reason: ex is FlutterError ? ex.toStringDeep() : ex?.toString(),
  );
}

Future<DeviceStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  final store = DeviceStore(
    prefs: await SharedPreferences.getInstance(),
    secrets: FakeSecrets(),
  );
  await store.add('ESP32-4MIC', kDefaultPassword);
  await store.add('ESP32-LAB-2', kDefaultPassword);
  await store.add('ESP32-4MIC-CADANGAN-PANJANG-SEKALI', kDefaultPassword);
  return store;
}

/// Flutter test memakai font "Ahem" (tiap huruf selebar 1 em) kalau Roboto tidak
/// dimuat, jadi teks terlihat jauh lebih lebar dari di perangkat asli dan tes
/// overflow jadi terlalu pesimis. Muat Roboto dari SDK (font bawaan Android).
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final f in ['regular', 'medium', 'bold']) {
    final file = File('$dir/roboto-$f.ttf');
    if (!file.existsSync()) return;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

/// Daftarkan seluruh tes responsif untuk satu ukuran layar. Dipanggil dari satu
/// berkas tes per ukuran (lihat test/responsive_*_test.dart) supaya tiap ukuran
/// jalan di proses runner sendiri -- satu berkas besar berisi semua ukuran sempat
/// terhenti diam-diam oleh runner di sekitar detik ke-7.
void defineResponsiveSuite(String sizeName, Size size) {
  setUpAll(_loadRoboto);

  for (final entry in {sizeName: size}.entries) {
    for (final scale in _textScales) {
      final label = '${entry.key}, teks x$scale';

      testWidgets('Rekam: tidak overflow ($label)', (tester) async {
        await _pump(
          tester,
          entry.value,
          scale,
          Scaffold(body: RecordScreen(api: FakeApi())),
        );
        _expectClean(tester);
      });

      testWidgets('Rekam saat merekam: tidak overflow ($label)', (tester) async {
        await _pump(
          tester,
          entry.value,
          scale,
          Scaffold(body: RecordScreen(api: FakeApi(recording: true))),
        );
        _expectClean(tester);
      });

      testWidgets('Lihat Data: tidak overflow ($label)', (tester) async {
        final store = await _store();
        final ctrl = ConnectionController(
          device: store.devices.first,
          store: store,
          api: FakeApi(),
          wifi: FakeWifi(),
        );
        await _pump(
          tester,
          entry.value,
          scale,
          Scaffold(
            body: BrowseScreen(api: FakeApi(), connection: ctrl),
          ),
        );
        // Telusuri sampai kartu take muncul.
        Future<void> tapText(String text) async {
          final f = find.text(text);
          await tester.scrollUntilVisible(
            f,
            100,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(f);
          await tester.pump(const Duration(milliseconds: 200));
        }

        await tapText('RESPONDEN 2');
        // Label huruf diambil dari data app supaya tes tidak patah kalau teksnya berubah.
        await tapText(hurufByIndex(5).label);
        await tapText('Variasi 1');
        await tester.scrollUntilVisible(
          find.text('Take 1'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Take 1'), findsOneWidget);
        _expectClean(tester);
      });

      testWidgets('Hub tersambung: tidak overflow ($label)', (tester) async {
        final store = await _store();
        final ctrl = ConnectionController(
          device: store.devices.first,
          store: store,
          api: FakeApi(),
          wifi: FakeWifi(),
        );
        await _pump(
          tester,
          entry.value,
          scale,
          DeviceHubScreen(
            device: store.devices.first,
            store: store,
            controller: ctrl,
          ),
        );
        expect(ctrl.connected, isTrue);
        _expectClean(tester);
      });

      testWidgets('Home dengan 3 alat: tidak overflow ($label)', (tester) async {
        final store = await _store();
        await _pump(tester, entry.value, scale, HomeScreen(store: store));
        _expectClean(tester);
      });
    }
  }
}
