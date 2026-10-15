import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reticulum_mobile/src/hub_api.dart';

void main() {
  late List<http.Request> seen;
  HttpHubApi api(Map<String, (int, Object)> routes) {
    seen = [];
    return HttpHubApi('http://hub:3000', 'tok', client: MockClient((r) async {
      seen.add(r);
      final hit = routes['${r.method} ${r.url.path}'];
      if (hit == null) return http.Response('nope', 404);
      return http.Response(jsonEncode(hit.$2), hit.$1);
    }));
  }

  test('peers uses existing /api/peers with bearer token', () async {
    final a = api({'GET /api/peers': (200, {'peers': [{'destination_hash': 'a', 'name': 'A'}]})});
    final p = await a.peers();
    expect(p.single.name, 'A');
    expect(seen.single.headers['Authorization'], 'Bearer tok');
  });

  test('announces falls back to /api/peers when v1 missing', () async {
    final a = api({'GET /api/peers': (200, {'peers': [{'destination_hash': 'a'}]})});
    expect((await a.announces()).length, 1);
    expect(seen.map((r) => r.url.path), ['/api/v1/announces', '/api/peers']);
  });

  test('conversations and messages parse v1 shape, sorted', () async {
    final a = api({
      'GET /api/v1/conversations': (200, {'conversations': [{'peer_hash': 'a', 'peer_name': 'A', 'unread': 2}]}),
      'GET /api/v1/conversations/a/messages': (200, {'messages': [
        {'id': 2, 'sender_hash': 'a', 'recipient_hash': 'l', 'body': 'second', 'direction': 'inbound', 'sent_at': '2026-10-15T05:01:00Z'},
        {'id': 1, 'sender_hash': 'a', 'recipient_hash': 'l', 'body': 'first', 'direction': 'inbound', 'sent_at': '2026-10-15T05:00:00Z'},
      ]}),
    });
    expect((await a.conversations()).single.unread, 2);
    expect((await a.messages('a')).map((m) => m.body), ['first', 'second']);
  });

  test('send posts message and parses response', () async {
    final a = api({'POST /api/v1/messages': (201, {'message': {'id': 9, 'sender_hash': 'l', 'recipient_hash': 'a', 'body': 'hi', 'direction': 'outbound'}})});
    final m = await a.send('a', 'hi');
    expect(m.id, '9');
    expect(jsonDecode(seen.single.body)['message']['recipient_hash'], 'a');
  });

  test('errors surface as HubException; ping false on failure', () async {
    final a = api({});
    expect(a.conversations(), throwsA(isA<HubException>()));
    expect(await a.ping(), isFalse);
  });

  test('cable URI derives ws/wss with token', () {
    expect(HttpHubApi('https://h.example/', 't').cableUri.toString(), 'wss://h.example/cable?token=t');
    expect(HttpHubApi('http://h:3000', '').cableUri.toString(), 'ws://h:3000/cable');
  });

  test('mock hub replies over event stream', () async {
    final m = MockHubApi(replyDelay: const Duration(milliseconds: 1));
    final ev = m.events()!.first;
    await m.send('f0a1b2c3', 'ping');
    expect((await ev).message!.body, 'ack: ping');
    expect((await m.messages('f0a1b2c3')).length, 3);
    m.dispose();
  });
}
