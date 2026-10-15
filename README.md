# Reticulum Mobile

A lightweight Android chat client for [Reticulum](https://reticulum.network/) / LXMF mesh messaging, built with Flutter. It is a **thin client** for a self-hosted [reticulum-hub](https://github.com/Blackshield-Company/reticulum-hub): the hub runs the RNS/LXMF node, and the phone talks to it over HTTP + WebSocket (e.g. over Tailscale/VPN). For a full on-device Reticulum node, see [Sideband](https://github.com/markqvist/Sideband).

## Features (MVP)

- **Pair screen**: hub URL + API token, reachability check, or **demo mode** with no hub
- **Conversation list** with last message, unread badge, pull to refresh
- **Chat view** with send and delivery status (○ pending, ✓ delivered, ✓✓ read)
- **Live updates** over Action Cable (`/cable`, `NetworkChannel` + `MessagesChannel`) with automatic **polling fallback**
- **Peer / announce browser** with status, hops, link quality and last seen; tap a peer to chat

## Build

Requires Flutter 3.47+, Android SDK 35/36 and JDK 17 or 21 (JDK 26 breaks AGP's `jlink` step).

```sh
flutter pub get
flutter test
flutter build apk --debug   # build/app/outputs/flutter-apk/app-debug.apk
```

## Hub API

The app talks to the hub through the `HubApi` interface (`lib/src/hub_api.dart`), implemented by `HttpHubApi` and `MockHubApi`.

| Endpoint | Status in reticulum-hub |
| --- | --- |
| `GET /up` | exists (used as ping) |
| `GET /api/peers` → `{peers: [...]}` | exists |
| `/cable` `NetworkChannel` `network_update` | exists |
| `GET /api/v1/conversations` → `{conversations: [{peer_hash, peer_name, last_message, unread}]}` | **proposed** |
| `GET /api/v1/conversations/:peer_hash/messages` → `{messages: [...]}` | **proposed** |
| `POST /api/v1/messages` `{message: {recipient_hash, body}}` → `201 {message}` | **proposed** |
| `GET /api/v1/announces` → `{announces: [...]}` (app falls back to `/api/peers`) | **proposed** |
| `Authorization: Bearer <token>` on `/api/*`, `?token=` on `/cable` | **proposed** |
| `/cable` `MessagesChannel` broadcasting `{type: "lxmf_message", message}` | **proposed** |

Message JSON follows the hub's `messages` table: `id, sender_hash, recipient_hash, body, direction, sent_at, delivered, read`.

Until those land, use demo mode.

## License

MIT, see [LICENSE](LICENSE).
