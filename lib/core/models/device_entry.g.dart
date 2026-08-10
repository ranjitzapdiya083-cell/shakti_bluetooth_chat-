// GENERATED CODE - hand-written equivalent of build_runner output.
// If you ever run `dart run build_runner build`, this file will be
// regenerated automatically and can safely be overwritten.

part of 'device_entry.dart';

class DeviceEntryAdapter extends TypeAdapter<DeviceEntry> {
  @override
  final int typeId = 0;

  @override
  DeviceEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeviceEntry(
      address: fields[0] as String,
      name: fields[1] as String,
      nickname: fields[2] as String?,
      isFavorite: fields[3] as bool? ?? false,
      isTrusted: fields[4] as bool? ?? false,
      lastConnectedAt: fields[5] as DateTime?,
      lastMessagePreview: fields[6] as String?,
      unreadCount: fields[7] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, DeviceEntry obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.address)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.nickname)
      ..writeByte(3)
      ..write(obj.isFavorite)
      ..writeByte(4)
      ..write(obj.isTrusted)
      ..writeByte(5)
      ..write(obj.lastConnectedAt)
      ..writeByte(6)
      ..write(obj.lastMessagePreview)
      ..writeByte(7)
      ..write(obj.unreadCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceEntryAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
