import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/models/device_entry.dart';
import '../../../core/providers/core_providers.dart';

/// QR payload format: shakti-bt://<mac-address>/<device-name>
/// Scanning a peer's QR jumps straight to pairing + opening the chat,
/// which is much faster than hunting through a discovery list.
class QrScreen extends ConsumerStatefulWidget {
  const QrScreen({super.key});

  @override
  ConsumerState<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends ConsumerState<QrScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick pair'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'My QR'), Tab(text: 'Scan')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_MyQrTab(), _ScanQrTab()],
      ),
    );
  }
}

class _MyQrTab extends StatelessWidget {
  const _MyQrTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: FlutterBluetoothSerial.instance.address,
      builder: (context, snapshot) {
        final address = snapshot.data;
        if (address == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final payload = 'shakti-bt://$address/device';
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: QrImageView(data: payload, size: 220),
                ),
                const SizedBox(height: 20),
                Text('Ask a friend to scan this to pair instantly',
                    style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(address, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScanQrTab extends ConsumerStatefulWidget {
  const _ScanQrTab();

  @override
  ConsumerState<_ScanQrTab> createState() => _ScanQrTabState();
}

class _ScanQrTabState extends ConsumerState<_ScanQrTab> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || !raw.startsWith('shakti-bt://')) return;

    final withoutScheme = raw.replaceFirst('shakti-bt://', '');
    final parts = withoutScheme.split('/');
    final address = parts.first;
    setState(() => _handled = true);

    final storage = ref.read(storageServiceProvider);
    var entry = storage.getDevice(address);
    entry ??= DeviceEntry(address: address, name: 'Paired via QR');
    entry.lastConnectedAt = DateTime.now();
    await storage.upsertDevice(entry);

    final bt = ref.read(bluetoothServiceProvider);
    await bt.pairDevice(address);
    await bt.connect(address);

    if (mounted) context.replace('/chat/$address');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
