import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/esp32_api.dart';
import '../data/huruf.dart';
import '../services/downloads.dart';
import '../store/connection_controller.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';

// Tab "Lihat Data": read-only. TIDAK PERNAH memanggil /select -- browsing
// tidak boleh diam-diam mengubah target yang bakal dipakai /start berikutnya.
//
// CATATAN: sempat ada tombol "Putar" (streaming langsung lewat audioplayers/
// ExoPlayer), tapi di-revert -- bikin WiFi AP ESP32 nggak stabil tiap kali
// streaming jalan, kemungkinan karena ExoPlayer buka beberapa koneksi HTTP
// (request Range) yang nggak ditangani baik oleh WebServer.h yang simpel di
// firmware. Unduh (satu request, satu koneksi) tetap aman dipakai.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key, required this.api, required this.connection});

  final Esp32Api api;
  final ConnectionController connection;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _downloads = DownloadsService();

  List<int> _respondents = [];
  Set<int> _withData = {};
  List<int> _variants = [];
  List<Take> _takes = [];

  int? _r;
  int? _h;
  int? _v;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadRespondents();
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadRespondents() async {
    try {
      final r = await widget.api.getRespondents();
      if (!mounted) return;
      setState(() => _respondents = r);
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _pickResponden(int n) async {
    setState(() {
      _r = n;
      _h = null;
      _v = null;
      _variants = [];
      _takes = [];
    });
    try {
      final withData = await widget.api.getHurufWithData(n);
      if (!mounted) return;
      setState(() => _withData = withData);
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _pickHuruf(int h) async {
    setState(() {
      _h = h;
      _v = null;
      _takes = [];
    });
    try {
      final info = await widget.api.getVariasi(_r!, h);
      if (!mounted) return;
      setState(() => _variants = info.variants);
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _pickVariasi(int v) async {
    setState(() => _v = v);
    await _loadTakes();
  }

  Future<void> _loadTakes() async {
    try {
      final takes = await widget.api.getTakes(_r!, _h!, _v!);
      if (!mounted) return;
      setState(() => _takes = takes);
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _download(Take take, int mic) async {
    setState(() => _busy = true);
    // ESP32 (WebServer.h) cuma layani satu koneksi sekaligus -- selama
    // download jalan, polling /status rutin dari ConnectionController bakal
    // ngantre lama di belakangnya, kena timeout, dan keliru menyimpulkan
    // "device terputus" padahal cuma lagi sibuk kirim file. Bekukan dulu.
    widget.connection.suspendChecks();
    try {
      final bytes = await widget.api.downloadMic(take.micPath(mic));
      final name = take.micPath(mic).split('/').last;
      final path = await _downloads.saveToDownloads(
        name,
        Uint8List.fromList(bytes),
      );
      _showMessage('Tersimpan: $path');
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      widget.connection.resumeChecks();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteTake(Take take) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus take ini?'),
        content: Text(
          'Take ${take.take} (4 file mic) akan dihapus dari SD card.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: NotionColors.semanticError,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.deleteTake(take.basePath);
      await _loadTakes();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isExpandedWidth(context)) {
      // Layar lebar: pilihan di kiri, daftar take di kanan, supaya tidak ada
      // ruang kosong di kiri-kanan kolom 720dp dan daftar take tidak perlu
      // digulir lewat pilihan dulu.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _selectionWidgets(),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 6,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _takeWidgets(),
            ),
          ),
        ],
      );
    }

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._selectionWidgets(),
          const SizedBox(height: 24),
          ..._takeWidgets(),
        ],
      ),
    );
  }

  List<Widget> _selectionWidgets() => [
    _section(
      'RESPONDEN',
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final n in _respondents)
            SelectTile(
              label: 'RESPONDEN $n',
              selected: _r == n,
              onTap: () => _pickResponden(n),
            ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    _section(
      'HURUF',
      _r == null
          ? const Text('Pilih responden dulu.')
          : _withData.isEmpty
          ? const Text('Belum ada data.')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in _withData.toList()..sort())
                  SelectTile(
                    label: hurufByIndex(h).label,
                    selected: _h == h,
                    onTap: () => _pickHuruf(h),
                  ),
              ],
            ),
    ),
    const SizedBox(height: 20),
    _section(
      'VARIASI',
      _h == null
          ? const Text('Pilih huruf dulu.')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in _variants)
                  SelectTile(
                    label: 'Variasi $v',
                    selected: _v == v,
                    onTap: () => _pickVariasi(v),
                  ),
              ],
            ),
    ),
  ];

  List<Widget> _takeWidgets() => [
    Text('TAKE', style: Theme.of(context).textTheme.labelSmall),
    const SizedBox(height: 8),
    if (_v == null)
      Text('Pilih variasi dulu.', style: Theme.of(context).textTheme.bodySmall)
    else if (_takes.isEmpty)
      Text('Belum ada take.', style: Theme.of(context).textTheme.bodySmall)
    else
      for (final t in _takes)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _takeCard(t),
        ),
    if (_busy)
      const Padding(
        padding: EdgeInsets.only(top: 12),
        child: LinearProgressIndicator(color: NotionColors.primary),
      ),
  ];

  Widget _section(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 8),
      child,
    ],
  );

  Widget _takeCard(Take t) {
    final kb = t.bytes.map((b) => (b / 1024).toStringAsFixed(0)).join(' / ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Take ${t.take}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TagBadge(
                  label: t.done ? 'Selesai' : 'Belum selesai',
                  background: t.done
                      ? NotionColors.cardTintMint
                      : NotionColors.cardTintPeach,
                  foreground: t.done
                      ? NotionColors.brandGreen
                      : NotionColors.semanticWarning,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: NotionColors.steel,
                  ),
                  tooltip: 'Hapus take',
                  onPressed: _busy ? null : () => _deleteTake(t),
                ),
              ],
            ),
            Text(
              '$kb KB per mic',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var mic = 1; mic <= 4; mic++)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _download(t, mic),
                    child: Text('Mic $mic'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
