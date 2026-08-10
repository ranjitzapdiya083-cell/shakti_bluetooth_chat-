import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';
import '../models/chat_message.dart';
import '../models/device_entry.dart';

/// Thin, testable wrapper around Hive so the rest of the app never
/// touches `Hive.box(...)` directly (keeps persistence swappable).
class StorageService {
  late Box<DeviceEntry> _devicesBox;
  late Box<ChatMessage> _messagesBox;
  late Box _settingsBox;

  static Future<StorageService> init() async {
    await Hive.initFlutter();

    Hive.registerAdapter(DeviceEntryAdapter());
    Hive.registerAdapter(MessageTypeAdapter());
    Hive.registerAdapter(MessageStatusAdapter());
    Hive.registerAdapter(ChatMessageAdapter());

    final service = StorageService();
    service._devicesBox = await Hive.openBox<DeviceEntry>(AppConstants.devicesBox);
    service._messagesBox = await Hive.openBox<ChatMessage>(AppConstants.messagesBox);
    service._settingsBox = await Hive.openBox(AppConstants.settingsBox);
    return service;
  }

  // ---------------- Devices ----------------

  List<DeviceEntry> getAllDevices() => _devicesBox.values.toList();

  DeviceEntry? getDevice(String address) {
    try {
      return _devicesBox.values.firstWhere((d) => d.address == address);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertDevice(DeviceEntry entry) async {
    final existingKey = _devicesBox.keys.firstWhere(
      (k) => _devicesBox.get(k)?.address == entry.address,
      orElse: () => null,
    );
    if (existingKey != null) {
      await _devicesBox.put(existingKey, entry);
    } else {
      await _devicesBox.add(entry);
    }
  }

  Future<void> deleteDevice(String address) async {
    final key = _devicesBox.keys.firstWhere(
      (k) => _devicesBox.get(k)?.address == address,
      orElse: () => null,
    );
    if (key != null) await _devicesBox.delete(key);
  }

  Stream<void> watchDevices() => _devicesBox.watch().map((_) {});

  // ---------------- Messages ----------------

  List<ChatMessage> getMessagesForDevice(String address) {
    final list = _messagesBox.values.where((m) => m.deviceAddress == address).toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  List<ChatMessage> searchMessages(String query, {String? deviceAddress}) {
    final q = query.toLowerCase();
    return _messagesBox.values
        .where((m) =>
            (deviceAddress == null || m.deviceAddress == deviceAddress) &&
            m.text.toLowerCase().contains(q))
        .toList();
  }

  Future<void> saveMessage(ChatMessage message) async {
    await _messagesBox.put(message.id, message);
  }

  Future<void> deleteMessage(String id) async {
    await _messagesBox.delete(id);
  }

  Future<void> deleteMessages(List<String> ids) async {
    await _messagesBox.deleteAll(ids);
  }

  Future<void> clearConversation(String address) async {
    final ids = _messagesBox.values.where((m) => m.deviceAddress == address).map((m) => m.id).toList();
    await _messagesBox.deleteAll(ids);
  }

  Stream<void> watchMessages() => _messagesBox.watch().map((_) {});

  // ---------------- Settings ----------------

  T? getSetting<T>(String key, {T? defaultValue}) =>
      _settingsBox.get(key, defaultValue: defaultValue) as T?;

  Future<void> setSetting<T>(String key, T value) => _settingsBox.put(key, value);
}
