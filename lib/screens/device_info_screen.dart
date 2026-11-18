import 'package:flutter/material.dart';

import '../api/esp32_api.dart';
import '../services/wifi_platform.dart';
import '../store/connection_controller.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';

// Tab Info: detail alat, status SD, dan aksi "Lupakan alat".
class DeviceInfoScreen extends StatefulWidget {
  const DeviceInfoScreen({super.key, required this.controller});

  final ConnectionController controller;

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  Status? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await widget.controller.api.getStatus();
      if (mounted) setState(() => _status = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _forget() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lupakan alat ini?'),
        content: Text(
          '${widget.controller.device.ssid} akan dihapus dari daftar. Data rekaman di SD card tidak ikut terhapus.',
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
            child: const Text('Lupakan'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await widget.controller.store.remove(widget.controller.device.ssid);
    try {
      await WifiPlatform().disconnect();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.controller.device;
    final s = _status;
    final sdOk = s != null && s.sdReady && s.sdPresent;

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(context, 'Nama jaringan', device.ssid),
                  const Divider(height: 24),
                  _row(context, 'Alamat', 'http://192.168.4.1'),
                  const Divider(height: 24),
                  _row(
                    context,
                    'Status SD',
                    s == null
                        ? (_error ?? 'Memuat...')
                        : !s.sdReady
                        ? 'Gagal'
                        : !s.sdPresent
                        ? 'Tidak terpasang'
                        : 'Terhubung',
                    valueColor: s == null
                        ? null
                        : (sdOk
                              ? NotionColors.brandGreen
                              : NotionColors.semanticError),
                  ),
                  const Divider(height: 24),
                  _row(
                    context,
                    'Terakhir dibuka',
                    device.lastUsed == null
                        ? '-'
                        : device.lastUsed!.toLocal().toString().substring(
                            0,
                            16,
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: widget.controller.connecting
                ? null
                : widget.controller.connect,
            child: const Text('Sambungkan ulang'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _forget,
            style: TextButton.styleFrom(
              foregroundColor: NotionColors.semanticError,
            ),
            child: const Text('Lupakan alat'),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 4),
      Text(
        value,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: valueColor),
      ),
    ],
  );
}
