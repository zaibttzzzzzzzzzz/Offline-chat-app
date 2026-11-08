import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_mesh_flutter/core/services/mesh_controller.dart';
import 'package:offline_mesh_flutter/core/theme/app_theme.dart';
import 'package:offline_mesh_flutter/features/chats/chat_room_page.dart';

class ChatsTab extends ConsumerWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(meshControllerProvider).friends;

    if (friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline, size: 72, color: kTeal.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              const Text('No chats yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Accept friends from the Nearby tab',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: friends.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final f = friends[i];
        final name = '${f['username'] ?? 'Friend'}';
        final hops = f['hops'] as int? ?? 0;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: kTeal,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(hops == 0 ? 'Direct' : '$hops towers away'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatRoomPage(
                  peerId: '${f['user_id']}',
                  peerName: name,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
