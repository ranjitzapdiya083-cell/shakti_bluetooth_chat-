import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/device_entry.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/bluetooth_status_banner.dart';
import '../../../core/widgets/device_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_list_tile.dart';
import '../../bluetooth/providers/bluetooth_providers.dart';
import '../providers/home_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adapterState = ref.watch(adapterStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search chats & devices',
                  border: InputBorder.none,
                ),
                onChanged: (v) => ref.read(homeSearchQueryProvider.notifier).state = v,
              )
            : const Text('Shakti Chat'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (!_isSearching) {
                _searchController.clear();
                ref.read(homeSearchQueryProvider.notifier).state = '';
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            onPressed: () => context.push('/qr'),
            tooltip: 'Quick pair with QR',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Paired'),
            Tab(text: 'Nearby'),
          ],
        ),
      ),
      body: Column(
        children: [
          adapterState.when(
            data: (state) => BluetoothStatusBanner(
              state: state,
              onEnable: () => ref.read(bluetoothServiceProvider).requestEnable(),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _RecentChatsTab(),
                _PairedDevicesTab(),
                _NearbyDevicesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentChatsTab extends ConsumerWidget {
  const _RecentChatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(recentChatsProvider);
    final connectedAddress = ref.watch(connectedAddressProvider);

    if (chats.isEmpty) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'No chats yet',
        message: 'Pair with a nearby device to start your first Bluetooth conversation.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox.shrink(),
      itemBuilder: (context, i) {
        final chat = chats[i];
        return DeviceTile(
          name: chat.displayName,
          address: chat.address,
          subtitle: chat.lastMessagePreview ?? 'Tap to open chat',
          isConnected: connectedAddress == chat.address,
          unreadCount: chat.unreadCount,
          onTap: () => context.push('/chat/${chat.address}'),
        );
      },
    );
  }
}

class _PairedDevicesTab extends ConsumerWidget {
  const _PairedDevicesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairedAsync = ref.watch(pairedDevicesProvider);
    final connectedAddress = ref.watch(connectedAddressProvider);

    return pairedAsync.when(
      loading: () => const ShimmerListView(),
      error: (e, __) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Couldn\'t load paired devices',
        message: '$e',
      ),
      data: (devices) {
        if (devices.isEmpty) {
          return EmptyState(
            icon: Icons.bluetooth_connected_rounded,
            title: 'No paired devices',
            message: 'Go to the Nearby tab to discover and pair a device.',
            action: FilledButton.icon(
              onPressed: () => PermissionService.requestBluetoothPermissions(),
              icon: const Icon(Icons.perm_device_information_rounded, size: 18),
              label: const Text('Check permissions'),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: devices.length,
          itemBuilder: (context, i) {
            final d = devices[i];
            return DeviceTile(
              name: d.name ?? 'Unknown device',
              address: d.address,
              subtitle: d.address,
              isConnected: connectedAddress == d.address,
              isPaired: true,
              onTap: () async {
                final storage = ref.read(storageServiceProvider);
                var entry = storage.getDevice(d.address);
                entry ??= DeviceEntry(address: d.address, name: d.name ?? 'Unknown device');
                entry.lastConnectedAt = DateTime.now();
                await storage.upsertDevice(entry);
                final bt = ref.read(bluetoothServiceProvider);
                await bt.connect(d.address);
                if (context.mounted) context.push('/chat/${d.address}');
              },
            );
          },
        );
      },
    );
  }
}

class _NearbyDevicesTab extends ConsumerStatefulWidget {
  const _NearbyDevicesTab();

  @override
  ConsumerState<_NearbyDevicesTab> createState() => _NearbyDevicesTabState();
}

class _NearbyDevicesTabState extends ConsumerState<_NearbyDevicesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final granted = await PermissionService.requestBluetoothPermissions();
      if (granted) {
        ref.read(discoveryProvider.notifier).startScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(discoveryProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(discoveryProvider.notifier).startScan(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(
                  discovery.isScanning ? Icons.bluetooth_searching_rounded : Icons.bluetooth_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  discovery.isScanning ? 'Scanning for nearby devices…' : 'Pull to refresh scan',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                if (discovery.isScanning)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          Expanded(
            child: discovery.results.isEmpty
                ? (discovery.isScanning
                    ? const ShimmerListView()
                    : const EmptyState(
                        icon: Icons.wifi_tethering_rounded,
                        title: 'No devices found',
                        message: 'Make sure the other device has Bluetooth on and is discoverable, then pull to refresh.',
                      ))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: discovery.results.length,
                    itemBuilder: (context, i) {
                      final result = discovery.results[i];
                      final device = result.device;
                      return DeviceTile(
                        name: device.name ?? 'Unknown device',
                        address: device.address,
                        subtitle: device.isBonded ? 'Paired · ${device.address}' : device.address,
                        trailing: device.isBonded
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1FAE5B), size: 20)
                            : TextButton(
                                onPressed: () async {
                                  final bt = ref.read(bluetoothServiceProvider);
                                  final ok = await bt.pairDevice(device.address);
                                  if (ok && context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(content: Text('Paired with ${device.name ?? device.address}')));
                                    ref.invalidate(pairedDevicesProvider);
                                  }
                                },
                                child: const Text('Pair'),
                              ),
                        onTap: () async {
                          final storage = ref.read(storageServiceProvider);
                          var entry = storage.getDevice(device.address);
                          entry ??= DeviceEntry(address: device.address, name: device.name ?? 'Unknown device');
                          entry.lastConnectedAt = DateTime.now();
                          await storage.upsertDevice(entry);
                          final bt = ref.read(bluetoothServiceProvider);
                          await bt.connect(device.address);
                          if (context.mounted) context.push('/chat/${device.address}');
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
