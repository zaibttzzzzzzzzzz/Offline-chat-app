import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_mesh_flutter/core/services/mesh_controller.dart';
import 'package:offline_mesh_flutter/core/theme/app_theme.dart';

class NearbyTab extends ConsumerStatefulWidget {
  const NearbyTab({super.key});

  @override
  ConsumerState<NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends ConsumerState<NearbyTab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(meshControllerProvider);
    final q = _search.text.trim().toLowerCase();
    final discovered = state.discovered.where((e) {
      if (q.isEmpty) return true;
      return '${e['username']}'.toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          height: 160,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              return CustomPaint(
                painter: _RadarPainter(progress: _pulse.value),
                child: const Center(
                  child: Icon(Icons.phone_android, size: 40, color: kTeal),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search mesh by username',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Incoming requests', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        if (state.pending.isEmpty)
          Text('No requests', style: TextStyle(color: Colors.grey.shade600))
        else
          ...state.pending.map((p) {
            return Card(
              child: ListTile(
                title: Text('${p['username']}'),
                subtitle: const Text('Wants to connect'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: kTeal),
                      onPressed: () => ref.read(meshControllerProvider.notifier).acceptRequest('${p['user_id']}'),
                      child: const Text('Accept'),
                    ),
                    OutlinedButton(onPressed: () {}, child: const Text('Reject')),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 20),
        const Text('Discovered peers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        if (discovered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const Text('No one nearby', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Both phones need the app open + Bluetooth on', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          )
        else
          ...discovered.map((d) {
            final hops = d['hops'] as int? ?? 0;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: kAccent,
                  child: Text('${d['username']}'.isNotEmpty ? '${d['username']}'[0].toUpperCase() : '?'),
                ),
                title: Text('${d['username']}'),
                subtitle: Text(hops == 0 ? 'Direct • nearby' : '$hops towers away'),
                trailing: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kTeal),
                  onPressed: () => ref.read(meshControllerProvider.notifier).sendRequest('${d['user_id']}'),
                  child: const Text('Send Request'),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kTeal.withValues(alpha: 1 - progress);
    for (var i = 1; i <= 3; i++) {
      final r = (size.shortestSide / 2) * (i / 3) * (0.4 + progress * 0.6);
      canvas.drawCircle(c, r, paint);
    }
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = kAccent.withValues(alpha: 0.5);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: size.shortestSide * 0.35),
      -math.pi / 2,
      progress * math.pi * 2,
      false,
      wave,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.progress != progress;
}
