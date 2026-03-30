// App Exception Hierarchy - 家庭記帳 App
//
// 統一的錯誤處理體系，支援程式化錯誤類型區分

/// 基礎異常類別，所有 App 異常的根類別
sealed class AppException implements Exception {
  final String message;
  final DateTime timestamp;
  final String? stackTrace;

  AppException(this.message, {String? stackTrace})
      : timestamp = DateTime.now(),
        stackTrace = stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// 認證相關異常
class AuthException extends AppException {
  final AuthErrorType type;

  AuthException(super.message, this.type, {super.stackTrace});

  @override
  String toString() => 'AuthException($type): $message';
}

enum AuthErrorType {
  googleSignInFailed,
  appleSignInFailed,
  anonymousSignInFailed,
  linkCredentialFailed,
  sessionExpired,
  userNotFound,
  insufficientPermission,
}

/// 資料同步相關異常
class SyncException extends AppException {
  final SyncErrorType type;

  SyncException(super.message, this.type, {super.stackTrace});

  @override
  String toString() => 'SyncException($type): $message';
}

enum SyncErrorType {
  firestoreWriteFailed,
  firestoreReadFailed,
  firestorePermissionDenied,
  realtimeListenerError,
  mergeConflict,
  networkUnavailable,
  offlineOperation,
}

/// 資料驗證相關異常
class ValidationException extends AppException {
  final String field;
  final ValidationErrorType type;

  ValidationException(
    super.message, {
    required this.field,
    required this.type,
    super.stackTrace,
  });

  @override
  String toString() => 'ValidationException($field, $type): $message';
}

enum ValidationErrorType {
  emptyRequired,
  invalidFormat,
  outOfRange,
  tooLong,
  duplicateEntry,
  notFound,
}

/// 資料庫相關異常
class DatabaseException extends AppException {
  final DatabaseErrorType type;

  DatabaseException(super.message, this.type, {super.stackTrace});

  @override
  String toString() => 'DatabaseException($type): $message';
}

enum DatabaseErrorType {
  isarInitFailed,
  writeTransactionFailed,
  queryFailed,
  schemaMismatch,
  corruptedData,
}

/// 網路相關異常
class NetworkException extends AppException {
  NetworkException(super.message, {super.stackTrace});
}

/// 通用未知異常（包裝未預期錯誤）
class UnknownException extends AppException {
  UnknownException(super.message, {super.stackTrace});
}
