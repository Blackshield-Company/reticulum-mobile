import 'package:shared_preferences/shared_preferences.dart';

class HubSettings {
  final String url;
  final String token;
  final bool mock;
  const HubSettings({required this.url, required this.token, required this.mock});

  static Future<HubSettings?> load() async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString('hub_url');
    final mock = p.getBool('hub_mock') ?? false;
    if (url == null && !mock) return null;
    return HubSettings(url: url ?? '', token: p.getString('hub_token') ?? '', mock: mock);
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('hub_url', url);
    await p.setString('hub_token', token);
    await p.setBool('hub_mock', mock);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('hub_url');
    await p.remove('hub_token');
    await p.remove('hub_mock');
  }
}
