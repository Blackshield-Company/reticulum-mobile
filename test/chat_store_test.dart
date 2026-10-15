import 'package:flutter_test/flutter_test.dart';
import 'package:reticulum_mobile/src/models.dart';
import 'package:reticulum_mobile/src/chat_store.dart';
import 'package:reticulum_mobile/src/hub_api.dart';

class NoLiveHub extends MockHubApi {
  int peerCalls = 0;
  NoLiveHub() : super(replyDelay: Duration.zero);
  @override
  Stream<HubEvent>? events() => null;
  @override
  Future<List<Peer>> peers() async {
    peerCalls++;
    return super.peers();
  }
}

class FailingLiveHub extends MockHubApi {
  FailingLiveHub() : super(replyDelay: Duration.zero);
  @override
  Stream<HubEvent>? events() => Stream.error(Exception('ws refused'));
}

void main() {
  test('websocket mode receives live messages', () async {
    final s = ChatStore(MockHubApi(replyDelay: const Duration(milliseconds: 5)));
    await s.start();
    expect(s.mode, LiveMode.websocket);
    expect(s.peers, hasLength(5));
    expect(s.conversations, hasLength(2));
    await s.openThread('b8c9d0e1');
    await s.send('b8c9d0e1', 'hello relay');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(s.threads['b8c9d0e1']!.map((m) => m.body), ['hello relay', 'ack: hello relay']);
    expect(s.conversations.first.peerHash, 'b8c9d0e1');
    s.dispose();
  });

  test('falls back to polling without live channel', () async {
    final hub = NoLiveHub();
    final s = ChatStore(hub, pollInterval: const Duration(milliseconds: 10));
    await s.start();
    expect(s.mode, LiveMode.polling);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(hub.peerCalls, greaterThan(2));
    s.dispose();
  });

  test('falls back to polling when websocket errors', () async {
    final s = ChatStore(FailingLiveHub(), pollInterval: const Duration(seconds: 30));
    await s.start();
    await Future<void>.delayed(Duration.zero);
    expect(s.mode, LiveMode.polling);
    s.dispose();
  });

  test('blank messages are not sent', () async {
    final s = ChatStore(MockHubApi(replyDelay: Duration.zero));
    await s.start();
    await s.send('x', '   ');
    expect(s.threads['x'], isNull);
    s.dispose();
  });
}
