import 'package:flutter/material.dart';

import '../api/esp32_api.dart';
import '../services/wifi_platform.dart';
import '../store/device_store.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';

// Langkah 2 pairing: masukkan password (default 12345678), sambungkan, lalu simpan.
class PairConnectScreen extends StatefulWidget {
  const PairConnectScreen({super.key, required this.ssid, required this.store});

  final String ssid;
  final DeviceStore store;

  @override
  State<PairConnectScreen> createState() => _PairConnectScreenState();
}

class _PairConnectScreenState extends State<PairConnectScreen> {
  final _password = TextEditingController(text: kDefaultPassword);
  final _wifi = WifiPlatform();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final pw = _password.text;
    if (pw.length < 8) {
      setState(() => _error = 'Password minimal 8 karakter.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _wifi.connect(widget.ssid, pw);
      // Pastikan AP benar-benar merespons sebelum disimpan sebagai alat.
      await Esp32Api().getStatus();
      await widget.store.add(widget.ssid, pw);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on WifiConnectException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sambungkan alat')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jaringan',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.ssid,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _obscure,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'Default: $kDefaultPassword',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kRadiusButton),
                  borderSide: const BorderSide(
                    color: NotionColors.hairlineStrong,
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  tooltip: _obscure
                      ? 'Tampilkan password'
                      : 'Sembunyikan password',
                  color: NotionColors.steel,
                  onPressed: _busy
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: NotionColors.semanticError),
                ),
              ),
            FilledButton(
              onPressed: _busy ? null : _connect,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: NotionColors.onPrimary,
                      ),
                    )
                  : const Text('Sambungkan'),
            ),
            const SizedBox(height: 12),
            Text(
              'Android akan menampilkan permintaan "Sambungkan ke jaringan ini?". Pilih Sambungkan.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
