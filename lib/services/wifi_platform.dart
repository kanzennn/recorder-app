import 'package:flutter/services.dart';

// Pembungkus channel native (android/.../WifiChannel.kt). Hanya Android 10+.
class WifiPlatform {
  static const _channel = MethodChannel('recorder/wifi');

  /// Minta HP tersambung ke AP [ssid]. Melempar [WifiConnectException] kalau gagal/ditolak.
  Future<void> connect(String ssid, String password) async {
    try {
      await _channel.invokeMethod<void>('connect', {
        'ssid': ssid,
        'password': password,
      });
    } on PlatformException catch (e) {
      throw WifiConnectException(e.message ?? 'Gagal tersambung ke $ssid');
    }
  }

  Future<void> disconnect() async {
    await _channel.invokeMethod<void>('disconnect');
  }
}

class WifiConnectException implements Exception {
  const WifiConnectException(this.message);

  final String message;

  @override
  String toString() => message;
}
