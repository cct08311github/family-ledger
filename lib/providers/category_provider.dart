import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';
import 'member_provider.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) async* {
  final group = await ref.watch(currentGroupProvider.future);
  if (group == null) {
    yield [];
    return;
  }
  yield* FirestoreService.watchActiveCategories(group.id);
});

/// 所有類別（含停用，管理頁面用）
final allCategoriesProvider = StreamProvider<List<Category>>((ref) async* {
  final group = await ref.watch(currentGroupProvider.future);
  if (group == null) {
    yield [];
    return;
  }
  yield* FirestoreService.watchAllCategories(group.id);
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
    final group = await ref.read(currentGroupProvider.future);
    if (group == null) return;
    final all = await ref.read(allCategoriesProvider.future);
    final maxOrder = all.isEmpty ? -1 : all.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b);
    final cat = Category()
      ..groupId = group.id
      ..name = name
      ..icon = icon
      ..sortOrder = maxOrder + 1
      ..isDefault = false
      ..isActive = true;
    await FirestoreService.addCategory(cat);
  }

  Future<void> updateCategory(Category category) async {
    await FirestoreService.updateCategory(category);
  }

  Future<void> toggleActive(Category category) async {
    category.isActive = !category.isActive;
    await FirestoreService.updateCategory(category);
  }

  Future<void> deleteCategory(String groupId, Category category) async {
    if (category.isDefault) return; // 預設類別不可刪除
    await FirestoreService.deleteCategory(groupId, category.id);
  }

  Future<void> reorder(List<Category> categories) async {
    for (var i = 0; i < categories.length; i++) {
      categories[i].sortOrder = i;
      await FirestoreService.updateCategory(categories[i]);
    }
  }
}
