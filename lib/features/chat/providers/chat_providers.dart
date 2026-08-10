import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/models/device_entry.dart';
import '../../../core/providers/core_providers.dart';

const _uuid = Uuid();

/// Messages for one conversation, kept in sync with Hive + live incoming
/// text from the Bluetooth socket.
class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;
  final String deviceAddress;
  StreamSubscription? _incomingSub;

  ChatMessagesNotifier(this.ref, this.deviceAddress) : super([]) {
    _load();
    _listenIncoming();
  }

  void _load() {
    state = ref.read(storageServiceProvider).getMessagesForDevice(deviceAddress);
  }

  void _listenIncoming() {
    final bt = ref.read(bluetoothServiceProvider);
    _incomingSub = bt.incomingText.listen((incoming) {
      if (bt.connectedAddress != deviceAddress) return;
      final msg = ChatMessage(
        id: _uuid.v4(),
        deviceAddress: deviceAddress,
        text: incoming.text,
        isMine: false,
        timestamp: DateTime.now(),
        type: MessageType.text,
        status: MessageStatus.delivered,
      );
      _addAndPersist(msg);
      _bumpDevicePreview(msg.text);
    });
  }

  Future<void> sendText(String text) async {
    if (text.trim().isEmpty) return;
    final msg = ChatMessage(
      id: _uuid.v4(),
      deviceAddress: deviceAddress,
      text: text.trim(),
      isMine: true,
      timestamp: DateTime.now(),
      type: MessageType.text,
      status: MessageStatus.sending,
    );
    _addAndPersist(msg);

    final bt = ref.read(bluetoothServiceProvider);
    final ok = await bt.sendText(text.trim());
    _updateStatus(msg.id, ok ? MessageStatus.sent : MessageStatus.failed);
    _bumpDevicePreview(text.trim());
  }

  Future<void> retry(String messageId) async {
    final msg = state.firstWhere((m) => m.id == messageId);
    _updateStatus(messageId, MessageStatus.sending);
    final bt = ref.read(bluetoothServiceProvider);
    final ok = await bt.sendText(msg.text);
    _updateStatus(messageId, ok ? MessageStatus.sent : MessageStatus.failed);
  }

  void deleteMessage(String id) {
    ref.read(storageServiceProvider).deleteMessage(id);
    state = state.where((m) => m.id != id).toList();
  }

  void deleteMultiple(List<String> ids) {
    ref.read(storageServiceProvider).deleteMessages(ids);
    state = state.where((m) => !ids.contains(m.id)).toList();
  }

  void toggleStar(String id) {
    final storage = ref.read(storageServiceProvider);
    final idx = state.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final msg = state[idx];
    msg.isStarred = !msg.isStarred;
    storage.saveMessage(msg);
    state = [...state];
  }

  void clearConversation() {
    ref.read(storageServiceProvider).clearConversation(deviceAddress);
    state = [];
  }

  void _addAndPersist(ChatMessage msg) {
    ref.read(storageServiceProvider).saveMessage(msg);
    state = [...state, msg];
  }

  void _updateStatus(String id, MessageStatus status) {
    final idx = state.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    state[idx].status = status;
    ref.read(storageServiceProvider).saveMessage(state[idx]);
    state = [...state];
  }

  void _bumpDevicePreview(String preview) {
    final storage = ref.read(storageServiceProvider);
    final device = storage.getDevice(deviceAddress);
    if (device != null) {
      device.lastMessagePreview = preview;
      device.lastConnectedAt = DateTime.now();
      storage.upsertDevice(device);
    }
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    super.dispose();
  }
}

final chatMessagesProvider =
    StateNotifierProvider.family.autoDispose<ChatMessagesNotifier, List<ChatMessage>, String>(
  (ref, deviceAddress) => ChatMessagesNotifier(ref, deviceAddress),
);

final chatDeviceProvider = Provider.family<DeviceEntry?, String>((ref, address) {
  return ref.watch(storageServiceProvider).getDevice(address);
});
