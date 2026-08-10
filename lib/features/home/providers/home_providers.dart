import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/device_entry.dart';
import '../../../core/providers/core_providers.dart';

final homeSearchQueryProvider = StateProvider<String>((ref) => '');

/// Devices with an existing conversation, sorted most-recent first.
final recentChatsProvider = Provider.autoDispose<List<DeviceEntry>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  ref.watch(_devicesTickProvider); // rebuild on Hive change
  final query = ref.watch(homeSearchQueryProvider).toLowerCase();

  final all = storage
      .getAllDevices()
      .where((d) => d.lastConnectedAt != null)
      .where((d) => query.isEmpty || d.displayName.toLowerCase().contains(query))
      .toList()
    ..sort((a, b) => (b.lastConnectedAt ?? DateTime(0)).compareTo(a.lastConnectedAt ?? DateTime(0)));
  return all;
});

final favoriteDevicesProvider = Provider.autoDispose<List<DeviceEntry>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  ref.watch(_devicesTickProvider);
  return storage.getAllDevices().where((d) => d.isFavorite).toList();
});

/// Simple tick provider so UI rebuilds whenever the Hive devices box changes.
final _devicesTickProvider = StreamProvider.autoDispose<void>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.watchDevices();
});
