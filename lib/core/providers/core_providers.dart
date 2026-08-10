import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bluetooth_service.dart';
import '../services/storage_service.dart';

/// Overridden in main.dart once StorageService.init() resolves.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in main()');
});

final bluetoothServiceProvider = Provider<AppBluetoothService>((ref) {
  return AppBluetoothService.instance;
});
