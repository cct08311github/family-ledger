import 'dart:convert';
import 'package:http/http.dart' as http;

/// AI 解析語音/文字為結構化記帳資料
class ExpenseParserService {
  static String? _apiKey;

  static void configure({required String apiKey}) {
    _apiKey = apiKey;
  }

  static bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// 解析自然語言為記帳結構
  /// 回傳 Map: {description, amount, category, date?}
  static Future<Map<String, dynamic>> parse(
    String text, {
    required List<String> availableCategories,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('尚未設定 AI API Key，請至設定頁面設定');
    }

    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final prompt = '''你是一個記帳助手。請從以下語音輸入中提取記帳資訊，回傳 JSON 格式。

可用類別：${availableCategories.join('、')}

規則：
- amount 必須是正數數字（不含貨幣符號）
- category 必須從可用類別中選擇最接近的一個
- date 格式為 YYYY-MM-DD，如果沒有提到日期則用今天 $today
- description 是簡短的支出描述
- 如果無法解析金額，amount 設為 0

只回傳 JSON，不要其他文字：
{"description": "...", "amount": 數字, "category": "...", "date": "YYYY-MM-DD"}

語音輸入：「$text」''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI 解析失敗 (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('AI 無法解析此內容');
    }

    final content = candidates[0]['content']['parts'][0]['text'] as String;
    // Strip markdown code fences if present
    final cleaned = content
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*$', multiLine: true), '')
        .trim();

    final parsed = jsonDecode(cleaned) as Map<String, dynamic>;

    // Validate and sanitize
    return {
      'description': (parsed['description'] as String?)?.trim() ?? text,
      'amount': (parsed['amount'] is num) ? (parsed['amount'] as num).toDouble() : 0.0,
      'category': availableCategories.contains(parsed['category'])
          ? parsed['category']
          : availableCategories.first,
      'date': parsed['date'] as String? ?? today,
    };
  }
}
