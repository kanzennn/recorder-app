import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'store/device_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DeviceStore(
    prefs: await SharedPreferences.getInstance(),
    secrets: SecureSecretStore(),
  );
  await store.load();
  runApp(RecorderApp(store: store));
}

class RecorderApp extends StatelessWidget {
  const RecorderApp({super.key, required this.store});

  final DeviceStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recorder',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeScreen(store: store),
    );
  }
}
