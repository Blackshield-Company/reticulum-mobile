import 'package:flutter_test/flutter_test.dart';
import 'package:reticulum_mobile/src/hub_api.dart';
import 'package:reticulum_mobile/src/models.dart';

void main() {
  test('Peer.fromJson parses hub peer shape', () {
    final p = Peer.fromJson({
      'destination_hash': 'abc',
      'name': 'Alpha',
      'last_seen': '2026-10-15T05:00:00Z',
      'link_quality': 0.9,
      'hops': 2,
      'status': 'active'
    });
    expect(p.name, 'Alpha');
    expect(p.hops, 2);
    expect(p.linkQuality, 0.9);
    expect(p.lastSeen, isNotNull);
  });

  test('Peer.fromJson tolerates missing fields', () {
    final p = Peer.fromJson({'destination_hash': 'abc'});
    expect(p.name, 'abc');
    expect(p.status, 'unknown');
  });

  test('ChatMessage peerHash and status icon', () {
    final out = ChatMessage.fromJson({
      'id': 1, 'sender_hash': 'local', 'recipient_hash': 'x', 'body': 'hi',
      'direction': 'outbound', 'sent_at': '2026-10-15T05:00:00Z', 'delivered': true
    });
    expect(out.peerHash, 'x');
    expect(out.statusIcon, '✓');
    final inb = ChatMessage.fromJson({'sender_hash': 'y', 'recipient_hash': 'local', 'direction': 'inbound'});
    expect(inb.peerHash, 'y');
    expect(inb.statusIcon, '○');
  });

  test('formatAgo', () {
    final now = DateTime(2026, 10, 15, 12);
    expect(formatAgo(null), 'never');
    expect(formatAgo(now.subtract(const Duration(seconds: 5)), now: now), 'just now');
    expect(formatAgo(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
    expect(formatAgo(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
    expect(formatAgo(now.subtract(const Duration(days: 2)), now: now), '2d ago');
  });

  group('decodeCableFrame', () {
    test('ignores welcome and ping', () {
      expect(decodeCableFrame('{"type":"welcome"}'), isNull);
      expect(decodeCableFrame('{"type":"ping","message":1}'), isNull);
      expect(decodeCableFrame('not json'), isNull);
    });
    test('decodes network_update from NetworkChannel', () {
      final e = decodeCableFrame(
          '{"identifier":"x","message":{"type":"network_update","peers":[{"destination_hash":"a","name":"A"}]}}');
      expect(e!.type, 'network_update');
      expect(e.peers.single.name, 'A');
    });
    test('decodes lxmf_message', () {
      final e = decodeCableFrame(
          '{"message":{"type":"lxmf_message","message":{"id":7,"sender_hash":"a","recipient_hash":"local","body":"yo","direction":"inbound"}}}');
      expect(e!.message!.body, 'yo');
    });
  });
}
