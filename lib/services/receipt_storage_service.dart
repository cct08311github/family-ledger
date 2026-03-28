import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'auth_service.dart';

/// Firebase Storage 收據照片上傳服務
///
/// 路徑：receipts/{groupId}/{expenseId}/{uuid}.jpg
/// 下載：使用 getDownloadURL() 取得公開 URL
class ReceiptStorageService {
  static FirebaseStorage get _storage => FirebaseStorage.instance;
  static const _uuid = Uuid();

  /// 上傳單張收據照片，回傳下載 URL
  static Future<String?> upload({
    required String localPath,
    required String groupId,
    required String expenseId,
  }) async {
    if (!AuthService.isSignedIn) return null;

    final file = File(localPath);
    if (!await file.exists()) return null;

    final fileName = '${_uuid.v4()}.jpg';
    final ref = _storage.ref('receipts/$groupId/$expenseId/$fileName');

    try {
      await ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': AuthService.currentUser?.uid ?? '',
          },
        ),
      );
      return await ref.getDownloadURL();
    } catch (_) {
      return null; // 上傳失敗靜默處理，本地路徑仍可用
    }
  }

  /// 批量上傳，回傳 URL 列表（失敗的項目保留本機路徑）
  static Future<List<String>> uploadAll({
    required List<String> localPaths,
    required String groupId,
    required String expenseId,
  }) async {
    if (!AuthService.isSignedIn) return localPaths;

    final results = <String>[];
    for (final path in localPaths) {
      // 已經是 URL 的跳過（避免重複上傳）
      if (path.startsWith('http')) {
        results.add(path);
        continue;
      }
      final url = await upload(
        localPath: path,
        groupId: groupId,
        expenseId: expenseId,
      );
      results.add(url ?? path); // 失敗時保留本機路徑
    }
    return results;
  }

  /// 刪除 expense 的所有收據照片
  static Future<void> deleteAll({
    required String groupId,
    required String expenseId,
  }) async {
    try {
      final ref = _storage.ref('receipts/$groupId/$expenseId');
      final list = await ref.listAll();
      for (final item in list.items) {
        await item.delete();
      }
    } catch (_) {
      // 靜默處理
    }
  }
}
