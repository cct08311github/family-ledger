/// 全域應用常數（Magic numbers 集中管理）
class AppConstants {
  AppConstants._();

  // 支出相關
  static const int maxReceiptPhotos = 10;
  static final DateTime minExpenseDate = DateTime(2020);

  // 日誌與通知
  static const int maxLogEntries = 500;
  static const int notificationLimit = 50;
  static const int activityLogLimit = 100;

  // API 服務
  static const String geminiApiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';
  static const double geminiTemperature = 0.1;

  // UI 限制
  static const int recentExpenseCount = 5;
  static const int searchHistoryLimit = 10;
}
