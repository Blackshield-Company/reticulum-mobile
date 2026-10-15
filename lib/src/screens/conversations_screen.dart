import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../models.dart';
import 'chat_screen.dart';
import 'peers_screen.dart';

class ConversationsScreen extends StatelessWidget {
  final ChatStore store;
  final VoidCallback onUnpair;
  const ConversationsScreen({super.key, required this.store, required this.onUnpair});

  void _open(BuildContext context, String hash) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(store: store, peerHash: hash)));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('Conversations'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(child: Text(store.mode.name, key: const Key('liveMode'))),
              ),
              IconButton(
                key: const Key('peersButton'),
                icon: const Icon(Icons.cell_tower),
                tooltip: 'Peers & announces',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PeersScreen(store: store, onPick: (h) => _open(context, h)))),
              ),
              IconButton(icon: const Icon(Icons.logout), tooltip: 'Unpair', onPressed: onUnpair),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: store.refresh,
            child: store.conversations.isEmpty
                ? ListView(children: [
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(store.error ?? 'No conversations yet. Pick a peer to start one.',
                          textAlign: TextAlign.center),
                    )
                  ])
                : ListView(
                    children: [
                      for (final c in store.conversations)
                        ListTile(
                          leading: CircleAvatar(child: Text(c.peerName.characters.first)),
                          title: Text(c.peerName),
                          subtitle: Text(c.lastMessage?.body ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(formatAgo(c.lastMessage?.sentAt), style: const TextStyle(fontSize: 11)),
                            if (c.unread > 0) Badge(label: Text('${c.unread}')),
                          ]),
                          onTap: () => _open(context, c.peerHash),
                        ),
                    ],
                  ),
          ),
        ),
      );
}
