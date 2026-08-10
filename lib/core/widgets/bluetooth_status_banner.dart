import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothStatusBanner extends StatelessWidget {
  final BluetoothState state;
  final VoidCallback onEnable;

  const BluetoothStatusBanner({super.key, required this.state, required this.onEnable});

  @override
  Widget build(BuildContext context) {
    if (state == BluetoothState.STATE_ON) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth_disabled_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bluetooth is off — turn it on to find and chat with nearby devices.',
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 13.5, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: onEnable,
            style: TextButton.styleFrom(foregroundColor: scheme.onErrorContainer),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}
