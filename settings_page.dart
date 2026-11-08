import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_mesh_flutter/core/services/mesh_controller.dart';
import 'package:offline_mesh_flutter/core/theme/app_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meshControllerProvider);
    final profile = state.profile;
    final theme = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: kTeal,
              child: Text(
                '${profile?['username'] ?? '?'}'[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text('${profile?['username'] ?? ''}'),
            subtitle: Text('${profile?['bio'] ?? 'Hey there! I am using Offline Mesh'}'),
            trailing: const Icon(Icons.qr_code),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Tower relay mode'),
            subtitle: const Text('Forward other people\'s packets (uses battery)'),
            value: state.towerOn,
            activeColor: kTeal,
            onChanged: (v) => ref.read(meshControllerProvider.notifier).setTower(v),
          ),
          SwitchListTile(
            title: const Text('Dark mode'),
            value: theme == ThemeMode.dark,
            activeColor: kTeal,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const ListTile(
            title: Text('About'),
            subtitle: Text(
              'Offline mesh chat. No cloud servers. Range depends on Bluetooth/Wi‑Fi Direct and how many phones relay.',
            ),
          ),
        ],
      ),
    );
  }
}
