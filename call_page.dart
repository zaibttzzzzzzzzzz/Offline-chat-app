import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:offline_mesh_flutter/core/services/mesh_controller.dart';
import 'package:offline_mesh_flutter/core/theme/app_theme.dart';

class CallPage extends ConsumerStatefulWidget {
  const CallPage({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.video,
  });

  final String peerId;
  final String peerName;
  final bool video;

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  bool muted = false;
  bool speaker = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final rtc = ref.read(meshControllerProvider.notifier).webrtc;
      if (rtc == null) return;
      // Attach target id into signal path by wrapping sendSignal is left to mesh layer.
      await rtc.startCall(video: widget.video);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final rtc = ref.read(meshControllerProvider.notifier).webrtc;

    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(widget.peerName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(widget.video ? 'Video call' : 'Voice call', style: const TextStyle(color: Colors.white70)),
            Expanded(
              child: widget.video && rtc != null
                  ? Stack(
                      children: [
                        Positioned.fill(child: RTCVideoView(rtc.remoteRenderer)),
                        Positioned(
                          right: 16,
                          bottom: 16,
                          width: 110,
                          height: 160,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: RTCVideoView(rtc.localRenderer, mirror: true),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: kTeal,
                        child: Text(
                          widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 40, color: Colors.white),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _roundBtn(
                    icon: muted ? Icons.mic_off : Icons.mic,
                    onTap: () async {
                      setState(() => muted = !muted);
                      await rtc?.setMuted(muted);
                    },
                  ),
                  _roundBtn(
                    icon: Icons.call_end,
                    color: Colors.red,
                    size: 72,
                    onTap: () async {
                      await rtc?.hangup();
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                  _roundBtn(
                    icon: widget.video ? Icons.cameraswitch : Icons.volume_up,
                    onTap: () async {
                      if (widget.video) await rtc?.switchCamera();
                      else setState(() => speaker = !speaker);
                    },
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 16, left: 24, right: 24),
              child: Text(
                'Media needs a local Wi‑Fi / Wi‑Fi Direct path. Signaling uses the mesh.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn({required IconData icon, required VoidCallback onTap, Color color = Colors.white24, double size = 56}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
