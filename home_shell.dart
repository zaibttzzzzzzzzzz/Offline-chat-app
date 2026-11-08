import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_mesh_flutter/core/theme/app_theme.dart';
import 'package:offline_mesh_flutter/features/calls/calls_tab.dart';
import 'package:offline_mesh_flutter/features/chats/chats_tab.dart';
import 'package:offline_mesh_flutter/features/nearby/nearby_tab.dart';
import 'package:offline_mesh_flutter/features/settings/settings_page.dart';
import 'package:offline_mesh_flutter/features/updates/updates_tab.dart';
import 'package:offline_mesh_flutter/features/group/create_group_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _titles = ['Mesh Chat', 'Updates', 'Nearby', 'Calls'];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ChatsTab(),
      const UpdatesTab(),
      const NearbyTab(),
      const CallsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'group') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateGroupPage()));
              } else if (v == 'theme') {
                await ref.read(themeModeProvider.notifier).toggle();
              } else if (v == 'settings') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'group', child: Text('New Group')),
              PopupMenuItem(value: 'channel', child: Text('New Channel')),
              PopupMenuItem(value: 'theme', child: Text('Dark / Light Mode')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.donut_large_outlined), selectedIcon: Icon(Icons.donut_large), label: 'Updates'),
          NavigationDestination(icon: Icon(Icons.radar_outlined), selectedIcon: Icon(Icons.radar), label: 'Nearby'),
          NavigationDestination(icon: Icon(Icons.call_outlined), selectedIcon: Icon(Icons.call), label: 'Calls'),
        ],
      ),
    );
  }
}
