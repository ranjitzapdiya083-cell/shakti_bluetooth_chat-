import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/services/bluetooth_service.dart';
import '../../../core/widgets/empty_state.dart';
import '../../bluetooth/providers/bluetooth_providers.dart';
import '../providers/chat_providers.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/date_separator.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String deviceAddress;
  const ChatScreen({super.key, required this.deviceAddress});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  final Set<String> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(target, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(chatDeviceProvider(widget.deviceAddress));
    final messages = ref.watch(chatMessagesProvider(widget.deviceAddress));
    final connState = ref.watch(connectionStateProvider);
    final scheme = Theme.of(context).colorScheme;

    ref.listen(chatMessagesProvider(widget.deviceAddress), (prev, next) {
      if (next.length > (prev?.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _isSelecting
            ? Text('${_selectedIds.length} selected')
            : Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      _initial(device?.displayName ?? '?'),
                      style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(device?.displayName ?? 'Unknown device',
                            overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        connState.when(
                          data: (s) => Text(
                            _connectionLabel(s),
                            style: TextStyle(fontSize: 12, color: _connectionColor(s, scheme)),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: _isSelecting
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () {
                    ref.read(chatMessagesProvider(widget.deviceAddress).notifier).deleteMultiple(_selectedIds.toList());
                    setState(() => _selectedIds.clear());
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _selectedIds.clear()),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => _showSearchSheet(context, messages),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'clear') {
                      _confirmClear(context);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'clear', child: Text('Clear conversation')),
                  ],
                ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No messages yet',
                    message: 'Say hi! Messages send instantly over Bluetooth — no internet needed.',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final showDate = index == 0 || !_isSameDay(messages[index - 1].timestamp, msg.timestamp);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDate) DateSeparator(date: msg.timestamp),
                          MessageBubble(
                            message: msg,
                            isSelected: _selectedIds.contains(msg.id),
                            onTap: _isSelecting ? () => _toggleSelect(msg.id) : null,
                            onLongPress: () => _isSelecting ? _toggleSelect(msg.id) : _showMessageMenu(context, msg),
                            onRetry: () => ref.read(chatMessagesProvider(widget.deviceAddress).notifier).retry(msg.id),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          ChatInputBar(
            onSend: (text) => ref.read(chatMessagesProvider(widget.deviceAddress).notifier).sendText(text),
            onAttachFile: () => _showComingSoonFileSheet(context),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _initial(String name) => name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  String _connectionLabel(BtConnectionState s) {
    switch (s) {
      case BtConnectionState.connected:
        return 'Connected';
      case BtConnectionState.connecting:
        return 'Connecting…';
      case BtConnectionState.reconnecting:
        return 'Reconnecting…';
      case BtConnectionState.disconnected:
        return 'Offline';
    }
  }

  Color _connectionColor(BtConnectionState s, ColorScheme scheme) {
    switch (s) {
      case BtConnectionState.connected:
        return const Color(0xFF1FAE5B);
      case BtConnectionState.connecting:
      case BtConnectionState.reconnecting:
        return const Color(0xFFE0A72E);
      case BtConnectionState.disconnected:
        return scheme.onSurfaceVariant;
    }
  }

  void _showMessageMenu(BuildContext context, ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: Icon(msg.isStarred ? Icons.star_rounded : Icons.star_border_rounded),
              title: Text(msg.isStarred ? 'Unstar' : 'Star'),
              onTap: () {
                ref.read(chatMessagesProvider(widget.deviceAddress).notifier).toggleStar(msg.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(chatMessagesProvider(widget.deviceAddress).notifier).deleteMessage(msg.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchSheet(BuildContext context, List<ChatMessage> messages) {
    showSearch(context: context, delegate: _MessageSearchDelegate(messages));
  }

  void _showComingSoonFileSheet(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pick a file to send — opens the file picker.')),
    );
    // Actual picker wiring lives in files feature; hook up FilePicker.platform.pickFiles()
    // and AppBluetoothService.sendFile() stream here once the Files screen ships.
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('This deletes all messages in this chat from this device. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(chatMessagesProvider(widget.deviceAddress).notifier).clearConversation();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _MessageSearchDelegate extends SearchDelegate<void> {
  final List<ChatMessage> messages;
  _MessageSearchDelegate(this.messages);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final results = messages.where((m) => m.text.toLowerCase().contains(query.toLowerCase())).toList();
    if (query.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) => ListTile(
        title: Text(results[i].text),
        subtitle: Text(results[i].timestamp.toString()),
      ),
    );
  }
}
