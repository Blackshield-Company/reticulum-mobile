import 'package:flutter/material.dart';

import '../chat_store.dart';

class ChatScreen extends StatefulWidget {
  final ChatStore store;
  final String peerHash;
  const ChatScreen({super.key, required this.store, required this.peerHash});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    widget.store.openThread(widget.peerHash);
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.store.send(widget.peerHash, text);
      _input.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final msgs = widget.store.threads[widget.peerHash] ?? const [];
        return Scaffold(
          appBar: AppBar(title: Text(widget.store.peerName(widget.peerHash))),
          body: Column(children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: msgs.length,
                itemBuilder: (context, i) {
                  final m = msgs[msgs.length - 1 - i];
                  return Align(
                    alignment: m.outbound ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints: const BoxConstraints(maxWidth: 300),
                      decoration: BoxDecoration(
                        color: m.outbound ? scheme.primary.withValues(alpha: 0.3) : scheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(m.body),
                        if (m.outbound) Text(m.statusIcon, style: const TextStyle(fontSize: 10)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Row(children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      key: const Key('composer'),
                      controller: _input,
                      decoration: const InputDecoration(hintText: 'LXMF message'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('send'),
                  icon: const Icon(Icons.send),
                  onPressed: _sending ? null : _send,
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}
