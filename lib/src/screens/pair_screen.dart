import 'package:flutter/material.dart';

import '../settings.dart';

class PairScreen extends StatefulWidget {
  final void Function(HubSettings) onPaired;
  final Future<bool> Function(HubSettings)? probe;
  const PairScreen({super.key, required this.onPaired, this.probe});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _url = TextEditingController(text: 'http://');
  final _token = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _connect({bool mock = false}) async {
    final s = HubSettings(url: _url.text.trim(), token: _token.text.trim(), mock: mock);
    if (!mock) {
      final u = Uri.tryParse(s.url);
      if (u == null || !u.hasScheme || u.host.isEmpty) {
        setState(() => _error = 'Enter a valid hub URL, e.g. http://100.64.0.2:3000');
        return;
      }
      setState(() {
        _busy = true;
        _error = null;
      });
      final ok = await (widget.probe?.call(s) ?? Future.value(true));
      if (!mounted) return;
      setState(() => _busy = false);
      if (!ok) {
        setState(() => _error = 'Hub not reachable at ${s.url}');
        return;
      }
    }
    widget.onPaired(s);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pair with reticulum-hub')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.hub, size: 64),
          const SizedBox(height: 16),
          TextField(
            key: const Key('hubUrl'),
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Hub URL'),
          ),
          TextField(
            key: const Key('hubToken'),
            controller: _token,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'API token'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('connect'),
            onPressed: _busy ? null : () => _connect(),
            child: Text(_busy ? 'Connecting…' : 'Connect'),
          ),
          TextButton(
            key: const Key('demo'),
            onPressed: _busy ? null : () => _connect(mock: true),
            child: const Text('Try demo mode (no hub)'),
          ),
        ]),
      );
}
