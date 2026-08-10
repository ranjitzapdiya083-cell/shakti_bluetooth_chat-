import 'package:hive/hive.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 1)
enum MessageType {
  @HiveField(0)
  text,
  @HiveField(1)
  file,
  @HiveField(2)
  system,
}

@HiveType(typeId: 2)
enum MessageStatus {
  @HiveField(0)
  sending,
  @HiveField(1)
  sent,
  @HiveField(2)
  delivered,
  @HiveField(3)
  failed,
}

@HiveType(typeId: 3)
class ChatMessage extends HiveObject {
  @HiveField(0)
  String id;

  /// The remote device's mac address — used as the "conversation id".
  @HiveField(1)
  String deviceAddress;

  @HiveField(2)
  String text;

  @HiveField(3)
  bool isMine;

  @HiveField(4)
  DateTime timestamp;

  @HiveField(5)
  MessageType type;

  @HiveField(6)
  MessageStatus status;

  @HiveField(7)
  String? filePath;

  @HiveField(8)
  String? fileName;

  @HiveField(9)
  int? fileSizeBytes;

  @HiveField(10)
  bool isStarred;

  @HiveField(11)
  String? replyToMessageId;

  ChatMessage({
    required this.id,
    required this.deviceAddress,
    required this.text,
    required this.isMine,
    required this.timestamp,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    this.filePath,
    this.fileName,
    this.fileSizeBytes,
    this.isStarred = false,
    this.replyToMessageId,
  });
}
