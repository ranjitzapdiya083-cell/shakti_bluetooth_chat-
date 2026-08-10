import 'package:hive/hive.dart';

part 'device_entry.g.dart';

/// A Bluetooth device the user has paired with, connected to, or favorited.
/// Persisted so "Paired Devices" / "Recent Chats" / "Trusted Devices" survive restarts.
@HiveType(typeId: 0)
class DeviceEntry extends HiveObject {
  @HiveField(0)
  String address;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? nickname;

  @HiveField(3)
  bool isFavorite;

  @HiveField(4)
  bool isTrusted;

  @HiveField(5)
  DateTime? lastConnectedAt;

  @HiveField(6)
  String? lastMessagePreview;

  @HiveField(7)
  int unreadCount;

  DeviceEntry({
    required this.address,
    required this.name,
    this.nickname,
    this.isFavorite = false,
    this.isTrusted = false,
    this.lastConnectedAt,
    this.lastMessagePreview,
    this.unreadCount = 0,
  });

  String get displayName => (nickname != null && nickname!.trim().isNotEmpty) ? nickname! : name;
}
