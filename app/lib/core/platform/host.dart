import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native host for the nightstand screensaver and Android settings.
///
/// The channel is implemented by `MainActivity` (opens screensaver settings)
/// and `IllunisDreamService` (finishes the dream). On every other platform
/// the calls no-op, so the in-app preview still works on Windows.
class Host {
  const Host._();

  static const _channel = MethodChannel('illunis/host');

  static Future<void> finishDream() async {
    try {
      await _channel.invokeMethod<void>('finish');
    } on MissingPluginException {
      // Desktop preview, or the channel is not wired on this embedder.
    }
  }

  static Future<bool> openDreamSettings() async {
    try {
      await _channel.invokeMethod<void>('openDreamSettings');
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
