import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();

  /// The flutter_bluetooth_serial plugin's native discovery/bonded-devices
  /// code checks ACCESS_FINE_LOCATION at runtime on ALL Android versions
  /// (it predates BLUETOOTH_SCAN's `neverForLocation` exception), so
  /// location must actually be granted — on Android 12+ too — or discovery
  /// throws PlatformException(no_permissions, "discovering other devices
  /// requires location access permission").
  static Future<bool> requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    return [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].every((p) => statuses[p]?.isGranted == true || statuses[p]?.isLimited == true);
  }

  static Future<bool> hasBluetoothPermissions() async {
    final scan = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;
    return scan.isGranted && connect.isGranted;
  }

  static Future<bool> requestStoragePermissions() async {
    final status = await Permission.storage.request();
    final photos = await Permission.photos.request();
    return status.isGranted || photos.isGranted;
  }

  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<void> openSettings() => openAppSettings();
}
