import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/category.dart';
import '../services/database_service.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) async* {
  final isar = await DatabaseService.instance;
  yield* isar.categorys
      .filter()
      .isActiveEqualTo(true)
      .sortBySortOrder()
      .watch(fireImmediately: true);
});

/// 所有類別（含停用，管理頁面用）
final allCategoriesProvider = StreamProvider<List<Category>>((ref) async* {
  final isar = await DatabaseService.instance;
  yield* isar.categorys
      .where()
      .sortBySortOrder()
      .watch(fireImmediately: true);
});

final categoryNotifierProvider =
    AsyncNotifierProvider<CategoryNotifier, void>(CategoryNotifier.new);

class CategoryNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addCategory({
    required String name,
    required String icon,
  }) async {
    final isar = await DatabaseService.instance;
    final groupId = await DatabaseService.getPrimaryGroupId();
    if (groupId == null) return;
    // Get max sort order
    final all = await isar.categorys.where().sortBySortOrderDesc().findFirst();
    final maxOrder = all?.sortOrder ?? -1;
    final cat = Category()
      ..groupId = groupId
      ..name = name
      ..icon = icon
      ..sortOrder = maxOrder + 1
      ..isDefault = false
      ..isActive = true;
    await isar.writeTxn(() async {
      await isar.categorys.put(cat);
    });
  }

  Future<void> updateCategory(Category category) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      await isar.categorys.put(category);
    });
  }

  Future<void> toggleActive(Category category) async {
    category.isActive = !category.isActive;
    await updateCategory(category);
  }

  Future<void> deleteCategory(Category category) async {
    if (category.isDefault) return; // 預設類別不可刪除
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      await isar.categorys.delete(category.isarId);
    });
  }

  Future<void> reorder(List<Category> categories) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      for (var i = 0; i < categories.length; i++) {
        categories[i].sortOrder = i;
        await isar.categorys.put(categories[i]);
      }
    });
  }
}
