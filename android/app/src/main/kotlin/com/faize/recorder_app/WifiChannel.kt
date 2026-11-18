package com.faize.recorder_app

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import io.flutter.plugin.common.MethodChannel

// Menyambungkan HP ke AP ESP32 (tanpa internet) lewat WifiNetworkSpecifier, lalu
// mengikat semua trafik proses app ke jaringan itu supaya HTTP ke 192.168.4.1 jalan.
class WifiChannel(context: Context) {
    private val cm = context.getSystemService(ConnectivityManager::class.java)
    private var callback: ConnectivityManager.NetworkCallback? = null

    fun connect(ssid: String, password: String, result: MethodChannel.Result) {
        callback?.let { cm.unregisterNetworkCallback(it) }

        val specifier = WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
            .setWpa2Passphrase(password)
            .build()
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()

        var replied = false
        fun reply(block: () -> Unit) {
            if (replied) return
            replied = true
            block()
        }

        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                cm.bindProcessToNetwork(network)
                reply { result.success(true) }
            }

            override fun onUnavailable() {
                reply { result.error("UNAVAILABLE", "Gagal tersambung ke $ssid (ditolak atau timeout)", null) }
            }
        }
        callback = cb
        // Timeout 20 detik: kalau user tidak menerima prompt atau AP tidak ketemu.
        cm.requestNetwork(request, cb, 20_000)
    }

    fun disconnect() {
        callback?.let { cm.unregisterNetworkCallback(it) }
        callback = null
        cm.bindProcessToNetwork(null)
    }
}
