import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    this.isSelected = false,
    this.onLongPress,
    this.onTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMine = message.isMine;

    final bubbleColor = isSelected
        ? scheme.primary.withValues(alpha: 0.25)
        : isMine
            ? scheme.primary
            : scheme.surfaceContainerHigh;
    final textColor = isMine ? scheme.onPrimary : scheme.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message.text, style: TextStyle(color: textColor, fontSize: 15.5, height: 1.3)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isStarred)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.star_rounded, size: 13, color: textColor.withValues(alpha: 0.8)),
                      ),
                    Text(
                      DateFormat('HH:mm').format(message.timestamp),
                      style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      _statusIcon(textColor),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 180.ms).slideY(begin: 0.15, end: 0, duration: 220.ms, curve: Curves.easeOut);
  }

  Widget _statusIcon(Color color) {
    switch (message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(strokeWidth: 1.6, color: color.withValues(alpha: 0.8)),
        );
      case MessageStatus.sent:
        return Icon(Icons.check_rounded, size: 14, color: color.withValues(alpha: 0.7));
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 14, color: color.withValues(alpha: 0.7));
      case MessageStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: Icon(Icons.error_outline_rounded, size: 14, color: Colors.redAccent.shade100),
        );
    }
  }
}
