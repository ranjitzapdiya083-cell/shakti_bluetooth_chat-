import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();

  /// Android 12+ needs BLUETOOTH_SCAN / BLUETOOTH_CONNECT.
  /// Android <12 needs ACCESS_FINE_LOCATION for discovery to return results.
  static Future<bool> requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    return statuses.values.every((s) => s.isGranted || s.isLimited);
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
