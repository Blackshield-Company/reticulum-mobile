import 'package:flutter/material.dart';

import 'src/chat_store.dart';
import 'src/hub_api.dart';
import 'src/screens/conversations_screen.dart';
import 'src/screens/pair_screen.dart';
import 'src/settings.dart';
import 'src/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ReticulumApp(initial: await HubSettings.load()));
}

HubApi apiFor(HubSettings s) => s.mock ? MockHubApi() : HttpHubApi(s.url, s.token);

class ReticulumApp extends StatefulWidget {
  final HubSettings? initial;
  final HubApi Function(HubSettings) apiFactory;
  final bool persist;
  const ReticulumApp({super.key, this.initial, this.apiFactory = apiFor, this.persist = true});

  @override
  State<ReticulumApp> createState() => _ReticulumAppState();
}

class _ReticulumAppState extends State<ReticulumApp> {
  ChatStore? _store;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _pair(widget.initial!, save: false);
  }

  void _pair(HubSettings s, {bool save = true}) {
    if (save && widget.persist) s.save();
    _store?.dispose();
    final store = ChatStore(widget.apiFactory(s));
    store.start();
    setState(() => _store = store);
  }

  void _unpair() {
    if (widget.persist) HubSettings.clear();
    _store?.dispose();
    setState(() => _store = null);
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Reticulum Mobile',
        debugShowCheckedModeBanner: false,
        theme: blackshieldTheme(),
        home: _store == null
            ? PairScreen(
                onPaired: _pair,
                probe: (s) => widget.apiFactory(s).ping(),
              )
            : ConversationsScreen(key: ObjectKey(_store), store: _store!, onUnpair: _unpair),
      );
}
