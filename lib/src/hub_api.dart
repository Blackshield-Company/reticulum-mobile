import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models.dart';

/// Hub event pushed over the live channel.
class HubEvent {
  final String type; // network_update | lxmf_message
  final List<Peer> peers;
  final ChatMessage? message;
  const HubEvent(this.type, {this.peers = const [], this.message});
}

/// Everything the app needs from reticulum-hub. Implemented by
/// [HttpHubApi] (real hub) and [MockHubApi] (offline / demo).
abstract class HubApi {
  Future<bool> ping();
  Future<List<Peer>> peers();
  Future<List<Peer>> announces();
  Future<List<Conversation>> conversations();
  Future<List<ChatMessage>> messages(String peerHash);
  Future<ChatMessage> send(String peerHash, String body);

  /// Live events, or null when the transport has no live channel.
  Stream<HubEvent>? events();
  void dispose() {}
}

class HubException implements Exception {
  final String message;
  HubException(this.message);
  @override
  String toString() => 'HubException: $message';
}

/// HTTP client for reticulum-hub.
///
/// Existing hub endpoints used: `GET /up`, `GET /api/peers`, `/cable` (NetworkChannel).
/// Proposed endpoints (not yet in the hub, see README): `/api/v1/...`.
class HttpHubApi implements HubApi {
  final Uri base;
  final String token;
  final http.Client _client;

  HttpHubApi(String baseUrl, this.token, {http.Client? client})
      : base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _get(String path) async {
    final r = await _client.get(base.resolve(path), headers: _headers);
    if (r.statusCode != 200) throw HubException('GET $path -> ${r.statusCode}');
    return jsonDecode(r.body);
  }

  @override
  Future<bool> ping() async {
    try {
      final r = await _client.get(base.resolve('up'), headers: _headers);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  List<Peer> _peerList(dynamic j, String key) =>
      ((j as Map<String, dynamic>)[key] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Peer.fromJson)
          .toList();

  @override
  Future<List<Peer>> peers() async => _peerList(await _get('api/peers'), 'peers');

  @override
  Future<List<Peer>> announces() async {
    try {
      return _peerList(await _get('api/v1/announces'), 'announces');
    } on HubException {
      // Fallback until the hub exposes JSON announces.
      return peers();
    }
  }

  @override
  Future<List<Conversation>> conversations() async {
    final j = await _get('api/v1/conversations') as Map<String, dynamic>;
    return (j['conversations'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Conversation.fromJson)
        .toList();
  }

  @override
  Future<List<ChatMessage>> messages(String peerHash) async {
    final j = await _get('api/v1/conversations/${Uri.encodeComponent(peerHash)}/messages')
        as Map<String, dynamic>;
    return (j['messages'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  @override
  Future<ChatMessage> send(String peerHash, String body) async {
    final r = await _client.post(base.resolve('api/v1/messages'),
        headers: _headers,
        body: jsonEncode({
          'message': {'recipient_hash': peerHash, 'body': body}
        }));
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw HubException('POST api/v1/messages -> ${r.statusCode}');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return ChatMessage.fromJson((j['message'] ?? j) as Map<String, dynamic>);
  }

  /// Action Cable URL derived from the hub URL.
  Uri get cableUri => base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '${base.path}cable',
        queryParameters: token.isEmpty ? null : {'token': token},
      );

  WebSocketChannel? _ws;

  @override
  Stream<HubEvent>? events() {
    _ws?.sink.close();
    final ws = WebSocketChannel.connect(cableUri);
    _ws = ws;
    for (final f in cableSubscribeFrames) {
      ws.sink.add(f);
    }
    return ws.stream.transform(actionCableDecoder);
  }

  @override
  void dispose() {
    _ws?.sink.close();
    _client.close();
  }
}

/// Action Cable subscribe frames for the channels the app listens to.
const cableSubscribeFrames = [
  '{"command":"subscribe","identifier":"{\\"channel\\":\\"NetworkChannel\\"}"}',
  '{"command":"subscribe","identifier":"{\\"channel\\":\\"MessagesChannel\\"}"}',
];

/// Decodes raw Action Cable frames into [HubEvent]s, dropping pings/welcome.
final actionCableDecoder = StreamTransformer<dynamic, HubEvent>.fromHandlers(
  handleData: (raw, sink) {
    final ev = decodeCableFrame(raw.toString());
    if (ev != null) sink.add(ev);
  },
);

HubEvent? decodeCableFrame(String raw) {
  Object? j;
  try {
    j = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (j is! Map<String, dynamic>) return null;
  final m = j['message'];
  if (m is! Map<String, dynamic>) return null;
  switch (m['type']) {
    case 'network_update':
      return HubEvent('network_update',
          peers: (m['peers'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(Peer.fromJson)
              .toList());
    case 'lxmf_message':
      final msg = m['message'];
      if (msg is Map<String, dynamic>) {
        return HubEvent('lxmf_message', message: ChatMessage.fromJson(msg));
      }
  }
  return null;
}

/// In-memory hub with the same mock peers reticulum-hub uses.
class MockHubApi implements HubApi {
  final _ctrl = StreamController<HubEvent>.broadcast();
  final Map<String, List<ChatMessage>> _msgs = {};
  final Duration replyDelay;
  int _id = 0;

  MockHubApi({this.replyDelay = const Duration(seconds: 2)}) {
    final now = DateTime.now();
    _add(ChatMessage(
        id: '${_id++}',
        senderHash: 'd4e5f6a7',
        recipientHash: 'local',
        body: 'Base Station online. Welcome to the mesh.',
        direction: 'inbound',
        sentAt: now.subtract(const Duration(minutes: 12))));
    _add(ChatMessage(
        id: '${_id++}',
        senderHash: 'f0a1b2c3',
        recipientHash: 'local',
        body: 'Alpha checking in, 1 hop out.',
        direction: 'inbound',
        sentAt: now.subtract(const Duration(minutes: 3))));
  }

  static final List<Peer> mockPeers = [
    Peer(destinationHash: 'f0a1b2c3', name: 'Field Node Alpha', lastSeen: DateTime.now().subtract(const Duration(minutes: 2)), linkQuality: 0.92, hops: 1, status: 'active'),
    Peer(destinationHash: 'd4e5f6a7', name: 'Base Station', lastSeen: DateTime.now().subtract(const Duration(seconds: 30)), linkQuality: 0.98, hops: 0, status: 'active'),
    Peer(destinationHash: 'b8c9d0e1', name: 'Relay Node 1', lastSeen: DateTime.now().subtract(const Duration(minutes: 5)), linkQuality: 0.74, hops: 2, status: 'active'),
    Peer(destinationHash: 'f2a3b4c5', name: 'Mobile Unit 3', lastSeen: DateTime.now().subtract(const Duration(minutes: 15)), linkQuality: 0.45, hops: 3, status: 'degraded'),
    Peer(destinationHash: 'd6e7f8a9', name: 'Gateway Node', lastSeen: DateTime.now().subtract(const Duration(hours: 1)), linkQuality: 0.0, hops: 1, status: 'offline'),
  ];

  void _add(ChatMessage m) => _msgs.putIfAbsent(m.peerHash, () => []).add(m);

  String _name(String h) =>
      mockPeers.firstWhere((p) => p.destinationHash == h,
          orElse: () => Peer(destinationHash: h, name: h)).name;

  @override
  Future<bool> ping() async => true;
  @override
  Future<List<Peer>> peers() async => mockPeers;
  @override
  Future<List<Peer>> announces() async => mockPeers;

  @override
  Future<List<Conversation>> conversations() async {
    final list = _msgs.entries
        .map((e) => Conversation(
            peerHash: e.key,
            peerName: _name(e.key),
            lastMessage: e.value.last,
            unread: e.value.where((m) => !m.outbound && !m.read).length))
        .toList()
      ..sort((a, b) => b.lastMessage!.sentAt.compareTo(a.lastMessage!.sentAt));
    return list;
  }

  @override
  Future<List<ChatMessage>> messages(String peerHash) async =>
      List.unmodifiable(_msgs[peerHash] ?? const []);

  @override
  Future<ChatMessage> send(String peerHash, String body) async {
    final m = ChatMessage(
        id: '${_id++}',
        senderHash: 'local',
        recipientHash: peerHash,
        body: body,
        direction: 'outbound',
        sentAt: DateTime.now(),
        delivered: true);
    _add(m);
    if (replyDelay > Duration.zero) {
      Timer(replyDelay, () {
        final r = ChatMessage(
            id: '${_id++}',
            senderHash: peerHash,
            recipientHash: 'local',
            body: 'ack: $body',
            direction: 'inbound',
            sentAt: DateTime.now());
        _add(r);
        if (!_ctrl.isClosed) _ctrl.add(HubEvent('lxmf_message', message: r));
      });
    }
    return m;
  }

  @override
  Stream<HubEvent>? events() => _ctrl.stream;

  @override
  void dispose() => _ctrl.close();
}
