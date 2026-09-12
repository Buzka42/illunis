package com.illunis.illunis

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IllunisDreamService.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openDreamSettings" -> {
                        startActivity(Intent(Settings.ACTION_DREAM_SETTINGS))
                        result.success(null)
                    }
                    "finish" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "illunis/health_connect")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(false)
                    "requestPermissions" -> result.success(false)
                    "getDailyData" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
    }
}
