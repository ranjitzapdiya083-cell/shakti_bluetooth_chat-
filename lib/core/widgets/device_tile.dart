import 'package:flutter/material.dart';

class DeviceTile extends StatelessWidget {
  final String name;
  final String address;
  final String? subtitle;
  final bool isConnected;
  final bool isPaired;
  final int unreadCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const DeviceTile({
    super.key,
    required this.name,
    required this.address,
    this.subtitle,
    this.isConnected = false,
    this.isPaired = false,
    this.unreadCount = 0,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase(),
              style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
          if (isConnected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: const Color(0xFF1FAE5B),
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
      subtitle: Text(
        subtitle ?? address,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
      ),
      trailing: trailing ??
          (unreadCount > 0
              ? CircleAvatar(
                  radius: 11,
                  backgroundColor: scheme.primary,
                  child: Text('$unreadCount', style: TextStyle(fontSize: 11, color: scheme.onPrimary, fontWeight: FontWeight.w700)),
                )
              : (isPaired ? Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant) : null)),
    );
  }
}
