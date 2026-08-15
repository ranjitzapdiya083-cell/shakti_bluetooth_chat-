import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';

enum BtConnectionState { disconnected, connecting, connected, reconnecting }

/// Wraps `flutter_bluetooth_serial` and exposes a clean, app-friendly API:
/// adapter state, discovery, pairing, RFCOMM connect, and a simple
/// line-based protocol for text + chunked file transfer over one socket.
class AppBluetoothService {
  AppBluetoothService._internal();
  static final AppBluetoothService instance = AppBluetoothService._internal();

  final _logger = Logger();
  final FlutterBluetoothSerial _serial = FlutterBluetoothSerial.instance;

  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _dataSub;
  String? _connectedAddress;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  final _connectionStateController = StreamController<BtConnectionState>.broadcast();
  final _incomingTextController = StreamController<IncomingText>.broadcast();
  final _incomingFileController = StreamController<IncomingFile>.broadcast();
  final _adapterStateController = StreamController<BluetoothState>.broadcast();

  Stream<BtConnectionState> get connectionState => _connectionStateController.stream;
  Stream<IncomingText> get incomingText => _incomingTextController.stream;
  Stream<IncomingFile> get incomingFile => _incomingFileController.stream;
  Stream<BluetoothState> get adapterState => _adapterStateController.stream;

  String? get connectedAddress => _connectedAddress;
  bool get isConnected => _connection?.isConnected ?? false;

  /// Message from the most recent failed connect() call, for surfacing to
  /// the user / logs instead of failing silently.
  String? lastConnectError;

  final StringBuffer _rxBuffer = StringBuffer();
  FileReceiveSession? _activeFileSession;

  Future<void> initAdapterListener() async {
    _serial.onStateChanged().listen((state) {
      _adapterStateController.add(state);
    });
  }

  Future<bool> isBluetoothSupported() async {
    // flutter_bluetooth_serial has no direct "isSupported" — we infer from
    // being able to read adapter state without throwing.
    try {
      await _serial.state;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async => await _serial.isEnabled ?? false;

  Future<bool> requestEnable() async {
    final enabled = await _serial.requestEnable();
    return enabled ?? false;
  }

  Future<void> disableBluetooth() async {
    await _serial.requestDisable();
  }

  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await _serial.getBondedDevices();
  }

  /// Starts a classic discovery scan. Caller is responsible for cancelling
  /// the subscription when done (e.g. dispose or stop-scan action).
  Stream<BluetoothDiscoveryResult> startDiscovery() {
    return _serial.startDiscovery();
  }

  Future<void> cancelDiscovery() async {
    await _serial.cancelDiscovery();
  }

  Future<bool> pairDevice(String address) async {
    try {
      final bonded = await _serial.bondDeviceAtAddress(address);
      return bonded ?? false;
    } catch (e) {
      _logger.e('Pair failed: $e');
      return false;
    }
  }

  Future<bool> unpairDevice(String address) async {
    try {
      final removed = await _serial.removeDeviceBondWithAddress(address);
      return removed ?? false;
    } catch (e) {
      _logger.e('Unpair failed: $e');
      return false;
    }
  }

  /// Connects (RFCOMM) to [address]. On unexpected drop, auto-reconnects
  /// up to [AppConstants.maxReconnectAttempts] with a short backoff.
  Future<bool> connect(String address, {bool isReconnectAttempt = false}) async {
    try {
      _connectionStateController.add(isReconnectAttempt ? BtConnectionState.reconnecting : BtConnectionState.connecting);
      lastConnectError = null;

      // Discovery left running (e.g. user just scanned the Nearby tab) makes
      // BluetoothConnection.toAddress() fail on many devices — most commonly
      // reported on Android 13 — with "read failed, socket might closed or
      // timeout, read ret: -1". Always stop it first and give the radio a
      // brief moment to settle before opening the RFCOMM socket.
      try {
        await _serial.cancelDiscovery();
      } catch (_) {
        // Ignore — discovery may not have been running.
      }
      await Future.delayed(const Duration(milliseconds: 300));

      final conn = await BluetoothConnection.toAddress(address);
      _connection = conn;
      _connectedAddress = address;
      _reconnectAttempts = 0;
      _connectionStateController.add(BtConnectionState.connected);

      _dataSub = conn.input?.listen(
        _onDataReceived,
        onDone: () => _handleDisconnect(address),
        onError: (_) => _handleDisconnect(address),
      );
      return true;
    } catch (e) {
      _logger.e('Connect failed: $e');
      lastConnectError = e.toString();
      _connectionStateController.add(BtConnectionState.disconnected);
      return false;
    }
  }

  void _handleDisconnect(String address) {
    _connectionStateController.add(BtConnectionState.disconnected);
    _dataSub?.cancel();
    _connection = null;

    if (_reconnectAttempts < AppConstants.maxReconnectAttempts) {
      _reconnectAttempts++;
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: AppConstants.reconnectDelaySeconds), () {
        connect(address, isReconnectAttempt: true);
      });
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = AppConstants.maxReconnectAttempts; // stop auto reconnect
    await _dataSub?.cancel();
    await _connection?.finish();
    _connection = null;
    _connectedAddress = null;
    _connectionStateController.add(BtConnectionState.disconnected);
  }

  // ---------------- Sending ----------------

  Future<bool> sendText(String text) async {
    if (_connection == null || !_connection!.isConnected) return false;
    final payload = '${AppConstants.textPrefix}$text\n';
    _connection!.output.add(Uint8List.fromList(utf8.encode(payload)));
    await _connection!.output.allSent;
    return true;
  }

  /// Sends a file in [AppConstants.chunkSizeBytes] base64 chunks so the
  /// single RFCOMM socket can interleave text + file protocol lines safely.
  Stream<double> sendFile({
    required String fileName,
    required int fileSizeBytes,
    required Stream<List<int>> byteStream,
  }) async* {
    if (_connection == null || !_connection!.isConnected) {
      throw StateError('Not connected');
    }
    final meta = jsonEncode({'name': fileName, 'size': fileSizeBytes});
    _connection!.output.add(Uint8List.fromList(utf8.encode('${AppConstants.fileMetaPrefix}$meta\n')));
    await _connection!.output.allSent;

    int sent = 0;
    final buffer = <int>[];
    await for (final chunk in byteStream) {
      buffer.addAll(chunk);
      while (buffer.length >= AppConstants.chunkSizeBytes) {
        final piece = buffer.sublist(0, AppConstants.chunkSizeBytes);
        buffer.removeRange(0, AppConstants.chunkSizeBytes);
        _sendChunk(piece);
        sent += piece.length;
        yield sent / fileSizeBytes;
      }
    }
    if (buffer.isNotEmpty) {
      _sendChunk(buffer);
      sent += buffer.length;
      yield sent / fileSizeBytes;
    }
    _connection!.output.add(Uint8List.fromList(utf8.encode('${AppConstants.fileEndPrefix}done\n')));
    await _connection!.output.allSent;
    yield 1.0;
  }

  void _sendChunk(List<int> bytes) {
    final b64 = base64Encode(bytes);
    _connection!.output.add(Uint8List.fromList(utf8.encode('${AppConstants.fileChunkPrefix}$b64\n')));
  }

  // ---------------- Receiving ----------------

  void _onDataReceived(Uint8List data) {
    _rxBuffer.write(utf8.decode(data, allowMalformed: true));
    final content = _rxBuffer.toString();
    final lines = content.split('\n');
    // Keep the last (possibly incomplete) segment in the buffer.
    _rxBuffer
      ..clear()
      ..write(lines.removeLast());

    for (final line in lines) {
      if (line.isEmpty) continue;
      _processLine(line);
    }
  }

  void _processLine(String line) {
    if (line.startsWith(AppConstants.textPrefix)) {
      final text = line.substring(AppConstants.textPrefix.length);
      _incomingTextController.add(IncomingText(text: text, fromAddress: _connectedAddress ?? ''));
    } else if (line.startsWith(AppConstants.fileMetaPrefix)) {
      final jsonStr = line.substring(AppConstants.fileMetaPrefix.length);
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        _activeFileSession = FileReceiveSession(
          fileName: map['name'] as String,
          totalBytes: map['size'] as int,
        );
      } catch (e) {
        _logger.e('Bad file meta: $e');
      }
    } else if (line.startsWith(AppConstants.fileChunkPrefix)) {
      final b64 = line.substring(AppConstants.fileChunkPrefix.length);
      try {
        final bytes = base64Decode(b64);
        _activeFileSession?.chunks.add(bytes);
        _activeFileSession?.receivedBytes += bytes.length;
      } catch (e) {
        _logger.e('Bad chunk: $e');
      }
    } else if (line.startsWith(AppConstants.fileEndPrefix)) {
      final session = _activeFileSession;
      if (session != null) {
        final allBytes = session.chunks.expand((e) => e).toList();
        _incomingFileController.add(IncomingFile(
          fileName: session.fileName,
          bytes: Uint8List.fromList(allBytes),
          fromAddress: _connectedAddress ?? '',
        ));
      }
      _activeFileSession = null;
    }
  }

  void dispose() {
    _dataSub?.cancel();
    _reconnectTimer?.cancel();
    _connectionStateController.close();
    _incomingTextController.close();
    _incomingFileController.close();
    _adapterStateController.close();
  }
}

class IncomingText {
  final String text;
  final String fromAddress;
  IncomingText({required this.text, required this.fromAddress});
}

class IncomingFile {
  final String fileName;
  final Uint8List bytes;
  final String fromAddress;
  IncomingFile({required this.fileName, required this.bytes, required this.fromAddress});
}

class FileReceiveSession {
  final String fileName;
  final int totalBytes;
  int receivedBytes = 0;
  final List<Uint8List> chunks = [];
  FileReceiveSession({required this.fileName, required this.totalBytes});
}
