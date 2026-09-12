import 'health_bridge.dart';
import 'wearable_data.dart';

HealthBridge createPlatformHealthBridge() => HealthBridgeStub();

/// Desktop / web / unsupported fallback: wearable connection is not supported,
/// so calls safely no-op and return null (absence honesty).
class HealthBridgeStub implements HealthBridge {
  @override
  bool get isSupported => false;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<WearableDailyData?> getDailyData(DateTime date) async => null;
}
