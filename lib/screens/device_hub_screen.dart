import 'package:flutter/material.dart';

import '../store/connection_controller.dart';
import '../store/device_store.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import 'browse_screen.dart';
import 'device_info_screen.dart';
import 'record_screen.dart';

// Hub satu alat: sambungkan dulu, lalu tab Rekam / Lihat Data / Info.
// HP: navigasi di bawah. Tablet/lebar: navigasi di kiri.
class DeviceHubScreen extends StatefulWidget {
  const DeviceHubScreen({
    super.key,
    required this.device,
    required this.store,
    this.controller,
  });

  final PairedDevice device;
  final DeviceStore store;

  /// Hanya untuk test: ganti controller (dan API) dengan versi palsu.
  final ConnectionController? controller;

  @override
  State<DeviceHubScreen> createState() => _DeviceHubScreenState();
}

class _DeviceHubScreenState extends State<DeviceHubScreen> {
  late final ConnectionController _ctrl;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ctrl =
        widget.controller ??
        ConnectionController(device: widget.device, store: widget.store);
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
    _ctrl.connect();
    _ctrl.startPolling();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.fiber_manual_record),
      label: 'Rekam',
    ),
    NavigationDestination(icon: Icon(Icons.folder_open), label: 'Lihat Data'),
    NavigationDestination(icon: Icon(Icons.info_outline), label: 'Info'),
  ];

  Widget _content() => SafeArea(top: false, child: _contentBody());

  Widget _contentBody() {
    if (_ctrl.connecting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_ctrl.connected) return _offline(context);
    return IndexedStack(
      index: _index,
      children: [
        RecordScreen(api: _ctrl.api),
        BrowseScreen(api: _ctrl.api, connection: _ctrl),
        DeviceInfoScreen(controller: _ctrl),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = isExpandedWidth(context);

    if (wide && _ctrl.connected) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.device.ssid)),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.fiber_manual_record),
                  label: Text('Rekam'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.folder_open),
                  label: Text('Lihat Data'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.info_outline),
                  label: Text('Info'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _content()),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.device.ssid)),
      body: _content(),
      bottomNavigationBar: _ctrl.connected
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: _destinations,
            )
          : null,
    );
  }

  Widget _offline(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: NotionColors.steel),
          const SizedBox(height: 12),
          Text(
            'Belum tersambung',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Pastikan alat menyala, lalu sambungkan ulang.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_ctrl.error != null) ...[
            const SizedBox(height: 8),
            Text(
              _ctrl.error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: NotionColors.semanticError),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _ctrl.connect,
            child: const Text('Sambungkan'),
          ),
        ],
      ),
    ),
  );
}
