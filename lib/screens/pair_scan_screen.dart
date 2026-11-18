import 'package:flutter/material.dart';

import '../services/wifi_scan.dart';
import '../store/device_store.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import 'pair_connect_screen.dart';

// Langkah 1 pairing: pindai WiFi dan pilih jaringan ESP32-*.
class PairScanScreen extends StatefulWidget {
  const PairScanScreen({super.key, required this.store});

  final DeviceStore store;

  @override
  State<PairScanScreen> createState() => _PairScanScreenState();
}

class _PairScanScreenState extends State<PairScanScreen> {
  final WifiScanService _scanner = WifiScanService();
  List<String>? _ssids;
  String? _error;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final list = await _scanner.scanEspNetworks();
      if (!mounted) return;
      setState(() => _ssids = list);
    } on WifiScanException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memindai WiFi: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pick(String ssid) async {
    final paired = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PairConnectScreen(ssid: ssid, store: widget.store),
      ),
    );
    if (paired == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih alat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Pindai ulang',
            onPressed: _scanning ? null : _scan,
          ),
        ],
      ),
      body: ContentWidth(
        child: Builder(
          builder: (context) {
            if (_scanning) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null) {
              return _message(context, Icons.wifi_find, _error!);
            }
            final list = _ssids ?? const <String>[];
            if (list.isEmpty) {
              return _message(
                context,
                Icons.search_off,
                'Tidak ada jaringan ESP32-* ditemukan. Nyalakan alat, lalu pindai ulang.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: const Icon(Icons.wifi, color: NotionColors.ink),
                  title: Text(
                    list[i],
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: NotionColors.steel,
                  ),
                  onTap: () => _pick(list[i]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _message(BuildContext context, IconData icon, String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: NotionColors.steel),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _scan, child: const Text('Pindai ulang')),
        ],
      ),
    ),
  );
}
