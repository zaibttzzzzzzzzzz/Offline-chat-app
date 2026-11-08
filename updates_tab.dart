import 'package:flutter/material.dart';
import 'package:offline_mesh_flutter/core/theme/app_theme.dart';

class UpdatesTab extends StatelessWidget {
  const UpdatesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: Stack(
            children: [
              const CircleAvatar(radius: 28, backgroundColor: kTeal, child: Icon(Icons.person, color: Colors.white)),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          title: const Text('My status', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Tap to add status update'),
          onTap: () {
            showModalBottomSheet(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.public, color: kTeal),
                      title: const Text('Global mesh status'),
                      subtitle: const Text('Epidemic flood to reachable nodes (TTL-limited)'),
                      onTap: () => Navigator.pop(ctx),
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_outline, color: kTeal),
                      title: const Text('Private friends status'),
                      subtitle: const Text('Only selected accepted friends'),
                      onTap: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Channels', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        ListTile(
          leading: const CircleAvatar(backgroundColor: kAccent, child: Icon(Icons.campaign, color: Colors.white)),
          title: const Text('Create channel'),
          subtitle: const Text('One-way signed broadcast'),
          onTap: () {},
        ),
      ],
    );
  }
}
