/// Central place for every magic number / string used across the app.
/// Never hardcode these values inline in widgets or services.
class AppConstants {
  AppConstants._();

  static const String appName = 'Shakti Bluetooth Chat';

  // Hive box names
  static const String chatsBox = 'chats_box';
  static const String messagesBox = 'messages_box';
  static const String devicesBox = 'devices_box';
  static const String settingsBox = 'settings_box';

  // Settings keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyUseDynamicColor = 'use_dynamic_color';
  static const String keyUserDisplayName = 'user_display_name';
  static const String keyLastConnectedAddress = 'last_connected_address';

  // Bluetooth
  static const int reconnectDelaySeconds = 3;
  static const int maxReconnectAttempts = 5;
  static const int chunkSizeBytes = 4096; // used for chunked file transfer

  // Message protocol prefixes (so text vs file transfer can share one socket)
  static const String textPrefix = 'TXT::';
  static const String fileMetaPrefix = 'FILEMETA::';
  static const String fileChunkPrefix = 'FILECHUNK::';
  static const String fileEndPrefix = 'FILEEND::';

  // UI
  static const double radiusSmall = 10;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  static const Duration animFast = Duration(milliseconds: 180);
  static const Duration animMedium = Duration(milliseconds: 320);
  static const Duration animSlow = Duration(milliseconds: 500);
}
