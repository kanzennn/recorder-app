import 'package:flutter/material.dart';

import '../store/device_store.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import 'device_hub_screen.dart';
import 'pair_scan_screen.dart';

// Layar awal: daftar alat yang sudah di-pair. Kosong -> ajak tambah alat.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final DeviceStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alat Saya')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => PairScanScreen(store: store))),
        icon: const Icon(Icons.add),
        label: const Text('Tambah alat'),
        backgroundColor: NotionColors.primary,
        foregroundColor: NotionColors.onPrimary,
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final devices = store.devices;
          if (devices.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Belum ada alat',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tekan "Tambah alat", lalu pilih ESP32-4MIC dari daftar WiFi.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }
          final width = screenWidth(context);
          if (width >= Breakpoints.medium) {
            // Tablet & lebar: kartu dalam grid, dibatasi lebarnya.
            final columns = width >= Breakpoints.expanded ? 3 : 2;
            return ContentWidth(
              maxWidth: 960,
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: devices.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 88,
                ),
                itemBuilder: (context, i) => _deviceCard(context, devices[i]),
              ),
            );
          }
          return ContentWidth(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: devices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _deviceCard(context, devices[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _deviceCard(BuildContext context, PairedDevice d) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.mic, color: NotionColors.ink),
        title: Text(d.ssid, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(
          d.lastUsed == null
              ? 'Belum pernah dibuka'
              : 'Terakhir dibuka ${_fmt(d.lastUsed!)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right, color: NotionColors.steel),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DeviceHubScreen(device: d, store: store),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime t) {
    final l = t.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
