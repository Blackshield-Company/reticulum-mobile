import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reticulum_mobile/main.dart';
import 'package:reticulum_mobile/src/hub_api.dart';
import 'package:reticulum_mobile/src/settings.dart';

HubApi testApi(HubSettings s) => MockHubApi(replyDelay: Duration.zero);

void main() {
  testWidgets('pair screen rejects invalid URL', (t) async {
    await t.pumpWidget(const ReticulumApp(apiFactory: testApi, persist: false));
    await t.enterText(find.byKey(const Key('hubUrl')), 'not a url');
    await t.tap(find.byKey(const Key('connect')));
    await t.pump();
    expect(find.textContaining('valid hub URL'), findsOneWidget);
  });

  testWidgets('pair screen reports unreachable hub', (t) async {
    await t.pumpWidget(ReticulumApp(
        apiFactory: (s) => s.mock ? MockHubApi() : HttpHubApi('http://127.0.0.1:1', ''),
        persist: false));
    await t.enterText(find.byKey(const Key('hubUrl')), 'http://127.0.0.1:1');
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('connect')));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await t.pump();
    expect(find.textContaining('not reachable'), findsOneWidget);
  });

  testWidgets('demo mode: conversations, chat, send', (t) async {
    await t.pumpWidget(const ReticulumApp(apiFactory: testApi, persist: false));
    await t.tap(find.byKey(const Key('demo')));
    await t.pumpAndSettle();
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('Field Node Alpha'), findsOneWidget);
    expect(find.text('websocket'), findsOneWidget);

    await t.tap(find.text('Base Station'));
    await t.pumpAndSettle();
    expect(find.text('Base Station online. Welcome to the mesh.'), findsOneWidget);

    await t.enterText(find.byKey(const Key('composer')), 'copy that');
    await t.tap(find.byKey(const Key('send')));
    await t.pumpAndSettle();
    expect(find.text('copy that'), findsOneWidget);
  });

  testWidgets('peer browser lists announces and opens chat', (t) async {
    await t.pumpWidget(const ReticulumApp(apiFactory: testApi, persist: false));
    await t.tap(find.byKey(const Key('demo')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('peersButton')));
    await t.pumpAndSettle();
    expect(find.text('Gateway Node'), findsOneWidget);
    expect(find.text('Relay Node 1'), findsOneWidget);
    await t.tap(find.text('Relay Node 1'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('composer')), findsOneWidget);
    expect(find.text('Relay Node 1'), findsOneWidget);
  });

  testWidgets('unpair returns to pair screen', (t) async {
    await t.pumpWidget(const ReticulumApp(apiFactory: testApi, persist: false));
    await t.tap(find.byKey(const Key('demo')));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Unpair'));
    await t.pumpAndSettle();
    expect(find.text('Pair with reticulum-hub'), findsOneWidget);
  });
}
