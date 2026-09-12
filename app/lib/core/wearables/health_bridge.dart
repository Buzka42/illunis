import 'health_bridge_stub.dart' if (dart.library.io) 'health_bridge_io.dart';
import 'wearable_data.dart';

/// Platform interface for wearable / health data (Health Connect on Android).
/// Desktop and unsupported platforms fall back to journal-derived figures.
abstract class HealthBridge {
  static HealthBridge create() => createPlatformHealthBridge();

  bool get isSupported;

  Future<bool> isAvailable();

  Future<bool> requestPermissions();

  Future<WearableDailyData?> getDailyData(DateTime date);
}
