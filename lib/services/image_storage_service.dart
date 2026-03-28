import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ImageStorageService {
  static Future<Directory> _receiptsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/receipts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copy picked image to app storage, return the persisted path.
  static Future<String> saveReceipt(String sourcePath) async {
    final dir = await _receiptsDir();
    final ext = sourcePath.contains('.') ? '.${sourcePath.split('.').last}' : '.jpg';
    final destPath = '${dir.path}/${_uuid.v4()}$ext';
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Delete a previously saved receipt.
  static Future<void> deleteReceipt(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
