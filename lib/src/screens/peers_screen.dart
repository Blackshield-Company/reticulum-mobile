import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../models.dart';

class PeersScreen extends StatelessWidget {
  final ChatStore store;
  final void Function(String peerHash) onPick;
  const PeersScreen({super.key, required this.store, required this.onPick});

  Color _color(Peer p) => switch (p.status) {
        'active' => Colors.greenAccent,
        'degraded' => Colors.amber,
        'offline' => Colors.redAccent,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = store.announces.isNotEmpty ? store.announces : store.peers;
          return Scaffold(
            appBar: AppBar(title: const Text('Peers & announces')),
            body: RefreshIndicator(
              onRefresh: store.refresh,
              child: ListView(children: [
                for (final p in list)
                  ListTile(
                    leading: Icon(Icons.circle, size: 14, color: _color(p)),
                    title: Text(p.name),
                    subtitle: Text(
                        '${p.destinationHash} · ${p.hops ?? '?'} hops · ${formatAgo(p.lastSeen)}'),
                    trailing: p.linkQuality == null
                        ? null
                        : Text('${(p.linkQuality! * 100).round()}%'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onPick(p.destinationHash);
                    },
                  ),
              ]),
            ),
          );
        },
      );
}
