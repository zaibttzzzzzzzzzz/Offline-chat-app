# Offline Mesh Flutter (WhatsApp-style, 100% offline)

Decentralized chat + calls over **Google Nearby Connections** (BLE + Wi-Fi Direct), multi-hop **Tower relay**, local **SQLite**, and **serverless WebRTC** (`iceServers: []`).

## Honest range note

Bluetooth / Wi-Fi Direct is **meters to ~100m per hop**, not hundreds of km. Multi-hop only helps when other phones running this app act as relays between you and the target. Density of “towers” (users) decides real coverage.

## Build APK (PC / laptop — recommended)

```bash
# 1) Install Flutter SDK: https://docs.flutter.dev/get-started/install
flutter doctor

# 2) Open project
cd offline_mesh_flutter
flutter pub get

# 3) Release APK
flutter build apk --release
```

APK path:

`build/app/outputs/flutter-apk/app-release.apk`

Copy that file to the phone and install (Allow unknown sources).

## Build from phone?

**Normal Android phones cannot compile Flutter → APK** (no full Android SDK + NDK toolchain). Options:

1. **PC / friend’s laptop** with Flutter (best).
2. **GitHub Actions** — push this repo, download APK artifact from CI.
3. Cloud IDEs (Gitpod, CodeMagic) with Flutter image.

Do **not** expect a random “ZIP to APK” app on Play Store to produce a safe, signed release of this project.

## First run on two phones

1. Install APK on both devices.  
2. Grant Bluetooth, Location, Nearby devices, Microphone, Camera.  
3. Finish onboarding (username + optional DP).  
4. Open **Nearby** on both → Send Request → Accept.  
5. Chat appears under **Chats**. Try voice note / call on same Wi-Fi if media fails on pure BT.

## Architecture

| Layer | Role |
|--------|------|
| `MeshRouterEngine` | TTL, dedupe, multi-hop forward |
| `NearbyHybridService` | P2P_CLUSTER discovery + payloads |
| `ServerlessWebRTCManager` | SDP/ICE over mesh, no STUN/TURN |
| `DatabaseHelper` | friends, messages, groups, status, channels |
| UI | WhatsApp-like tabs: Chats, Updates, Nearby, Calls |
