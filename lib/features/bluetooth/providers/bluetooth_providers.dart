import 'dart:async';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/services/bluetooth_service.dart';

/// Whether the adapter itself is on/off.
final adapterStateProvider = StreamProvider<BluetoothState>((ref) {
  final bt = ref.watch(bluetoothServiceProvider);
  bt.initAdapterListener();
  return bt.adapterState;
});

/// Currently paired (bonded) devices.
final pairedDevicesProvider = FutureProvider.autoDispose<List<BluetoothDevice>>((ref) async {
  final bt = ref.watch(bluetoothServiceProvider);
  return bt.getPairedDevices();
});

/// Live discovery scan state — a controller-backed notifier so the UI can
/// start/stop scanning and get a growing, de-duplicated device list.
class DiscoveryState {
  final bool isScanning;
  final List<BluetoothDiscoveryResult> results;
  const DiscoveryState({this.isScanning = false, this.results = const []});

  DiscoveryState copyWith({bool? isScanning, List<BluetoothDiscoveryResult>? results}) {
    return DiscoveryState(isScanning: isScanning ?? this.isScanning, results: results ?? this.results);
  }
}

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final AppBluetoothService _bt;
  StreamSubscription<BluetoothDiscoveryResult>? _sub;

  DiscoveryNotifier(this._bt) : super(const DiscoveryState());

  Future<void> startScan() async {
    await _sub?.cancel();
    state = state.copyWith(isScanning: true, results: []);
    _sub = _bt.startDiscovery().listen(
      (result) {
        final existingIndex = state.results.indexWhere((r) => r.device.address == result.device.address);
        final updated = [...state.results];
        if (existingIndex >= 0) {
          updated[existingIndex] = result;
        } else {
          updated.add(result);
        }
        state = state.copyWith(results: updated);
      },
      onDone: () => state = state.copyWith(isScanning: false),
    );
  }

  Future<void> stopScan() async {
    await _bt.cancelDiscovery();
    await _sub?.cancel();
    state = state.copyWith(isScanning: false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final discoveryProvider = StateNotifierProvider.autoDispose<DiscoveryNotifier, DiscoveryState>((ref) {
  final bt = ref.watch(bluetoothServiceProvider);
  return DiscoveryNotifier(bt);
});

/// Current RFCOMM connection state, exposed as a stream for the whole app
/// (chat header, connection banners, home screen status chip, etc).
final connectionStateProvider = StreamProvider<BtConnectionState>((ref) {
  final bt = ref.watch(bluetoothServiceProvider);
  return bt.connectionState;
});

/// Re-evaluates whenever the connection state stream emits, so the UI
/// (device tiles, chat header) reflects connect/disconnect immediately.
final connectedAddressProvider = Provider<String?>((ref) {
  ref.watch(connectionStateProvider);
  final bt = ref.watch(bluetoothServiceProvider);
  return bt.connectedAddress;
});
