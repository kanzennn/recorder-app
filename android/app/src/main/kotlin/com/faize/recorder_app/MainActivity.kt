package com.faize.recorder_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val wifi = WifiChannel(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "recorder/wifi")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connect" -> {
                        val ssid = call.argument<String>("ssid")
                        val password = call.argument<String>("password")
                        if (ssid == null || password == null) {
                            result.error("BAD_ARGS", "ssid/password kosong", null)
                        } else {
                            wifi.connect(ssid, password, result)
                        }
                    }
                    "disconnect" -> {
                        wifi.disconnect()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        val downloads = DownloadsChannel(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "recorder/downloads")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val fileName = call.argument<String>("fileName")
                        val bytes = call.argument<ByteArray>("bytes")
                        if (fileName == null || bytes == null) {
                            result.error("BAD_ARGS", "fileName/bytes kosong", null)
                        } else {
                            downloads.saveToDownloads(fileName, bytes, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
