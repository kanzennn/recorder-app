import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/esp32_api.dart';
import '../services/wifi_platform.dart';
import 'device_store.dart';

/// Mengelola koneksi ke satu alat: menyambungkan HP ke AP-nya, memverifikasi
/// lewat /status, dan memeriksa ulang berkala selama layar hub terbuka.
class ConnectionController extends ChangeNotifier {
  ConnectionController({
    required this.device,
    required this.store,
    Esp32Api? api,
    WifiPlatform? wifi,
    this.pollInterval = const Duration(seconds: 2),
  }) : api = api ?? Esp32Api(),
       _wifi = wifi ?? WifiPlatform();

  final PairedDevice device;
  final DeviceStore store;
  final Esp32Api api;
  final WifiPlatform _wifi;
  final Duration pollInterval;

  bool connecting = false;
  bool connected = false;
  String? error;
  Timer? _poll;
  bool _suspended = false;

  /// Sambungkan HP ke AP alat ini lalu pastikan /status bisa dijangkau.
  Future<void> connect() async {
    connecting = true;
    error = null;
    notifyListeners();
    try {
      final password = await store.passwordFor(device.ssid);
      await _wifi.connect(device.ssid, password);
      await api.getStatus();
      connected = true;
      await store.touch(device.ssid);
    } on WifiConnectException catch (e) {
      connected = false;
      error = e.message;
    } catch (e) {
      connected = false;
      error = e.toString();
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  /// Hentikan sementara polling /status -- dipakai selagi kita sendiri yang
  /// bikin ESP32 sibuk (mis. download file besar). WebServer.h di firmware
  /// cuma layani satu koneksi sekaligus, jadi /status yang nyelonong di
  /// tengah download bakal nunggu lama di belakang, kena timeout, dan salah
  /// kesimpulan "device terputus" padahal cuma lagi sibuk kirim file.
  void suspendChecks() => _suspended = true;

  void resumeChecks() => _suspended = false;

  /// Cek ringan: apakah alat masih terjangkau sekarang.
  Future<void> checkReachable() async {
    if (_suspended) return;
    try {
      await api.getStatus();
      if (!connected) {
        connected = true;
        error = null;
        notifyListeners();
      }
    } catch (_) {
      if (connected) {
        connected = false;
        notifyListeners();
      }
    }
  }

  void startPolling() {
    _poll ??= Timer.periodic(pollInterval, (_) => checkReachable());
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  bool _disposed = false;

  // Pengecekan /status atau connect() yang masih jalan waktu layar ditutup
  // selesai SETELAH dispose(); tanpa penjagaan ini notifyListeners() melempar
  // "used after being disposed".
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
