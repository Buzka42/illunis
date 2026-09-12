import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'health_bridge.dart';
import 'health_bridge_stub.dart';
import 'wearable_data.dart';

HealthBridge createPlatformHealthBridge() {
  if (Platform.isAndroid) {
    return HealthBridgeAndroid();
  }
  return HealthBridgeStub();
}

/// Android Health Connect bridge via platform channel.
class HealthBridgeAndroid implements HealthBridge {
  static const _channel = MethodChannel('illunis/health_connect');

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Future<bool> isAvailable() async {
    try {
      final res = await _channel.invokeMethod<bool>('isAvailable');
      return res ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestPermissions');
      return res ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<WearableDailyData?> getDailyData(DateTime date) async {
    try {
      final res = await _channel.invokeMapMethod<String, Object?>(
        'getDailyData',
        {'date': date.toIso8601String()},
      );
      if (res == null) return null;
      return WearableDailyData.fromJson(res);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
