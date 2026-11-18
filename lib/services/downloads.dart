import 'package:flutter/services.dart';

// Simpan file ke folder Download publik HP (lewat MediaStore di sisi native
// Android -- lihat DownloadsChannel.kt), supaya kelihatan di file manager,
// bukan folder internal app yang nggak bisa dibuka tanpa root.
class DownloadsService {
  static const _channel = MethodChannel('recorder/downloads');

  Future<String> saveToDownloads(String fileName, Uint8List bytes) async {
    final path = await _channel.invokeMethod<String>('saveToDownloads', {
      'fileName': fileName,
      'bytes': bytes,
    });
    if (path == null) {
      throw const DownloadsException('Gagal menyimpan file.');
    }
    return path;
  }
}

class DownloadsException implements Exception {
  const DownloadsException(this.message);

  final String message;

  @override
  String toString() => message;
}
