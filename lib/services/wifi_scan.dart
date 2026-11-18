import 'package:wifi_scan/wifi_scan.dart';

const String kEspSsidPrefix = 'ESP32-';

/// Hanya SSID yang diawali [kEspSsidPrefix], tanpa duplikat, terurut.
List<String> filterEspSsids(Iterable<String> ssids) {
  final set = <String>{
    for (final s in ssids)
      if (s.startsWith(kEspSsidPrefix)) s,
  };
  return set.toList()..sort();
}

class WifiScanException implements Exception {
  const WifiScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WifiScanService {
  /// Pindai WiFi dan kembalikan SSID ESP32-*. Melempar [WifiScanException] dengan
  /// pesan yang bisa langsung ditampilkan ke user.
  Future<List<String>> scanEspNetworks() async {
    final can = await WiFiScan.instance.canStartScan(askPermissions: true);
    if (can == CanStartScan.notSupported) {
      throw const WifiScanException(
        'Pemindaian WiFi tidak didukung di HP ini.',
      );
    }
    if (can == CanStartScan.noLocationServiceDisabled) {
      throw const WifiScanException(
        'Aktifkan layanan lokasi (GPS) di HP, lalu coba lagi.',
      );
    }
    if (can == CanStartScan.noLocationPermissionDenied ||
        can == CanStartScan.noLocationPermissionUpgradeAccuracy ||
        can == CanStartScan.noLocationPermissionRequired) {
      throw const WifiScanException(
        'Izin lokasi dibutuhkan untuk mencari WiFi. Berikan izin lalu coba lagi.',
      );
    }

    await WiFiScan.instance.startScan();

    final canGet = await WiFiScan.instance.canGetScannedResults(
      askPermissions: true,
    );
    if (canGet != CanGetScannedResults.yes) {
      throw const WifiScanException(
        'Hasil pemindaian WiFi belum tersedia. Coba lagi.',
      );
    }
    final aps = await WiFiScan.instance.getScannedResults();
    return filterEspSsids(aps.map((a) => a.ssid));
  }
}
