import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

// Satu-satunya tempat yang bicara ke ESP32. Endpoint & bentuk JSON mengikuti
// web_ui.ino -- jangan diubah di sini tanpa ubah firmware juga.
class Esp32Api {
  // Default = IP AP ESP32. Bisa diganti saat preview tanpa hardware lewat
  // --dart-define=ESP32_BASE_URL=http://localhost:8080 (lihat mock server).
  Esp32Api({
    this.baseUrl = const String.fromEnvironment(
      'ESP32_BASE_URL',
      defaultValue: 'http://192.168.4.1',
    ),
  });

  final String baseUrl;
  static const Duration _timeout = Duration(seconds: 3);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> _getJson(
    String path, [
    Map<String, String>? q,
  ]) async {
    final res = await _send(() => http.get(_uri(path, q)).timeout(_timeout));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      final res = await call();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiException(res.statusCode, res.body.trim());
      }
      return res;
    } on TimeoutException {
      throw const ApiException(
        null,
        'ESP32 tidak merespons (sibuk atau tidak terjangkau)',
      );
    } on SocketException {
      throw const ApiException(
        null,
        'Tidak terhubung ke ESP32-4MIC. Sambungkan WiFi HP ke jaringan itu dulu.',
      );
    } on http.ClientException {
      throw const ApiException(
        null,
        'Tidak terhubung ke ESP32-4MIC. Sambungkan WiFi HP ke jaringan itu dulu.',
      );
    }
  }

  Future<Status> getStatus() async =>
      Status.fromJson(await _getJson('/status'));

  Future<List<int>> getRespondents() async {
    final j = await _getJson('/respondents');
    return (j['respondents'] as List).cast<int>();
  }

  Future<int> createRespondent() async {
    final res = await _send(
      () => http.post(_uri('/respondents')).timeout(_timeout),
    );
    return (jsonDecode(res.body) as Map<String, dynamic>)['created'] as int;
  }

  Future<Set<int>> getHurufWithData(int responden) async {
    final j = await _getJson('/huruf', {'responden': '$responden'});
    return (j['withData'] as List).cast<int>().toSet();
  }

  Future<VariasiInfo> getVariasi(int responden, int huruf) async {
    final j = await _getJson('/variasi', {
      'responden': '$responden',
      'huruf': '$huruf',
    });
    return VariasiInfo(
      variants: (j['variants'] as List).cast<int>(),
      nextNew: j['nextNew'] as int,
    );
  }

  Future<int> select(int responden, int huruf, int variasi) async {
    final res = await _send(
      () => http
          .post(
            _uri('/select', {
              'responden': '$responden',
              'huruf': '$huruf',
              'variasi': '$variasi',
            }),
          )
          .timeout(_timeout),
    );
    return (jsonDecode(res.body) as Map<String, dynamic>)['nextTake'] as int;
  }

  Future<void> start() async {
    await _send(() => http.post(_uri('/start')).timeout(_timeout));
  }

  Future<void> stop() async {
    await _send(() => http.post(_uri('/stop')).timeout(_timeout));
  }

  Future<List<Take>> getTakes(int responden, int huruf, int variasi) async {
    final j = await _getJson('/takes', {
      'responden': '$responden',
      'huruf': '$huruf',
      'variasi': '$variasi',
    });
    return (j['takes'] as List)
        .map(
          (e) => Take.fromJson(
            e as Map<String, dynamic>,
            responden,
            huruf,
            variasi,
          ),
        )
        .toList();
  }

  /// `take.micPath(n)` yang dikirim ke /download?path=... (base path tanpa _MICn.wav).
  Future<List<int>> downloadMic(String path) async {
    final res = await _send(
      () => http
          .get(_uri('/download', {'path': path}))
          .timeout(const Duration(seconds: 60)),
    );
    return res.bodyBytes;
  }

  Future<void> deleteTake(String basePath) async {
    await _send(
      () => http
          .post(_uri('/delete', {'scope': 'take', 'path': basePath}))
          .timeout(_timeout),
    );
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int? statusCode;
  final String message;

  @override
  String toString() => message;
}

class Status {
  Status({
    required this.recording,
    required this.elapsedSec,
    required this.sdReady,
    required this.sdPresent,
    required this.targetSelected,
    required this.responden,
    required this.huruf,
    required this.variasi,
    required this.nextTake,
    required this.currentTake,
  });

  final bool recording;
  final int elapsedSec;
  final bool sdReady;
  final bool sdPresent;
  final bool targetSelected;
  final int responden;
  final int huruf;
  final int variasi;
  final int nextTake;
  final int currentTake;

  factory Status.fromJson(Map<String, dynamic> j) => Status(
    recording: j['recording'] as bool,
    elapsedSec: j['elapsed_sec'] as int,
    sdReady: j['sdReady'] as bool,
    sdPresent: j['sdPresent'] as bool,
    targetSelected: j['targetSelected'] as bool,
    responden: j['responden'] as int,
    huruf: j['huruf'] as int,
    variasi: j['variasi'] as int,
    nextTake: j['nextTake'] as int,
    currentTake: j['currentTake'] as int,
  );
}

class VariasiInfo {
  const VariasiInfo({required this.variants, required this.nextNew});

  final List<int> variants;
  final int nextNew;
}

class Take {
  Take({
    required this.take,
    required this.done,
    required this.bytes,
    required this.responden,
    required this.huruf,
    required this.variasi,
  });

  final int take;
  final bool done;
  final List<int> bytes; // ukuran per mic (4 elemen)
  final int responden;
  final int huruf;
  final int variasi;

  /// Base path sama persis dengan yang dipakai web UI: /RSPDN{r}/HRF{h}/VRS{v}/RSPDN{r}_HRF{h}_VRS{v}_{take}
  String get basePath =>
      '/RSPDN$responden/HRF$huruf/VRS$variasi/RSPDN${responden}_HRF${huruf}_VRS${variasi}_$take';

  String micPath(int mic) => '${basePath}_MIC$mic.wav';

  factory Take.fromJson(
    Map<String, dynamic> j,
    int responden,
    int huruf,
    int variasi,
  ) => Take(
    take: j['take'] as int,
    done: j['done'] as bool,
    bytes: (j['bytes'] as List).cast<int>(),
    responden: responden,
    huruf: huruf,
    variasi: variasi,
  );
}
