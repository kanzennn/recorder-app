import 'dart:async';

import 'package:flutter/material.dart';

import '../api/esp32_api.dart';
import '../data/huruf.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';

// Tab "Rekam Baru": pilih Responden -> Huruf -> Variasi, lalu Rekam/Stop.
// Logika sengaja mengikuti web page (web_ui.ino INDEX_HTML).
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key, required this.api});

  final Esp32Api api;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  List<int> _respondents = [];
  Set<int> _withData = {};
  VariasiInfo? _variasi;

  int? _selR;
  int? _selH;
  int? _selV;

  Status? _status;
  String? _targetPreview;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadRespondents();
    _refreshStatus();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Future<void> _refreshStatus() async {
    try {
      final s = await widget.api.getStatus();
      if (!mounted) return;
      setState(() => _status = s);
      // Ambil target yang sudah tersimpan di alat HANYA saat app belum punya
      // pilihan sendiri (mis. app baru dibuka). Jangan timpa pilihan yang lagi
      // dibuat user: responden/huruf baru belum dikirim ke alat (/select baru
      // dipanggil saat variasi dipilih), jadi status alat masih target lama
      // dan polling 2 detik bakal melempar user balik ke pilihan sebelumnya.
      // Tombol fisik tidak lagi mengubah target, jadi sinkron terus-menerus
      // tidak diperlukan.
      if (s.targetSelected && _selR == null) {
        _selR = s.responden;
        _selH = s.huruf;
        _selV = s.variasi;
        _targetPreview = _previewText(s.nextTake);
        await _loadRespondentsAndHuruf();
      }
    } catch (_) {
      // Status gagal dimuat -- layar tetap tampil, pesan error ditangani saat aksi.
    }
  }

  Future<void> _loadRespondents() async {
    try {
      final r = await widget.api.getRespondents();
      if (!mounted) return;
      setState(() => _respondents = r);
      if (_selR != null) await _loadRespondentsAndHuruf();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _loadRespondentsAndHuruf() async {
    if (_selR == null) return;
    try {
      final withData = await widget.api.getHurufWithData(_selR!);
      if (!mounted) return;
      setState(() => _withData = withData);
      if (_selH != null) await _loadVariasi();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _loadVariasi() async {
    if (_selR == null || _selH == null) return;
    try {
      final v = await widget.api.getVariasi(_selR!, _selH!);
      if (!mounted) return;
      setState(() => _variasi = v);
    } catch (e) {
      _showError(e);
    }
  }

  String _previewText(int nextTake) =>
      'RESPONDEN $_selR  ·  ${hurufByIndex(_selH!).label}  ·  Variasi $_selV  ·  Take $nextTake';

  bool get _recording => _status?.recording ?? false;

  Future<void> _addResponden() async {
    if (_recording) return;
    try {
      final created = await widget.api.createRespondent();
      if (!mounted) return;
      setState(() {
        _selR = created;
        _selH = null;
        _selV = null;
        _variasi = null;
        _targetPreview = null;
      });
      await _loadRespondents();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _pickResponden(int n) async {
    if (_recording) return;
    setState(() {
      _selR = n;
      _selH = null;
      _selV = null;
      _variasi = null;
      _targetPreview = 'Pilih huruf dan variasi.';
    });
    await _loadRespondentsAndHuruf();
  }

  Future<void> _pickHuruf(int n) async {
    if (_recording) return;
    setState(() {
      _selH = n;
      _selV = null;
      _targetPreview = 'Pilih variasi.';
    });
    await _loadVariasi();
  }

  Future<void> _pickVariasi(int v) async {
    if (_recording) return;
    setState(() => _selV = v);
    try {
      final nextTake = await widget.api.select(_selR!, _selH!, v);
      if (!mounted) return;
      setState(() => _targetPreview = _previewText(nextTake));
      await _loadVariasi();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _start() async {
    try {
      await widget.api.start();
      await _refreshStatus();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _stop() async {
    try {
      await widget.api.stop();
      await _refreshStatus();
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final canRecord =
        s != null && s.targetSelected && !s.recording && s.sdPresent;

    final startButton = FilledButton.icon(
      onPressed: canRecord ? _start : null,
      icon: const Icon(Icons.fiber_manual_record, size: 16),
      label: const Text('Mulai rekam'),
    );
    // STOP selalu bisa ditekan (sama seperti web) -- klik pas nggak rekam itu aman.
    final stopButton = OutlinedButton.icon(
      onPressed: _stop,
      icon: const Icon(Icons.stop, size: 16),
      label: const Text('Stop'),
    );

    if (isExpandedWidth(context)) {
      // Layar lebar: tiga pilihan berdampingan (Responden | Huruf | Variasi),
      // seperti di mockup. Tombol aksi di bawah.
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusCard(s),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _scrollColumn(
                      _section('RESPONDEN', _respondentTiles()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _scrollColumn(_section('HURUF', _hurufTiles())),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _scrollColumn(_section('VARIASI', _variasiTiles())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _targetPreview == null
                      ? const SizedBox.shrink()
                      : Text(
                          _targetPreview!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 180, child: startButton),
                const SizedBox(width: 12),
                SizedBox(width: 140, child: stopButton),
              ],
            ),
          ],
        ),
      );
    }

    final listChildren = [
      _statusCard(s),
      const SizedBox(height: 20),
      _section('RESPONDEN', _respondentTiles()),
      const SizedBox(height: 20),
      _section('HURUF', _hurufTiles()),
      const SizedBox(height: 20),
      _section('VARIASI', _variasiTiles()),
    ];

    // HP landscape: tingginya cuma ~200dp setelah app bar & navigasi, jadi
    // bilah tombol di bawah memakan hampir semuanya. Pakai panel samping.
    final shortAndWide =
        MediaQuery.sizeOf(context).height < 500 &&
        screenWidth(context) >= Breakpoints.medium;
    if (shortAndWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: listChildren,
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 220,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_targetPreview != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _targetPreview!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  startButton,
                  const SizedBox(height: 8),
                  stopButton,
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Tombol Mulai/Stop ditempel di bawah (di luar ListView): daftar huruf
    // panjang, jadi kalau ikut menggulir user harus scroll jauh tiap kali rekam.
    return ContentWidth(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: listChildren,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_targetPreview != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _targetPreview!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                // CTA utama (satu-satunya tombol ungu) sesuai DESIGN.md.
                Row(
                  children: [
                    Expanded(flex: 3, child: startButton),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: stopButton),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Kolom yang bisa di-scroll sendiri (dipakai di layar lebar, supaya huruf yang banyak tetap bisa digulir).
  Widget _scrollColumn(Widget child) => SingleChildScrollView(child: child);

  Widget _statusCard(Status? s) {
    final sdLabel = s == null
        ? 'SD memuat...'
        : !s.sdReady
        ? 'SD Failed'
        : !s.sdPresent
        ? 'SD Disconnected'
        : 'SD Connected';
    final sdOk = s != null && s.sdReady && s.sdPresent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wrap (bukan Row) supaya badge SD dan penanda REC turun ke baris
            // berikutnya di layar sempit / teks besar, bukan meluap.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                TagBadge(
                  label: sdLabel,
                  background: sdOk
                      ? NotionColors.cardTintMint
                      : NotionColors.cardTintPeach,
                  foreground: sdOk
                      ? NotionColors.brandGreen
                      : NotionColors.semanticError,
                ),
                if (s != null && s.recording)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: NotionColors.semanticError,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'REC ${_fmtElapsed(s.elapsedSec)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              s == null
                  ? 'Memuat status...'
                  : s.recording
                  ? 'Sedang merekam take ${s.currentTake}'
                  : 'Idle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (s != null && s.recording) ...[
              const SizedBox(height: 4),
              Text(
                'RESPONDEN ${s.responden}  ·  ${hurufByIndex(s.huruf).label}  ·  Variasi ${s.variasi}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtElapsed(int sec) =>
      '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';

  Widget _section(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 8),
      child,
    ],
  );

  Widget _respondentTiles() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final n in _respondents)
        SelectTile(
          label: 'RESPONDEN $n',
          selected: _selR == n,
          onTap: () => _pickResponden(n),
        ),
      TextButton.icon(
        onPressed: _addResponden,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Tambah responden'),
      ),
    ],
  );

  Widget _hurufTiles() {
    if (_selR == null) return const Text('Pilih responden dulu.');
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final h in hurufList)
          SelectTile(
            label: h.label,
            selected: _selH == h.index,
            hasData: _withData.contains(h.index),
            onTap: () => _pickHuruf(h.index),
          ),
      ],
    );
  }

  Widget _variasiTiles() {
    if (_selH == null || _variasi == null) {
      return const Text('Pilih huruf dulu.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in _variasi!.variants)
          SelectTile(
            label: 'Variasi $v',
            selected: _selV == v,
            onTap: () => _pickVariasi(v),
          ),
        TextButton.icon(
          onPressed: () => _pickVariasi(_variasi!.nextNew),
          icon: const Icon(Icons.add, size: 16),
          label: Text('Variasi ${_variasi!.nextNew} (baru)'),
        ),
      ],
    );
  }
}
