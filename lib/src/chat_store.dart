import 'dart:async';

import 'package:flutter/foundation.dart';

import 'hub_api.dart';
import 'models.dart';

enum LiveMode { offline, websocket, polling }

/// App state: peers, conversations, open chat, live updates.
/// Uses the hub's live channel when available; otherwise polls.
class ChatStore extends ChangeNotifier {
  final HubApi api;
  final Duration pollInterval;

  ChatStore(this.api, {this.pollInterval = const Duration(seconds: 10)});

  List<Peer> peers = [];
  List<Peer> announces = [];
  List<Conversation> conversations = [];
  final Map<String, List<ChatMessage>> threads = {};
  LiveMode mode = LiveMode.offline;
  String? error;

  StreamSubscription<HubEvent>? _sub;
  Timer? _poll;
  bool _disposed = false;

  String peerName(String hash) => peers
      .firstWhere((p) => p.destinationHash == hash,
          orElse: () => Peer(destinationHash: hash, name: hash))
      .name;

  Future<void> start() async {
    await refresh();
    _startLive();
  }

  void _startLive() {
    Stream<HubEvent>? s;
    try {
      s = api.events();
    } catch (_) {
      s = null;
    }
    if (s == null) return _startPolling();
    mode = LiveMode.websocket;
    _sub = s.listen(_onEvent, onError: (_) => _startPolling(), onDone: _startPolling);
    _notify();
  }

  void _startPolling() {
    _sub?.cancel();
    _sub = null;
    if (_disposed) return;
    mode = LiveMode.polling;
    _poll ??= Timer.periodic(pollInterval, (_) => refresh());
    _notify();
  }

  void _onEvent(HubEvent e) {
    if (e.type == 'network_update' && e.peers.isNotEmpty) {
      peers = e.peers;
      _notify();
    } else if (e.type == 'lxmf_message' && e.message != null) {
      final m = e.message!;
      final t = threads.putIfAbsent(m.peerHash, () => []);
      if (!t.any((x) => x.id == m.id)) t.add(m);
      _loadConversations();
    }
  }

  Future<void> refresh() async {
    try {
      peers = await api.peers();
      error = null;
    } catch (e) {
      error = '$e';
    }
    try {
      announces = await api.announces();
    } catch (_) {}
    await _loadConversations();
    for (final h in threads.keys.toList()) {
      await openThread(h);
    }
  }

  Future<void> _loadConversations() async {
    try {
      conversations = await api.conversations();
    } catch (e) {
      error ??= 'Conversations unavailable: $e';
    }
    _notify();
  }

  Future<void> openThread(String peerHash) async {
    try {
      threads[peerHash] = List.of(await api.messages(peerHash));
    } catch (e) {
      threads.putIfAbsent(peerHash, () => []);
      error = '$e';
    }
    _notify();
  }

  Future<void> send(String peerHash, String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    final m = await api.send(peerHash, text);
    final t = threads.putIfAbsent(peerHash, () => []);
    if (!t.any((x) => x.id == m.id)) t.add(m);
    await _loadConversations();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _poll?.cancel();
    api.dispose();
    super.dispose();
  }
}
