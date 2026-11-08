import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

/// Serverless WebRTC: iceServers must stay empty (no public STUN/TURN).
/// Signaling rides the mesh; media needs a local IP path (same Wi‑Fi / Wi‑Fi Direct).
class ServerlessWebRTCManager {
  ServerlessWebRTCManager({required this.sendSignal});

  final Future<void> Function(Map<String, dynamic> signal) sendSignal;

  RTCPeerConnection? _pc;
  MediaStream? _local;
  final _uuid = const Uuid();
  String? callId;
  bool withVideo = false;

  final remoteRenderer = RTCVideoRenderer();
  final localRenderer = RTCVideoRenderer();

  Future<void> initRenderers() async {
    await remoteRenderer.initialize();
    await localRenderer.initialize();
  }

  Future<void> dispose() async {
    await hangup(notify: false);
    await remoteRenderer.dispose();
    await localRenderer.dispose();
  }

  Map<String, dynamic> get _config => {
        'iceServers': <Map<String, dynamic>>[], // offline: no STUN/TURN
        'sdpSemantics': 'unified-plan',
      };

  Future<void> _ensurePc() async {
    if (_pc != null) return;
    _pc = await createPeerConnection(_config);
    _pc!.onIceCandidate = (c) {
      if (c.candidate == null) return;
      unawaited(sendSignal({
        'kind': 'ice',
        'callId': callId,
        'candidate': c.toMap(),
      }));
    };
    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
      }
    };
  }

  Future<MediaStream> _getMedia(bool video) async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video
          ? {
              'facingMode': 'user',
              'width': 640,
              'height': 360,
              'frameRate': 20,
            }
          : false,
    });
    // Soft bitrate target for intermediate relays / weak links.
    return stream;
  }

  Future<void> startCall({required bool video}) async {
    withVideo = video;
    callId = _uuid.v4();
    await _ensurePc();
    _local = await _getMedia(video);
    localRenderer.srcObject = _local;
    for (final track in _local!.getTracks()) {
      await _pc!.addTrack(track, _local!);
    }
    await sendSignal({
      'kind': 'ring',
      'callId': callId,
      'withVideo': video,
    });
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': video ? 1 : 0,
    });
    await _pc!.setLocalDescription(offer);
    await sendSignal({
      'kind': 'offer',
      'callId': callId,
      'withVideo': video,
      'sdp': offer.toMap(),
    });
  }

  Future<void> acceptCall({
    required String remoteCallId,
    required bool video,
    required Map<String, dynamic> offerSdp,
  }) async {
    withVideo = video;
    callId = remoteCallId;
    await _ensurePc();
    _local = await _getMedia(video);
    localRenderer.srcObject = _local;
    for (final track in _local!.getTracks()) {
      await _pc!.addTrack(track, _local!);
    }
    await _pc!.setRemoteDescription(
      RTCSessionDescription(offerSdp['sdp'] as String, offerSdp['type'] as String),
    );
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    await sendSignal({
      'kind': 'answer',
      'callId': callId,
      'sdp': answer.toMap(),
    });
  }

  Future<void> handleSignal(Map<String, dynamic> signal) async {
    final kind = signal['kind'] as String?;
    if (kind == null) return;
    if (kind == 'answer' && _pc != null) {
      final sdp = signal['sdp'] as Map<String, dynamic>;
      await _pc!.setRemoteDescription(
        RTCSessionDescription(sdp['sdp'] as String, sdp['type'] as String),
      );
    } else if (kind == 'ice' && _pc != null) {
      final c = signal['candidate'] as Map<String, dynamic>?;
      if (c != null) {
        await _pc!.addCandidate(RTCIceCandidate(
          c['candidate'] as String?,
          c['sdpMid'] as String?,
          c['sdpMLineIndex'] as int?,
        ));
      }
    } else if (kind == 'hangup') {
      await hangup(notify: false);
    }
  }

  Future<void> setMuted(bool muted) async {
    _local?.getAudioTracks().forEach((t) => t.enabled = !muted);
  }

  Future<void> switchCamera() async {
    final v = _local?.getVideoTracks();
    if (v == null || v.isEmpty) return;
    await Helper.switchCamera(v.first);
  }

  Future<void> hangup({bool notify = true}) async {
    if (notify && callId != null) {
      await sendSignal({'kind': 'hangup', 'callId': callId});
    }
    await _local?.dispose();
    _local = null;
    await _pc?.close();
    _pc = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    callId = null;
  }
}
