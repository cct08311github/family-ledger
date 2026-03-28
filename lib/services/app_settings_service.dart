import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 簡單的 app 設定持久化（JSON 檔案）
class AppSettingsService {
  static Map<String, dynamic>? _cache;

  static Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/family_ledger_settings.json');
  }

  static Future<Map<String, dynamic>> _load() async {
    if (_cache != null) return _cache!;
    final f = await _file;
    if (await f.exists()) {
      _cache = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } else {
      _cache = {};
    }
    return _cache!;
  }

  static Future<void> _save() async {
    final f = await _file;
    await f.writeAsString(jsonEncode(_cache ?? {}));
  }

  static Future<String?> get(String key) async {
    final settings = await _load();
    return settings[key] as String?;
  }

  static Future<void> set(String key, String? value) async {
    final settings = await _load();
    if (value == null) {
      settings.remove(key);
    } else {
      settings[key] = value;
    }
    await _save();
  }

  // Convenience
  static Future<String?> get geminiApiKey => get('gemini_api_key');
  static Future<void> setGeminiApiKey(String? key) => set('gemini_api_key', key);
}
