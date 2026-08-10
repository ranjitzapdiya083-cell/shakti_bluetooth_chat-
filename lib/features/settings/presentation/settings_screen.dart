import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart' show PackageInfo;

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final useDynamicColor = ref.watch(useDynamicColorProvider);
    final storage = ref.watch(storageServiceProvider);
    final displayName = storage.getSetting<String>(AppConstants.keyUserDisplayName, defaultValue: 'Me');

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Profile'),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
            title: Text(displayName ?? 'Me'),
            subtitle: const Text('Display name shown to devices you chat with'),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: () => _editDisplayName(context, ref, displayName ?? 'Me'),
          ),
          const Divider(),
          const _SectionHeader('Appearance'),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (v) => ref.read(themeModeProvider.notifier).setMode(v!),
            child: Column(
              children: const [
                RadioListTile<ThemeMode>(title: Text('Light'), value: ThemeMode.light),
                RadioListTile<ThemeMode>(title: Text('Dark'), value: ThemeMode.dark),
                RadioListTile<ThemeMode>(title: Text('System default'), value: ThemeMode.system),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Material You dynamic color'),
            subtitle: const Text('Match your wallpaper theme (Android 12+)'),
            value: useDynamicColor,
            onChanged: (v) => ref.read(useDynamicColorProvider.notifier).toggle(v),
          ),
          const Divider(),
          const _SectionHeader('Notifications'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notification settings'),
            subtitle: const Text('New messages, file transfers, connection alerts'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
          const Divider(),
          const _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About Shakti Bluetooth Chat'),
            onTap: () => _showAbout(context),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privacy policy'),
          ),
          const ListTile(
            leading: Icon(Icons.description_outlined),
            title: Text('Terms of service'),
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '1.0.0';
              return ListTile(
                leading: const Icon(Icons.tag_rounded),
                title: const Text('App version'),
                trailing: Text(version),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _editDisplayName(BuildContext context, WidgetRef ref, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(storageServiceProvider).setSetting(AppConstants.keyUserDisplayName, controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 Shakti. Chat offline over Bluetooth — no internet, no servers.',
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
