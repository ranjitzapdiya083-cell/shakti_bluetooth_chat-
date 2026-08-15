import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();

  /// Android 12+ needs BLUETOOTH_SCAN / BLUETOOTH_CONNECT.
  /// Android <12 needs ACCESS_FINE_LOCATION for discovery to return results.
  ///
  /// NOTE: location is requested for older devices, but is NOT required for
  /// success. On Android 12+ the manifest declares BLUETOOTH_SCAN with
  /// `neverForLocation`, and ACCESS_FINE_LOCATION/COARSE_LOCATION are capped
  /// at maxSdkVersion=30 — so on Android 12+ devices the OS never even shows
  /// a location prompt and Permission.location.status stays "denied"
  /// forever. Treating it as required made scanning silently refuse to
  /// start on Android 12+ even when every Bluetooth permission was granted.
  static Future<bool> requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    final bluetoothGranted = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].every((p) => statuses[p]?.isGranted == true || statuses[p]?.isLimited == true);

    return bluetoothGranted;
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
