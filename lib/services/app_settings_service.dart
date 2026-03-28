import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// App 設定持久化
/// - 敏感資料（API Keys）→ flutter_secure_storage（Keychain/Keystore）
/// - 一般設定（主題等）→ JSON 檔案
class AppSettingsService {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── 安全儲存（API Keys 等敏感資料） ──

  static Future<String?> getSecure(String key) async {
    return await _secureStorage.read(key: key);
  }

  static Future<void> setSecure(String key, String? value) async {
    if (value == null) {
      await _secureStorage.delete(key: key);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  // Gemini API Key（安全儲存）
  static Future<String?> get geminiApiKey => getSecure('gemini_api_key');
  static Future<void> setGeminiApiKey(String? key) => setSecure('gemini_api_key', key);

  // ── 一般設定（非敏感，JSON 檔案） ──

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
}
